"""선수 사진과 뉴스 썸네일의 공개 주소·저장·캐시 규칙을 함께 관리해요."""
from dataclasses import dataclass
import hashlib
import re
from urllib.parse import urlsplit

from botocore.exceptions import ClientError

IMAGE_CACHE_CONTROL = "public, max-age=31536000, immutable"


@dataclass(frozen=True)
class PublicImage:
    prefix: str
    extension: str
    content_type: str

    @property
    def route(self) -> str:
        return f"/{self.prefix}/{{digest}}.{self.extension}"

    def object_key(self, digest: str) -> str:
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Expected a SHA-256 image digest")
        # 파일 내용이 바뀌면 주소도 바뀌므로 캐시에 예전 이미지가 남지 않아요.
        return f"{self.prefix}/{digest}.{self.extension}"

    def url(self, base_url: str, digest: str) -> str:
        parts = urlsplit(base_url)
        if (parts.scheme not in {"http", "https"} or not parts.netloc or parts.path not in {"", "/"}
                or parts.query or parts.fragment or parts.username or parts.password):
            raise ValueError("Use an API origin such as https://api.1touch.football")
        return f"{base_url.rstrip('/')}/v1/{self.object_key(digest)}"


PLAYER_IMAGE = PublicImage("player-images", "png", "image/png")
NEWS_IMAGE = PublicImage("news-images", "webp", "image/webp")


def upload_public_image(client, bucket: str, image: PublicImage, data: bytes) -> tuple[str, bool]:
    digest = hashlib.sha256(data).hexdigest()
    key = image.object_key(digest)
    try:
        stored = client.head_object(Bucket=bucket, Key=key)
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") not in {"404", "NoSuchKey", "NotFound"}:
            raise
    else:
        if (stored["ContentLength"] != len(data) or stored.get("ContentType") != image.content_type
                or stored.get("Metadata", {}).get("sha256") != digest):
            raise ValueError(f"Stored image differs from its content key: {key}")
        return digest, False
    client.put_object(Bucket=bucket, Key=key, Body=data, ContentType=image.content_type,
                      CacheControl=IMAGE_CACHE_CONTROL, Metadata={"sha256": digest})
    return digest, True
