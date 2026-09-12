"""게시물·댓글·좋아요의 관계와 홈 최애팀 권한을 함께 처리해요."""
from enum import Enum
from fastapi import HTTPException
from ..db import fetch_all_dict, fetch_one_dict, transaction
from ..services.community_access import require_favorite_team_access
from ..services.community_periods import PostPeriod, period_bounds, public_row, utc_now
from ..services.community_retention import UNPUBLISHED_RETENTION
from .users_repo import get_user, lock_user, require_profile
from .media_repo import remove_attachments
from ..services.content_visibility import blocked_sql, public_author, require_visible_author


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
    row = fetch_one_dict("SELECT team_id FROM posts WHERE post_id=%s AND state='active'", (post_id,))
    if row is None:
        raise HTTPException(404, "Post not found")
    return row["team_id"]


def list_posts(user_id: int, team_id: int, category: str | None, sort: PostSort,
               period: PostPeriod, limit: int, offset: int, timezone: str | None = None) -> list[dict]:
    community_user(user_id, team_id)
    clauses, params = ["p.team_id=%s", "p.state='active'", f"NOT {blocked_sql('p.user_id')}"], [user_id, user_id, team_id, user_id]
    if category:
        clauses.append("p.category=%s")
        params.append(category)
    bounds = period_bounds(period, timezone, utc_now())
    if bounds:
        clauses.append("p.created_at >= %s AND p.created_at < %s")
        params.extend(bounds)
    # 인기순도 선택 기간에 작성된 게시물의 전체 좋아요 수로 비교해요.
    order = "like_count DESC,p.created_at DESC,p.post_id DESC" if sort == PostSort.popular else "p.created_at DESC,p.post_id DESC"
    having = "HAVING like_count >= 10" if sort == PostSort.best else ""
    rows = fetch_all_dict(f"""SELECT p.*,u.username,EXISTS(SELECT 1 FROM user_avatars a WHERE a.user_id=p.user_id) AS has_avatar,
        (SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.post_id) AS like_count,
        (SELECT COUNT(*) FROM post_comments c WHERE c.post_id=p.post_id AND c.state='active' AND NOT {blocked_sql('c.user_id')}) AS comment_count,
        EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.post_id AND l.user_id=%s) AS liked
        FROM posts p LEFT JOIN users u ON u.user_id=p.user_id WHERE {' AND '.join(clauses)}
        {having} ORDER BY {order} LIMIT %s OFFSET %s""", tuple(params + [limit, offset]))
    for row in rows:
        row["attachments"] = attachments_for_post(row["post_id"])
    return [public_row(public_author(row)) for row in rows]


def attachments_for_post(post_id: int) -> list[dict]:
    rows = fetch_all_dict("""SELECT attachment_id,position,link_url,content_type,byte_size
        FROM post_attachments WHERE post_id=%s ORDER BY position""", (post_id,))
    for row in rows:
        # 공개 R2 URL을 주지 않고 매 요청에서 권한을 확인하는 우리 API 주소를 제공해요.
        row["media_url"] = None if row["link_url"] else f"/v1/attachments/{row['attachment_id']}/content"
    return rows


def get_post(user_id: int, post_id: int) -> dict:
    community_user(user_id, _post_team(post_id))
    row = fetch_one_dict(f"""SELECT p.*,u.username,EXISTS(SELECT 1 FROM user_avatars a WHERE a.user_id=p.user_id) AS has_avatar,
        (SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.post_id) AS like_count,
        (SELECT COUNT(*) FROM post_comments c WHERE c.post_id=p.post_id AND c.state='active' AND NOT {blocked_sql('c.user_id')}) AS comment_count,
        EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.post_id AND l.user_id=%s) AS liked
        FROM posts p LEFT JOIN users u ON u.user_id=p.user_id WHERE p.post_id=%s AND p.state='active'""", (user_id, user_id, post_id))
    if row is None:
        raise HTTPException(404, "Post not found")
    require_visible_author(user_id, row["user_id"])
    row["attachments"] = attachments_for_post(post_id)
    return public_row(public_author(row))


