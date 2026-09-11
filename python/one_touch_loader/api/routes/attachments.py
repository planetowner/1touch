from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile
from pydantic import BaseModel, HttpUrl, field_validator
from ..db import fetch_one_dict, transaction
from ..deps import get_user_id
from ..repos.auth_repo import rate_limit
from ..repos.posts_repo import get_post
from ..repos.media_repo import queue_deletion
from ..repos.users_repo import get_user, lock_user, require_profile
from ..services.community_periods import utc_now
from ..services.media_storage import private_content, stored_upload

router = APIRouter()


def _draft_user(user_id):
    user = get_user(user_id)
    require_profile(user)
    if user["favorite_team_id"] is None:
        raise HTTPException(403, "Select your home favorite team first")


@router.post("/attachments/upload", status_code=201)
def upload(file: UploadFile = File(), user_id: int = Depends(get_user_id)):
    _draft_user(user_id)
    rate_limit(f"upload:{user_id}", 20, 60)
    with stored_upload(file.file, "posts") as media:
        with transaction() as conn, conn.cursor() as cur:
            # 탈퇴와 업로드가 겹쳐도 미게시 파일의 작성자 관계를 유지해요.
            with conn.cursor(dictionary=True) as user_cur:
                lock_user(user_cur, user_id)
            cur.execute("""INSERT INTO post_attachments (user_id,object_key,content_type,byte_size,created_at)
                VALUES (%s,%s,%s,%s,%s)""", (user_id, media["object_key"], media["content_type"], media["byte_size"], utc_now()))
            attachment_id = cur.lastrowid
    return {"attachment_id": attachment_id, "content_type": media["content_type"], "byte_size": media["byte_size"]}


class LinkBody(BaseModel):
    url: HttpUrl

    @field_validator("url")
    @classmethod
    def stored_url_length(cls, value):
        if len(str(value)) > 2048:
            raise ValueError("Link URL must be at most 2048 characters")
        return value


@router.post("/attachments/link", status_code=201)
def create_link(body: LinkBody, user_id: int = Depends(get_user_id)):
    _draft_user(user_id)
    rate_limit(f"upload:{user_id}", 20, 60)
    # 링크 미리보기를 위해 서버가 임의 주소에 접속하지 않아요.
    with transaction() as conn, conn.cursor() as cur:
        cur.execute("INSERT INTO post_attachments (user_id,link_url,created_at) VALUES (%s,%s,%s)",
                    (user_id, str(body.url), utc_now()))
        return {"attachment_id": cur.lastrowid, "link_url": str(body.url)}


def _accessible_attachment(attachment_id: int, user_id: int) -> dict:
    item = fetch_one_dict("SELECT * FROM post_attachments WHERE attachment_id=%s", (attachment_id,))
    if item is None:
        raise HTTPException(404, "Attachment not found")
    if item["post_id"] is None:
        if item["user_id"] != user_id:
            raise HTTPException(403, "Private draft attachment")
    else:
        get_post(user_id, item["post_id"])
    return item


@router.get("/attachments/{attachment_id}/content")
def content(attachment_id: int, range_header: str | None = Header(default=None, alias="Range"),
            user_id: int = Depends(get_user_id)):
    item = _accessible_attachment(attachment_id, user_id)
    if item["object_key"] is None:
        raise HTTPException(404, "This attachment is a link")
    return private_content(item, range_header)


@router.delete("/attachments/{attachment_id}")
def delete_draft(attachment_id: int, user_id: int = Depends(get_user_id)):
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, user_id)
        cur.execute("SELECT * FROM post_attachments WHERE attachment_id=%s FOR UPDATE", (attachment_id,))
        item = cur.fetchone()
        if item is None:
            raise HTTPException(404, "Attachment not found")
        if item["user_id"] != user_id or item["post_id"] is not None:
            raise HTTPException(403, "Only your unpublished attachments can be removed")
        queue_deletion(cur, item["object_key"])
        cur.execute("DELETE FROM post_attachments WHERE attachment_id=%s", (attachment_id,))
    return {"ok": True}
