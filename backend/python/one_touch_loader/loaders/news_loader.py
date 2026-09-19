"""확인된 RSS만 읽어요. --apply를 명시해야 운영 데이터를 저장해요."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import requests
import xml.etree.ElementTree as ET

from one_touch_loader.core.news import ALIASES_PATH, NEWS_MAX_AGE, TeamNewsMatcher, load_sources, parse_feed


def current_teams() -> list[dict]:
    from one_touch_loader.core.db import fetch_all
    rows = fetch_all("""SELECT DISTINCT t.team_id, t.name, s.competition_id
        FROM teams t JOIN team_seasons ts ON ts.team_id=t.team_id
        JOIN seasons s ON s.season_id=ts.season_id
        WHERE s.is_current=1 AND s.competition_id IN (8,82,301,384,564)""")
    return [dict(zip(("team_id", "name", "competition_id"), row)) for row in rows]


def save_sources(sources: list[dict]) -> None:
    from one_touch_loader.core.db import transaction
    with transaction() as conn, conn.cursor() as cur:
        cur.executemany("""INSERT INTO news_sources
            (source_key, name, language, competition_ids, feed_url, is_active)
            VALUES (%s,%s,%s,%s,%s,%s) ON DUPLICATE KEY UPDATE
            name=VALUES(name), language=VALUES(language), competition_ids=VALUES(competition_ids),
            feed_url=VALUES(feed_url), is_active=VALUES(is_active)""",
            [(s["key"], s["name"], s["language"], json.dumps(s["competition_ids"]),
              s["feed_url"], s["is_active"]) for s in sources])


def save_articles(source: dict, articles: list[dict], checked_at: datetime, error: str | None) -> None:
    from one_touch_loader.core.db import transaction
    with transaction() as conn, conn.cursor() as cur:
        for article in articles:
            cur.execute("""INSERT INTO news_articles
                (source_key,language,title,url,url_hash,image_url,published_at,collected_at)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s) ON DUPLICATE KEY UPDATE
                article_id=LAST_INSERT_ID(article_id), title=VALUES(title),
                image_url=VALUES(image_url), published_at=VALUES(published_at), collected_at=VALUES(collected_at)
                """, (source["key"], source["language"], article["title"], article["url"],
                       article["url_hash"], article["image_url"], article["published_at"].replace(tzinfo=None),
                       checked_at.replace(tzinfo=None)))
            article_id = cur.lastrowid
            # 제목·태그가 정정되면 예전 팀 연결도 함께 바꿔요.
            cur.execute("DELETE FROM news_article_teams WHERE article_id=%s", (article_id,))
            if article["team_ids"]:
                cur.executemany("INSERT INTO news_article_teams(article_id,team_id) VALUES(%s,%s)",
                                [(article_id, team_id) for team_id in article["team_ids"]])
        cur.execute("""UPDATE news_sources SET last_checked_at=%s, last_error=%s,
            last_success_at=CASE WHEN %s IS NULL THEN %s ELSE last_success_at END
            WHERE source_key=%s""", (checked_at.replace(tzinfo=None), error, error,
                                    checked_at.replace(tzinfo=None), source["key"]))


def refresh(*, apply: bool, sources=None, teams=None, session=None, now=None) -> dict:
    sources = load_sources() if sources is None else sources
    teams = current_teams() if teams is None else teams
    aliases = json.loads(ALIASES_PATH.read_text(encoding="utf-8"))["teams"]
    matcher = TeamNewsMatcher(teams, aliases)
    now = now or datetime.now(timezone.utc)
    report = {"apply": apply, "teams": len(teams), "sources": []}
    if apply:
        save_sources(sources)
    own_session = session is None
    session = session or requests.Session()
    try:
        for source in sources:
            if not source["is_active"]:
                continue
            articles, error = [], None
            try:
                response = session.get(source["feed_url"], timeout=20,
                                       headers={"User-Agent": "1Touch-News/1.0", "Accept": "application/rss+xml, application/xml"})
                response.raise_for_status()
                for article in parse_feed(response.content, source):
                    if now - NEWS_MAX_AGE <= article["published_at"] <= now:
                        articles.append({**article, "team_ids": matcher.match(article, source["competition_ids"])})
            except (requests.RequestException, ET.ParseError, ValueError) as exc:
                # 원문 응답이나 URL을 오류에 출력하지 않고 실패한 공급자만 표시해요.
                error = type(exc).__name__
            if apply:
                save_articles(source, articles, now, error)
            report["sources"].append({"name": source["name"], "language": source["language"],
                                      "articles": len(articles), "matched": sum(bool(a["team_ids"]) for a in articles),
                                      "team_ids": sorted({t for a in articles for t in a["team_ids"]}), "error": error})
    finally:
        if own_session:
            session.close()
    return report


def run_cli(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", choices=["refresh"], default="refresh")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    report = refresh(apply=args.apply)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if any(s["error"] for s in report["sources"]):
        raise SystemExit(1)


if __name__ == "__main__":
    run_cli()
