"""회원 관계를 조회할 때는 공개 프로필과 조회자의 차단 규칙을 함께 적용해요."""
from typing import Literal

from fastapi import HTTPException
from ..db import fetch_all_dict, fetch_one_dict, transaction
from ..services.content_visibility import blocked_sql, public_author, require_visible_author
from .users_repo import get_user, lock_user, require_profile


FollowDirection = Literal['followers', 'following']
_PROFILE_COLUMNS = """u.user_id,u.username,u.display_name,
    EXISTS(SELECT 1 FROM user_avatars a WHERE a.user_id=u.user_id) AS has_avatar,
    EXISTS(SELECT 1 FROM user_following_users mine
        WHERE mine.user_id=%s AND mine.followed_user_id=u.user_id) AS following"""


def _public_profile(row: dict, viewer_id: int) -> dict:
    return {**public_author(row), 'following': bool(row['following']), 'is_self': viewer_id == row['user_id']}


def get_profile(viewer_id: int, author_id: int) -> dict:
    require_profile(get_user(viewer_id))
    require_visible_author(viewer_id, author_id)
    row = fetch_one_dict(f"""SELECT {_PROFILE_COLUMNS}
        FROM users u WHERE u.user_id=%s""", (viewer_id, author_id))
    if row is None:
        raise HTTPException(404, 'User not found')
    return _public_profile(row, viewer_id)


def _follow_relation(viewer_id: int, author_id: int, direction: FollowDirection) -> tuple[str, tuple]:
    # 관계 방향만 바꾸고 목록과 숫자에 같은 차단 조건을 적용해요.
    owner, member = {'followers': ('followed_user_id', 'user_id'),
                     'following': ('user_id', 'followed_user_id')}[direction]
    return (f"""FROM user_following_users f JOIN users u ON u.user_id=f.{member}
        WHERE f.{owner}=%s AND NOT {blocked_sql('u.user_id')}""", (author_id, viewer_id))


def count_follows(viewer_id: int, author_id: int) -> dict:
    get_profile(viewer_id, author_id)
    followers, follower_params = _follow_relation(viewer_id, author_id, 'followers')
    following, following_params = _follow_relation(viewer_id, author_id, 'following')
    # 별도 카운터 없이 관계 테이블을 한 번에 집계해 같은 시점의 숫자를 반환해요.
    return fetch_one_dict(f"""SELECT
        (SELECT COUNT(*) {followers}) AS follower_count,
        (SELECT COUNT(*) {following}) AS following_count""", follower_params + following_params)


def list_follows(viewer_id: int, author_id: int, direction: FollowDirection, limit: int, offset: int) -> dict:
    get_profile(viewer_id, author_id)
    relation, params = _follow_relation(viewer_id, author_id, direction)
    # 기존 관계에는 생성 시각이 없어서 회원 ID 순으로 페이지 순서를 고정해요.
    rows = fetch_all_dict(f"""SELECT {_PROFILE_COLUMNS} {relation}
        ORDER BY u.user_id LIMIT %s OFFSET %s""", (viewer_id, *params, limit, offset))
    return {'items': [_public_profile(row, viewer_id) for row in rows], 'limit': limit, 'offset': offset}


def set_following(viewer_id: int, author_id: int, following: bool) -> None:
    if viewer_id == author_id:
        raise HTTPException(400, 'Cannot follow yourself')
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        # 서로 팔로우할 때도 회원 잠금 순서를 같게 유지해요.
        # 상대가 탈퇴한 경우를 세션 만료로 처리하지 않도록 404로 구분해요.
        users = {user_id: lock_user(cur, user_id, not_found_status=401 if user_id == viewer_id else 404)
                 for user_id in sorted((viewer_id, author_id))}
        require_profile(users[viewer_id])
        cur.execute('SELECT 1 FROM user_blocks WHERE user_id=%s AND blocked_user_id=%s', (viewer_id, author_id))
        if cur.fetchone():
            raise HTTPException(404, 'User not found')
        if following:
            cur.execute('''INSERT INTO user_following_users (user_id,followed_user_id) VALUES (%s,%s)
                ON DUPLICATE KEY UPDATE user_id=VALUES(user_id)''', (viewer_id, author_id))
        else:
            cur.execute('DELETE FROM user_following_users WHERE user_id=%s AND followed_user_id=%s', (viewer_id, author_id))
