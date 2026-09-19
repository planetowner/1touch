from datetime import datetime, timezone

from ..db import fetch_all_dict
from ...core.news import NEWS_MAX_AGE, news_language, select_news, utc_datetime


def get_team_news(team_id: int, locale: str) -> dict:
    language = news_language(locale)
    now = datetime.now(timezone.utc)
    # DB에는 UTC를 저장해요. 서버의 로컬 시간대와 무관하게 같은 14일을 조회해요.
    rows = fetch_all_dict("""
        SELECT a.article_id, a.title, s.name AS source, a.url, a.image_url,
               a.published_at, a.language
        FROM news_article_teams article_team
        JOIN news_articles a ON a.article_id = article_team.article_id
        JOIN news_sources s ON s.source_key = a.source_key
        WHERE article_team.team_id = %s AND a.language = %s AND s.is_active = 1
          AND a.published_at >= %s AND a.published_at <= %s
        ORDER BY a.published_at DESC, a.article_id DESC
    """, (team_id, language, (now - NEWS_MAX_AGE).replace(tzinfo=None), now.replace(tzinfo=None)))
    items = [{**a, "published_at": utc_datetime(a["published_at"])}
             for a in select_news(rows, language=language, now=now)]
    return {"team_id": team_id, "language": language, "items": items}
