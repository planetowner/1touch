"""R2 파일은 비공개로 보관하고 원본 형식·크기를 확인해요."""
from functools import lru_cache
import warnings
import boto3
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import HTTPException
from PIL import Image, UnidentifiedImageError
from .auth_security import required_setting

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
