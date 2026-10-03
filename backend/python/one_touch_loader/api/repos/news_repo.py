from datetime import datetime, timezone

from ..db import fetch_all_dict
from ...core.news import NEWS_MAX_AGE, news_language, select_news, utc_datetime


def get_team_news(team_id: int, locale: str) -> dict:
    language = news_language(locale)
    now = datetime.now(timezone.utc)
    rows = news_candidates(now, team_id=team_id, language=language)
    return {"team_id": team_id, "language": language,
            "items": select_news(rows, language=language, now=now)}


def news_candidates(now: datetime, *, team_id: int | None = None, language: str | None = None) -> list[dict]:
    filters, params = [], []
    if team_id is not None:
        filters.append("article_team.team_id = %s")
        params.append(team_id)
    if language is not None:
        filters.append("a.language = %s")
        params.append(language)
    filters.extend(["s.is_active = 1", "a.published_at >= %s", "a.published_at <= %s"])
    params.extend([(now - NEWS_MAX_AGE).replace(tzinfo=None), now.replace(tzinfo=None)])
    # DB에는 UTC를 저장해요. 서버의 로컬 시간대와 무관하게 같은 14일을 조회해요.
    rows = fetch_all_dict(f"""
        SELECT a.article_id, a.title, s.name AS source, a.url, a.image_url,
               a.published_at, a.language, a.thumbnail_digest, article_team.team_id
        FROM news_article_teams article_team
        JOIN news_articles a ON a.article_id = article_team.article_id
        JOIN news_sources s ON s.source_key = a.source_key
        WHERE {' AND '.join(filters)}
        ORDER BY a.published_at DESC, a.article_id DESC
    """, tuple(params))
    return [{**row, "published_at": utc_datetime(row["published_at"])} for row in rows]
