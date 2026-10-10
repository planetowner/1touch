"""커뮤니티 프로필에는 공개 작성자 정보와 내 팔로우 상태만 제공해요."""
from fastapi import HTTPException
from ..db import fetch_one_dict, transaction
from ..services.content_visibility import public_author, require_visible_author
from .users_repo import get_user, lock_user, require_profile


def get_profile(viewer_id: int, author_id: int) -> dict:
    require_profile(get_user(viewer_id))
    require_visible_author(viewer_id, author_id)
    row = fetch_one_dict("""SELECT u.user_id,u.username,u.display_name,
        EXISTS(SELECT 1 FROM user_avatars a WHERE a.user_id=u.user_id) AS has_avatar,
        EXISTS(SELECT 1 FROM user_following_users f WHERE f.user_id=%s AND f.followed_user_id=u.user_id) AS following
        FROM users u WHERE u.user_id=%s""", (viewer_id, author_id))
    if row is None:
        raise HTTPException(404, 'User not found')
    return {**public_author(row), 'following': bool(row['following']), 'is_self': viewer_id == author_id}


def set_following(viewer_id: int, author_id: int, following: bool) -> None:
    if viewer_id == author_id:
        raise HTTPException(400, 'Cannot follow yourself')
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        # 서로 팔로우할 때도 회원 잠금 순서를 같게 유지해요.
        users = {user_id: lock_user(cur, user_id) for user_id in sorted((viewer_id, author_id))}
        require_profile(users[viewer_id])
        cur.execute('SELECT 1 FROM user_blocks WHERE user_id=%s AND blocked_user_id=%s', (viewer_id, author_id))
        if cur.fetchone():
            raise HTTPException(404, 'User not found')
        if following:
            cur.execute('''INSERT INTO user_following_users (user_id,followed_user_id) VALUES (%s,%s)
                ON DUPLICATE KEY UPDATE user_id=VALUES(user_id)''', (viewer_id, author_id))
        else:
            cur.execute('DELETE FROM user_following_users WHERE user_id=%s AND followed_user_id=%s', (viewer_id, author_id))
