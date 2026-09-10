"""게시물·댓글·좋아요의 관계와 홈 최애팀 권한을 함께 처리해요."""
from enum import Enum
from fastapi import HTTPException
from ..db import fetch_all_dict, fetch_one_dict, transaction
from ..services.community_access import require_favorite_team_access
from ..services.community_periods import PostPeriod, period_bounds, public_row, utc_now
from .users_repo import get_user, lock_user, require_profile


class PostSort(str, Enum):
    newest = "newest"
    popular = "popular"
    best = "best"


def community_user(user_id: int, team_id: int) -> dict:
    user = get_user(user_id)
    check_community_user(user, team_id)
    return user


def check_community_user(user: dict, team_id: int) -> None:
    require_profile(user)
    require_favorite_team_access(user["favorite_team_id"], (team_id,))


def _post_team(post_id: int) -> int:
    row = fetch_one_dict("SELECT team_id FROM posts WHERE post_id=%s", (post_id,))
    if row is None:
        raise HTTPException(404, "Post not found")
    return row["team_id"]


def list_posts(user_id: int, team_id: int, category: str | None, sort: PostSort,
               period: PostPeriod, limit: int, offset: int) -> list[dict]:
    user = community_user(user_id, team_id)
    clauses, params = ["p.team_id=%s"], [user_id, team_id]
    if category:
        clauses.append("p.category=%s")
        params.append(category)
    bounds = period_bounds(period, user["timezone"], utc_now())
    if bounds:
        clauses.append("p.created_at >= %s AND p.created_at < %s")
        params.extend(bounds)
    # 인기순도 선택 기간에 작성된 게시물의 전체 좋아요 수로 비교해요.
    order = "like_count DESC,p.created_at DESC,p.post_id DESC" if sort == PostSort.popular else "p.created_at DESC,p.post_id DESC"
    having = "HAVING like_count >= 10" if sort == PostSort.best else ""
    rows = fetch_all_dict(f"""SELECT p.*,u.username,
        (SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.post_id) AS like_count,
        (SELECT COUNT(*) FROM post_comments c WHERE c.post_id=p.post_id) AS comment_count,
        EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.post_id AND l.user_id=%s) AS liked
        FROM posts p JOIN users u ON u.user_id=p.user_id WHERE {' AND '.join(clauses)}
        {having} ORDER BY {order} LIMIT %s OFFSET %s""", tuple(params + [limit, offset]))
    for row in rows:
        row["attachments"] = attachments_for_post(row["post_id"])
    return [public_row(row) for row in rows]


def attachments_for_post(post_id: int) -> list[dict]:
    rows = fetch_all_dict("""SELECT attachment_id,position,link_url,content_type,byte_size
        FROM post_attachments WHERE post_id=%s ORDER BY position""", (post_id,))
    for row in rows:
        # 공개 R2 URL을 주지 않고 매 요청에서 권한을 확인하는 우리 API 주소를 제공해요.
        row["media_url"] = None if row["link_url"] else f"/v1/attachments/{row['attachment_id']}/content"
    return rows


def get_post(user_id: int, post_id: int) -> dict:
    community_user(user_id, _post_team(post_id))
    row = fetch_one_dict("""SELECT p.*,u.username,
        (SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.post_id) AS like_count,
        (SELECT COUNT(*) FROM post_comments c WHERE c.post_id=p.post_id) AS comment_count,
        EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.post_id AND l.user_id=%s) AS liked
        FROM posts p JOIN users u ON u.user_id=p.user_id WHERE p.post_id=%s""", (user_id, post_id))
    row["attachments"] = attachments_for_post(post_id)
    return public_row(row)


def create_post(user_id: int, team_id: int, category: str, title: str, body: str, attachment_ids: list[int]) -> int:
    if len(attachment_ids) != len(set(attachment_ids)):
        raise HTTPException(400, "Repeated attachment ID")
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        check_community_user(lock_user(cur, user_id), team_id)
        cur.execute("INSERT INTO posts (team_id,user_id,category,title,body,created_at) VALUES (%s,%s,%s,%s,%s,%s)",
                    (team_id, user_id, category, title, body, utc_now()))
        post_id = cur.lastrowid
        for position, attachment_id in enumerate(attachment_ids):
            cur.execute("SELECT user_id,post_id FROM post_attachments WHERE attachment_id=%s FOR UPDATE", (attachment_id,))
            item = cur.fetchone()
            if item is None or item["user_id"] != user_id or item["post_id"] is not None:
                raise HTTPException(400, "Attachment must be your unpublished upload or link")
            cur.execute("UPDATE post_attachments SET post_id=%s,position=%s WHERE attachment_id=%s", (post_id, position, attachment_id))
    return post_id


