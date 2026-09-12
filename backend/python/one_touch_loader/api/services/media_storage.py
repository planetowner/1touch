"""R2 파일은 비공개로 보관하고 원본 형식·크기를 확인해요."""
from functools import lru_cache
from contextlib import contextmanager
import re
import warnings
import boto3
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import HTTPException
from fastapi.responses import StreamingResponse
from PIL import Image, UnidentifiedImageError
from .auth_security import new_token, required_setting

IMAGE_LIMIT = 10_000_000
VIDEO_LIMIT = 100_000_000


@lru_cache(maxsize=1)
def r2_client():
    return boto3.client("s3", endpoint_url=f"https://{required_setting('R2_ACCOUNT_ID')}.r2.cloudflarestorage.com",
                        aws_access_key_id=required_setting("R2_ACCESS_KEY_ID"),
                        aws_secret_access_key=required_setting("R2_SECRET_ACCESS_KEY"), region_name="auto")


def inspect_upload(file) -> tuple[str, int]:
    file.seek(0, 2)
    size = file.tell()
    if not 0 < size <= VIDEO_LIMIT:
        raise HTTPException(413, "File must be between 1 byte and 100 MB")
    file.seek(0)
    header = file.read(4096)
    file.seek(0)
    if header[4:8] == b"ftyp" and header[8:12] in (b"isom", b"iso2", b"mp41", b"mp42", b"avc1", b"M4V ", b"MSNV"):
        content_type = "video/mp4"
    elif header.startswith(b"\x1a\x45\xdf\xa3") and b"webm" in header:
        content_type = "video/webm"
    else:
        if size > IMAGE_LIMIT:
            raise HTTPException(413, "Images and GIFs must be at most 10 MB")
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("error", Image.DecompressionBombWarning)
                with Image.open(file) as image:
                    content_type = {"JPEG": "image/jpeg", "PNG": "image/png", "GIF": "image/gif", "WEBP": "image/webp"}.get(image.format)
                    image.verify()
        except (UnidentifiedImageError, OSError, SyntaxError, Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
            raise HTTPException(415, "Unsupported or invalid image/video") from exc
        if content_type is None:
            raise HTTPException(415, "Use JPEG, PNG, GIF, WebP, MP4, or WebM")
    # 확장자·클라이언트 Content-Type을 파일 내용의 증거로 사용하지 않아요.
    # 영상 컨테이너 서명 검사이며 전체 디코딩·화질 변환을 한 것은 아니에요.
    file.seek(0)
    return content_type, size


def object_operation(operation: str, **kwargs):
    try:
        return getattr(r2_client(), operation)(Bucket=required_setting("R2_BUCKET"), **kwargs)
    except (ClientError, BotoCoreError) as exc:
        raise HTTPException(502, "Attachment storage unavailable") from exc


@contextmanager
def stored_upload(file, prefix: str, *, images_only: bool = False):
    mime, size = inspect_upload(file)
    if images_only and not mime.startswith("image/"):
        raise HTTPException(415, "Profile photos must be images")
    key = f"{prefix}/{new_token()}"
    object_operation("put_object", Key=key, Body=file, ContentLength=size, ContentType=mime)
    try:
        yield {"object_key": key, "content_type": mime, "byte_size": size}
    except Exception:
        # 프로필·게시물 모두 DB 커밋에 실패하면 이번 요청에서 업로드한 파일만 지워요.
        object_operation("delete_object", Key=key)
        raise


def private_content(item: dict, range_header: str | None = None):
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