def _set_attachments(cur, user_id: int, post_id: int, attachment_ids: list[int]) -> None:
    if len(attachment_ids) > 10 or len(attachment_ids) != len(set(attachment_ids)):
        raise HTTPException(400, "Use up to ten different attachments")
    for attachment_id in sorted(attachment_ids):
        cur.execute("SELECT user_id,post_id,created_at FROM post_attachments WHERE attachment_id=%s FOR UPDATE", (attachment_id,))
        item = cur.fetchone()
        if item is None or item["user_id"] != user_id or item["post_id"] not in (None, post_id):
            raise HTTPException(400, "Attachment must be your draft or belong to this post")
        # 초안에 연결한 첨부는 초안의 마지막 저장을 따라가요. 미사용 파일만 업로드 시각으로 판단해요.
        if item["post_id"] is None and item["created_at"] <= utc_now() - UNPUBLISHED_RETENTION:
            raise HTTPException(400, "Unused attachment has expired")
    remove_attachments(cur, post_id, tuple(attachment_ids))
    # 순서를 맞바꿀 때 UNIQUE(post_id,position)가 부딪히지 않게 연결을 한 번 비워요.
    # 같은 트랜잭션 안에서만 비우므로 외부 조회에는 중간 상태가 보이지 않아요.
    cur.execute("UPDATE post_attachments SET post_id=NULL,position=NULL WHERE post_id=%s", (post_id,))
    for position, attachment_id in enumerate(attachment_ids):
        cur.execute("UPDATE post_attachments SET post_id=%s,position=%s WHERE attachment_id=%s", (post_id, position, attachment_id))


def _lock_post(cur, user: dict, post_id: int) -> dict:
    cur.execute("SELECT * FROM posts WHERE post_id=%s FOR UPDATE", (post_id,))
    post = cur.fetchone()
    if post is None or post["state"] != "active":
        raise HTTPException(404, "Post not found")
    check_community_user(user, post["team_id"])
    cur.execute("SELECT 1 FROM user_blocks WHERE user_id=%s AND blocked_user_id=%s", (user["user_id"], post["user_id"]))
    if cur.fetchone():
        raise HTTPException(404, "Post not found")
    return post


def _require_author(user_id: int, content: dict) -> None:
    if content["user_id"] != user_id:
        raise HTTPException(403, "Only the author can change this content")


def create_post(user_id: int, team_id: int, category: str, title: str, body: str, attachment_ids: list[int], *, draft: bool = False) -> int:
    if len(attachment_ids) != len(set(attachment_ids)):
        raise HTTPException(400, "Repeated attachment ID")
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        check_community_user(lock_user(cur, user_id), team_id)
        now = utc_now()
        cur.execute("INSERT INTO posts (team_id,user_id,category,title,body,created_at,state,edited_at) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
                    (team_id, user_id, category, title, body, now, "draft" if draft else "active", now if draft else None))
        post_id = cur.lastrowid
        _set_attachments(cur, user_id, post_id, attachment_ids)
    return post_id


def update_post(user_id: int, post_id: int, category: str, title: str, body: str, attachment_ids: list[int], *, draft: bool = False) -> None:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        user = lock_user(cur, user_id)
        post = _lock_draft(cur, user_id, post_id) if draft else _lock_post(cur, user, post_id)
        check_community_user(user, post["team_id"])
        _require_author(user_id, post)
        _set_attachments(cur, user_id, post_id, attachment_ids)
        # 수정으로 최신순 맨 위에 다시 올라가지 않도록 작성 시각은 유지해요.
        cur.execute("UPDATE posts SET category=%s,title=%s,body=%s,edited_at=%s WHERE post_id=%s",
                    (category, title, body, utc_now(), post_id))


def _require_draft(row: dict | None, user_id: int) -> dict:
    # 정리 작업 실행 전이라도 7일이 지난 초안을 다시 저장하거나 게시할 수 없어요.
    if (row is None or row["state"] != "draft" or row["user_id"] != user_id
            or row["edited_at"] <= utc_now() - UNPUBLISHED_RETENTION):
        raise HTTPException(404, "Draft not found or expired")
    return row


