import re
from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, HttpUrl, field_validator
from ..db import fetch_one_dict, transaction
from ..deps import get_user_id
from ..repos.auth_repo import rate_limit
from ..repos.posts_repo import community_user
from ..repos.users_repo import get_user, lock_user, require_profile
from ..services.auth_security import new_token
from ..services.community_periods import utc_now
from ..services.media_storage import inspect_upload, object_operation

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
    mime, size = inspect_upload(file.file)
    key = f"posts/{new_token()}"
    uploaded = False
    try:
        with transaction() as conn, conn.cursor() as cur:
            cur.execute("""INSERT INTO post_attachments (user_id,object_key,content_type,byte_size,created_at)
                VALUES (%s,%s,%s,%s,%s)""", (user_id, key, mime, size, utc_now()))
            attachment_id = cur.lastrowid
            object_operation("put_object", Key=key, Body=file.file, ContentLength=size, ContentType=mime)
            uploaded = True
    except Exception:
        # 파일 업로드 후 DB 저장이 실패한 경우, 이번 요청이 만든 파일만 정리해요.
        if uploaded:
            object_operation("delete_object", Key=key)
        raise
    return {"attachment_id": attachment_id, "content_type": mime, "byte_size": size}


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
        post = fetch_one_dict("SELECT team_id FROM posts WHERE post_id=%s", (item["post_id"],))
        community_user(user_id, post["team_id"])
    return item


@router.get("/attachments/{attachment_id}/content")
def content(attachment_id: int, range_header: str | None = Header(default=None, alias="Range"),
            user_id: int = Depends(get_user_id)):
    item = _accessible_attachment(attachment_id, user_id)
    if item["object_key"] is None:
        raise HTTPException(404, "This attachment is a link")
    args = {"Key": item["object_key"]}
    if range_header is not None:
        match = re.fullmatch(r"bytes=(\d*)-(\d*)", range_header)
        if match is None or not any(match.groups()):
            raise HTTPException(416, "A single byte range is required")
        start, end = match.groups()
        if (start and int(start) >= item["byte_size"]) or (start and end and int(end) < int(start)) or (not start and int(end) == 0):
            raise HTTPException(416, "Range outside file", headers={"Content-Range": f"bytes */{item['byte_size']}"})
        args["Range"] = range_header
    response = object_operation("get_object", **args)
    stream = response["Body"]

    def chunks():
        try:
            yield from stream.iter_chunks(chunk_size=64 * 1024)
        finally:
            stream.close()

    headers = {"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff",
               "Accept-Ranges": "bytes", "Content-Length": str(response["ContentLength"])}
    if range_header:
        headers["Content-Range"] = response["ContentRange"]
    return StreamingResponse(chunks(), status_code=206 if range_header else 200,
                             media_type=item["content_type"], headers=headers)


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
        if item["object_key"]:
            object_operation("delete_object", Key=item["object_key"])
        cur.execute("DELETE FROM post_attachments WHERE attachment_id=%s", (attachment_id,))
    return {"ok": True}