def list_comments(user_id: int, post_id: int, after_id: int, limit: int) -> list[dict]:
    community_user(user_id, _post_team(post_id))
    rows = fetch_all_dict("""SELECT c.*,u.username,
        (SELECT COUNT(*) FROM comment_likes l WHERE l.comment_id=c.comment_id) AS like_count,
        EXISTS(SELECT 1 FROM comment_likes l WHERE l.comment_id=c.comment_id AND l.user_id=%s) AS liked
        FROM post_comments c JOIN users u ON u.user_id=c.user_id
        WHERE c.post_id=%s AND c.comment_id>%s ORDER BY c.comment_id LIMIT %s""", (user_id, post_id, after_id, limit))
    return [public_row(row) for row in rows]


def create_comment(user_id: int, post_id: int, body: str, reply_to_id: int | None) -> int:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        user = lock_user(cur, user_id)
        cur.execute("SELECT team_id FROM posts WHERE post_id=%s", (post_id,))
        post = cur.fetchone()
        if post is None:
            raise HTTPException(404, "Post not found")
        check_community_user(user, post["team_id"])
        if reply_to_id is not None:
            cur.execute("SELECT post_id FROM post_comments WHERE comment_id=%s", (reply_to_id,))
            parent = cur.fetchone()
            if parent is None or parent["post_id"] != post_id:
                raise HTTPException(400, "Reply target must belong to this post")
        cur.execute("INSERT INTO post_comments (post_id,user_id,reply_to_id,body,created_at) VALUES (%s,%s,%s,%s,%s)",
                    (post_id, user_id, reply_to_id, body, utc_now()))
        return cur.lastrowid


def set_like(user_id: int, target: str, target_id: int, liked: bool) -> None:
    # 게시물·댓글은 같은 1인 1회 관계예요. 테이블 이름은 이 내부 목록에서만 선택해요.
    table, key, lookup = {
        "post": ("post_likes", "post_id", "SELECT team_id FROM posts WHERE post_id=%s"),
        "comment": ("comment_likes", "comment_id", "SELECT p.team_id FROM post_comments c JOIN posts p ON p.post_id=c.post_id WHERE c.comment_id=%s"),
    }[target]
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        user = lock_user(cur, user_id)
        cur.execute(lookup, (target_id,))
        row = cur.fetchone()
        if row is None:
            raise HTTPException(404, "Content not found")
        check_community_user(user, row["team_id"])
        if liked:
            cur.execute(f"INSERT INTO {table} ({key},user_id) VALUES (%s,%s) ON DUPLICATE KEY UPDATE user_id=VALUES(user_id)", (target_id, user_id))
        else:
            cur.execute(f"DELETE FROM {table} WHERE {key}=%s AND user_id=%s", (target_id, user_id))


def report_content(user_id: int, target: str, target_id: int, reason: str) -> None:
    column, lookup = {
        "post": ("post_id", "SELECT team_id FROM posts WHERE post_id=%s"),
        "comment": ("comment_id", "SELECT p.team_id FROM post_comments c JOIN posts p ON p.post_id=c.post_id WHERE c.comment_id=%s"),
        "message": ("message_id", "SELECT f.home_team_id,f.away_team_id FROM fixture_chat_messages m JOIN fixtures f ON f.fixture_id=m.fixture_id WHERE m.message_id=%s"),
    }[target]
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        user = lock_user(cur, user_id)
        require_profile(user)
        cur.execute(lookup, (target_id,))
        row = cur.fetchone()
        if row is None:
            raise HTTPException(404, "Content not found")
        require_favorite_team_access(user["favorite_team_id"], tuple(row.values()))
        cur.execute(f"INSERT INTO content_reports (user_id,{column},reason,created_at) VALUES (%s,%s,%s,%s)",
                    (user_id, target_id, reason, utc_now()))