def _lock_draft(cur, user_id: int, post_id: int) -> dict:
    cur.execute("SELECT * FROM posts WHERE post_id=%s FOR UPDATE", (post_id,))
    return _require_draft(cur.fetchone(), user_id)


def _public_draft(row: dict) -> dict:
    row["attachments"] = attachments_for_post(row["post_id"])
    row["expires_at"] = row["edited_at"] + UNPUBLISHED_RETENTION
    return public_row(row)


def list_drafts(user_id: int, limit: int, offset: int) -> list[dict]:
    require_profile(get_user(user_id))
    # 초안 목록은 작성자만 봐요. 최애팀 변경 후에도 내 초안을 확인·삭제할 수 있어요.
    rows = fetch_all_dict("""SELECT * FROM posts WHERE user_id=%s AND state='draft' AND edited_at>%s
        ORDER BY edited_at DESC,post_id DESC LIMIT %s OFFSET %s""",
        (user_id, utc_now() - UNPUBLISHED_RETENTION, limit, offset))
    return [_public_draft(row) for row in rows]


def get_draft(user_id: int, post_id: int) -> dict:
    require_profile(get_user(user_id))
    row = fetch_one_dict("SELECT * FROM posts WHERE post_id=%s", (post_id,))
    return _public_draft(_require_draft(row, user_id))


def publish_draft(user_id: int, post_id: int) -> int:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        user = lock_user(cur, user_id)
        post = _lock_draft(cur, user_id, post_id)
        # 게시 권한은 지금의 최애팀으로 다시 확인해요. 저장 당시 권한을 이어 쓰지 않아요.
        check_community_user(user, post["team_id"])
        if not post["title"]:
            raise HTTPException(400, "A title is required to publish")
        # 게시·댓글·첨부는 같은 ID를 써요. 최신순은 초안 작성일이 아닌 실제 게시일로 정해요.
        cur.execute("UPDATE posts SET state='active',created_at=%s,edited_at=NULL WHERE post_id=%s", (utc_now(), post_id))
    return post_id


def delete_draft(user_id: int, post_id: int) -> None:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        require_profile(lock_user(cur, user_id))
        _lock_draft(cur, user_id, post_id)
        remove_attachments(cur, post_id)
        # 초안은 공개한 적이 없어 답글 관계를 남길 필요가 없어요.
        cur.execute("DELETE FROM posts WHERE post_id=%s", (post_id,))


def delete_post(user_id: int, post_id: int) -> None:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        _require_author(user_id, _lock_post(cur, lock_user(cur, user_id), post_id))
        remove_attachments(cur, post_id)
        cur.execute("UPDATE posts SET state='deleted',title='',body='' WHERE post_id=%s", (post_id,))


def list_comments(user_id: int, post_id: int, after_id: int, limit: int) -> list[dict]:
    get_post(user_id, post_id)
    rows = fetch_all_dict(f"""SELECT c.*,u.username,{blocked_sql('c.user_id')} AS blocked,
        EXISTS(SELECT 1 FROM user_avatars a WHERE a.user_id=c.user_id) AS has_avatar,
        (SELECT COUNT(*) FROM comment_likes l WHERE l.comment_id=c.comment_id) AS like_count,
        EXISTS(SELECT 1 FROM comment_likes l WHERE l.comment_id=c.comment_id AND l.user_id=%s) AS liked
        FROM post_comments c LEFT JOIN users u ON u.user_id=c.user_id
        WHERE c.post_id=%s AND c.comment_id>%s ORDER BY c.comment_id LIMIT %s""", (user_id, user_id, post_id, after_id, limit))
    for row in rows:
        blocked = row.pop("blocked")
        public_author(row)
        if blocked or row["state"] != "active":
            # 댓글 행을 없애면 답글 대상이 사라져요. ID와 답글 관계만 남기고 내용은 숨겨요.
            row.update(body="", username=None, user_id=None, avatar_url=None, liked=False, like_count=0,
                       state="blocked" if blocked else row["state"])
    return [public_row(row) for row in rows]


