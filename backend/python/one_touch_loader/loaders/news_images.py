"""화면에 표시할 뉴스 이미지를 수집할 때 줄여서 저장해요."""
from collections import defaultdict
from datetime import datetime
import io

from botocore.exceptions import BotoCoreError, ClientError
from PIL import Image, ImageOps
import requests

from one_touch_loader.core.news import select_news
from one_touch_loader.core.public_images import NEWS_IMAGE, upload_public_image

# 홈 카드 119×68을 3배 해상도로 준비해 작은 화면에서도 선명하게 보여줘요.
THUMBNAIL_SIZE = (357, 204)


def make_news_thumbnail(content: bytes) -> bytes:
    with Image.open(io.BytesIO(content)) as source:
        image = ImageOps.fit(ImageOps.exif_transpose(source).convert("RGBA"), THUMBNAIL_SIZE,
                             method=Image.Resampling.LANCZOS)
        output = io.BytesIO()
        image.save(output, format="WEBP", quality=80, method=4)
        return output.getvalue()


def thumbnail_targets(rows: list[dict], now: datetime) -> dict[str, set[int]]:
    feeds = defaultdict(list)
    for row in rows:
        feeds[(row["team_id"], row["language"])].append(row)
    targets = defaultdict(set)
    for (_, language), articles in feeds.items():
        # API와 같은 최신 3개 선정 규칙을 써요. 여러 팀에 걸친 이미지는 한 번만 받아요.
        for article in select_news(articles, language=language, now=now):
            if article["image_url"] and not article.get("thumbnail_digest"):
                targets[article["image_url"]].add(article["article_id"])
    return targets


def refresh_news_images(session, now: datetime) -> dict:
    from one_touch_loader.api.db import execute
    from one_touch_loader.api.repos.news_repo import news_candidates
    from one_touch_loader.api.services.auth_security import required_setting
    from one_touch_loader.api.services.media_storage import r2_client

    # 피드에서 이미 빠진 기사도 DB에 남아 있는 표시 대상이면 준비해요.
    targets = thumbnail_targets(news_candidates(now), now)
    report = {"prepared": 0, "errors": []}
    if not targets:
        return report
    client, bucket = r2_client(), required_setting("R2_BUCKET")
    for url, article_ids in targets.items():
        try:
            with session.get(url, timeout=20, headers={"User-Agent": "1Touch-News/1.0"}) as response:
                response.raise_for_status()
                data = make_news_thumbnail(response.content)
            digest, _ = upload_public_image(client, bucket, NEWS_IMAGE, data)
            # 업로드를 마친 파일만 연결하고, 수집 중 원본 주소가 바뀌면 다음 실행에서 다시 준비해요.
            placeholders = ','.join(['%s'] * len(article_ids))
            report["prepared"] += execute(f"""UPDATE news_articles SET thumbnail_digest=%s
                WHERE article_id IN ({placeholders}) AND image_url=%s AND thumbnail_digest IS NULL""",
                (digest, *sorted(article_ids), url))
        except (requests.RequestException, OSError, ValueError, Image.DecompressionBombError,
                BotoCoreError, ClientError) as exc:
            # 외부 이미지 실패로 기사나 기존 원본 주소를 버리지 않아요.
            report["errors"].append({"article_ids": sorted(article_ids), "error": type(exc).__name__})
    return report
