"""선수 사진의 공개 주소와 R2 경로를 같은 규칙으로 만들어요."""
import re
from urllib.parse import urlsplit

IMAGE_ROUTE = "/player-images"
IMAGE_CACHE_CONTROL = "public, max-age=31536000, immutable"


def image_object_key(digest: str) -> str:
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("Expected a SHA-256 image digest")
    # 파일 내용이 바뀌면 주소도 바뀌므로 앱 캐시에 예전 사진이 남지 않아요.
    return f"player-images/{digest}.png"


def image_url(base_url: str, digest: str) -> str:
    parts = urlsplit(base_url)
    if (parts.scheme not in {"http", "https"} or not parts.netloc or parts.path not in {"", "/"}
            or parts.query or parts.fragment or parts.username or parts.password):
        raise ValueError("Use an API origin such as https://api.1touch.football")
    image_object_key(digest)
    return f"{base_url.rstrip('/')}/v1{IMAGE_ROUTE}/{digest}.png"