def create_comment(user_id: int, post_id: int, body: str, reply_to_id: int | None) -> int:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        user = lock_user(cur, user_id)
        _lock_post(cur, user, post_id)
        if reply_to_id is not None:
            cur.execute("SELECT post_id,user_id,state FROM post_comments WHERE comment_id=%s FOR UPDATE", (reply_to_id,))
            parent = cur.fetchone()
            if parent is None or parent["post_id"] != post_id or parent["state"] != "active":
                raise HTTPException(400, "Reply target must belong to this post")
            require_visible_author(user_id, parent["user_id"])
        cur.execute("INSERT INTO post_comments (post_id,user_id,reply_to_id,body,created_at) VALUES (%s,%s,%s,%s,%s)",
                    (post_id, user_id, reply_to_id, body, utc_now()))
        return cur.lastrowid


def _lock_comment(cur, user: dict, comment_id: int) -> dict:
    cur.execute("SELECT post_id FROM post_comments WHERE comment_id=%s", (comment_id,))
    row = cur.fetchone()
    if row is None:
        raise HTTPException(404, "Comment not found")
    _lock_post(cur, user, row["post_id"])
    cur.execute("SELECT * FROM post_comments WHERE comment_id=%s FOR UPDATE", (comment_id,))
    comment = cur.fetchone()
    if comment["state"] != "active":
        raise HTTPException(404, "Comment not found")
    require_visible_author(user["user_id"], comment["user_id"])
    return comment


def change_comment(user_id: int, comment_id: int, body: str | None) -> None:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        _require_author(user_id, _lock_comment(cur, lock_user(cur, user_id), comment_id))
        if body is None:
            cur.execute("UPDATE post_comments SET state='deleted',body='' WHERE comment_id=%s", (comment_id,))
        else:
            # 수정은 본문만 바꿔요. 다른 댓글로 답글 대상을 옮길 수 없어요.
            cur.execute("UPDATE post_comments SET body=%s,edited_at=%s WHERE comment_id=%s", (body, utc_now(), comment_id))


def set_like(user_id: int, target: str, target_id: int, liked: bool) -> None:
    # 게시물·댓글은 같은 1인 1회 관계예요. 테이블 이름은 이 내부 목록에서만 선택해요.
    table, key, lookup = {
        "post": ("post_likes", "post_id", _lock_post),
        "comment": ("comment_likes", "comment_id", _lock_comment),
    }[target]
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        user = lock_user(cur, user_id)
        lookup(cur, user, target_id)
        if liked:
            cur.execute(f"INSERT INTO {table} ({key},user_id) VALUES (%s,%s) ON DUPLICATE KEY UPDATE user_id=VALUES(user_id)", (target_id, user_id))
        else:
            cur.execute(f"DELETE FROM {table} WHERE {key}=%s AND user_id=%s", (target_id, user_id))


def report_content(user_id: int, target: str, target_id: int, reason: str) -> None:
    column = {"post": "post_id", "comment": "comment_id", "message": "message_id"}[target]
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        user = lock_user(cur, user_id)
        require_profile(user)
        if target == "post":
            _lock_post(cur, user, target_id)
        elif target == "comment":
            _lock_comment(cur, user, target_id)
        else:
            cur.execute("""SELECT f.home_team_id,f.away_team_id,m.user_id FROM fixture_chat_messages m
                JOIN fixtures f ON f.fixture_id=m.fixture_id WHERE m.message_id=%s AND m.state='active' FOR UPDATE""", (target_id,))
            row = cur.fetchone()
            if row is None:
                raise HTTPException(404, "Content not found")
            require_favorite_team_access(user["favorite_team_id"], (row["home_team_id"], row["away_team_id"]))
            require_visible_author(user_id, row["user_id"])
        cur.execute(f"INSERT INTO content_reports (user_id,{column},reason,created_at) VALUES (%s,%s,%s,%s)",
                    (user_id, target_id, reason, utc_now()))
