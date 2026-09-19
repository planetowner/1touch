"""공급자와 화면이 달라도 기사 정리·팀 연결·선정 규칙은 같아요."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from hashlib import sha256
import html
import json
from pathlib import Path
import re
import unicodedata
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
from zoneinfo import ZoneInfo
import xml.etree.ElementTree as ET

from bs4 import BeautifulSoup

from .datetime_utils import utc_datetime

NEWS_LIMIT = 3
NEWS_MAX_AGE = timedelta(days=14)
CATALOG_PATH = Path(__file__).with_name("news_sources.json")
ALIASES_PATH = Path(__file__).with_name("news_team_aliases.json")


def news_language(locale: str) -> str:
    # TODO: 중국어·일본어 공급자를 찾으면 zh·ja도 각 언어의 기사로 제공해요.
    return "ko" if locale.lower().replace("_", "-").split("-")[0] == "ko" else "en"


def load_sources() -> list[dict]:
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))["sources"]


def normalized_text(value: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", html.unescape(value)).casefold().split())


def canonical_url(value: str) -> str | None:
    parts = urlsplit(html.unescape(value.strip()))
    if parts.scheme not in ("http", "https") or not parts.hostname:
        return None
    # 기사 식별자인 idxno 등은 보존하고 추적 매개변수만 없애요.
    query = [(k, v) for k, v in parse_qsl(parts.query, keep_blank_values=True)
             if not k.lower().startswith("utm_") and k.lower() not in ("fbclid", "gclid")]
    return urlunsplit((parts.scheme.lower(), parts.netloc.lower(), parts.path, urlencode(sorted(query)), ""))


def fingerprint(value: str) -> str:
    return sha256(value.encode("utf-8")).hexdigest()


def parse_published_at(value: str, source_timezone: str | None) -> datetime | None:
    try:
        parsed = parsedate_to_datetime(value)
    except (TypeError, ValueError):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    if parsed.tzinfo is None:
        # 풋볼리스트 RSS는 한국 현지 시각을 시간대 없이 제공해요.
        if not source_timezone:
            return None
        parsed = parsed.replace(tzinfo=ZoneInfo(source_timezone))
    return parsed.astimezone(timezone.utc)


def parse_feed(content: bytes, source: dict) -> list[dict]:
    root = ET.fromstring(content)
    channel = root.find("channel")
    if channel is None:
        raise ValueError("RSS channel is missing")
    declared_language = (channel.findtext("language") or "").lower().split("-")[0]
    if declared_language and declared_language != source["language"]:
        raise ValueError("RSS language does not match the source")
    articles = []
    for item in channel.findall("item"):
        title = BeautifulSoup(item.findtext("title") or "", "html.parser").get_text(" ", strip=True)
        url = canonical_url(item.findtext("link") or "")
        published_at = parse_published_at(item.findtext("pubDate") or "", source.get("timezone"))
        if not title or not url or published_at is None:
            continue
        image = None
        for element in item.iter():
            tag = element.tag.rsplit("}", 1)[-1]
            if tag == "thumbnail" or (tag in ("content", "enclosure") and
                    (element.get("medium") == "image" or element.get("type", "").startswith("image/"))):
                image = canonical_url(element.get("url", ""))
                if image:
                    break
        if image is None:
            # 일부 RSS는 이미지 주소를 description 또는 content:encoded 안에 넣어요.
            for element in item:
                if element.tag.rsplit("}", 1)[-1] in ("description", "encoded"):
                    img = BeautifulSoup(element.text or "", "html.parser").find("img", src=True)
                    if img:
                        image = canonical_url(img["src"])
                        if image:
                            break
        articles.append({"title": title, "url": url, "url_hash": fingerprint(url),
                         "image_url": image, "published_at": published_at,
                         "language": source["language"], "source_key": source["key"],
                         "categories": [c.text.strip() for c in item.findall("category") if c.text]})
    return articles


class TeamNewsMatcher:
    def __init__(self, teams: list[dict], aliases: dict):
        self.teams = teams
        self.terms = {}
        for team in teams:
            saved = aliases.get(str(team["team_id"]), {})
            for language in ("ko", "en"):
                terms = list(saved.get(language, []))
                self.terms[team["team_id"], language] = [normalized_text(t) for t in terms]

    def match(self, article: dict, competition_ids: list[int]) -> list[int]:
        title = normalized_text(article["title"])
        categories = {normalized_text(c) for c in article["categories"]}
        title_matches, category_matches = [], []
        for team in self.teams:
            if team["competition_id"] not in competition_ids:
                continue
            terms = self.terms[team["team_id"], article["language"]]
            for term in terms:
                # Paris와 Inter만으로는 PSG·Paris FC, Inter Miami를 구분할 수 없어요.
                title_allowed = term not in {"paris", "파리", "inter", "인테르"}
                # 한글 팀명 뒤의 조사(토트넘은 등)는 허용하고 앞 단어의 일부는 제외해요.
                end = "" if re.search("[가-힣]$", term) else r"(?![\w])"
                if term in categories and team["team_id"] not in category_matches:
                    category_matches.append(team["team_id"])
                if title_allowed and re.search(r"(?<![\w])" + re.escape(term) + end, title):
                    title_matches.append(team["team_id"])
                    break
        # EPL Index는 비교 대상 구단도 태그에 넣어요. 제목의 팀을 먼저 연결해요.
        # 제목에 팀이 없으면 단일 팀 태그로 확인되는 기사만 연결해요.
        return title_matches or (category_matches if len(category_matches) == 1 else [])


def select_news(articles: list[dict], *, language: str, now: datetime) -> list[dict]:
    now = utc_datetime(now)
    candidates = [a for a in articles if a["language"] == language
                  and now - NEWS_MAX_AGE <= utc_datetime(a["published_at"]) <= now]
    candidates.sort(key=lambda a: (utc_datetime(a["published_at"]), a["url"]), reverse=True)
    selected, urls, titles = [], set(), set()
    for article in candidates:
        url = canonical_url(article["url"])
        title = normalized_text(article["title"])
        if url is None or url in urls or title in titles:
            continue
        urls.add(url)
        titles.add(title)
        selected.append(article)
        if len(selected) == NEWS_LIMIT:
            break
    return selected
