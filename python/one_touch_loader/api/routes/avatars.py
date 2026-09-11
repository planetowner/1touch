"""프로필 사진도 게시물 첨부와 같은 비공개 업로드·전송 경로를 사용해요."""
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from ..db import fetch_one_dict, transaction
from ..deps import get_user_id
from ..repos.auth_repo import rate_limit
from ..repos.media_repo import queue_deletion
from ..repos.users_repo import get_user, lock_user, require_profile
from ..services.content_visibility import require_visible_author
from ..services.media_storage import private_content, stored_upload

router = APIRouter()


@router.put("/users/me/avatar")
def upload_avatar(file: UploadFile = File(), user_id: int = Depends(get_user_id)):
    require_profile(get_user(user_id))
    rate_limit(f"upload:{user_id}", 20, 60)
    with stored_upload(file.file, "avatars", images_only=True) as media:
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            require_profile(lock_user(cur, user_id))
            cur.execute("SELECT object_key FROM user_avatars WHERE user_id=%s FOR UPDATE", (user_id,))
            previous = cur.fetchone()
            if previous:
                queue_deletion(cur, previous["object_key"])
            cur.execute("""INSERT INTO user_avatars (user_id,object_key,content_type,byte_size) VALUES (%s,%s,%s,%s)
                ON DUPLICATE KEY UPDATE object_key=VALUES(object_key),content_type=VALUES(content_type),byte_size=VALUES(byte_size)""",
                        (user_id, media["object_key"], media["content_type"], media["byte_size"]))
    return {"avatar_url": f"/v1/users/{user_id}/avatar"}


@router.delete("/users/me/avatar")
def delete_avatar(user_id: int = Depends(get_user_id)):
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, user_id)
        cur.execute("SELECT object_key FROM user_avatars WHERE user_id=%s FOR UPDATE", (user_id,))
        previous = cur.fetchone()
        if previous:
            queue_deletion(cur, previous["object_key"])
            cur.execute("DELETE FROM user_avatars WHERE user_id=%s", (user_id,))
    return {"ok": True}


@router.get("/users/{author_id}/avatar")
def avatar(author_id: int, user_id: int = Depends(get_user_id)):
    if author_id != user_id:
        viewer = get_user(user_id)
        require_profile(viewer)
        require_visible_author(user_id, author_id)
        # 현재 팀이 달라도 같은 커뮤니티·경기에서 보이는 작성자의 사진은 읽을 수 있어요.
        visible = fetch_one_dict("""SELECT 1 WHERE
            EXISTS(SELECT 1 FROM posts WHERE user_id=%s AND team_id=%s AND state='active') OR
            EXISTS(SELECT 1 FROM post_comments c JOIN posts p ON p.post_id=c.post_id
                WHERE c.user_id=%s AND p.team_id=%s AND c.state='active' AND p.state='active') OR
            EXISTS(SELECT 1 FROM fixture_chat_messages m JOIN fixtures f ON f.fixture_id=m.fixture_id
                WHERE m.user_id=%s AND %s IN (f.home_team_id,f.away_team_id) AND m.state='active')""",
                                 (author_id, viewer["favorite_team_id"]) * 3)
        if not visible:
            raise HTTPException(404, "Profile photo not found")
    item = fetch_one_dict("SELECT * FROM user_avatars WHERE user_id=%s", (author_id,))
    if item is None:
        raise HTTPException(404, "Profile photo not found")
    return private_content(item)
