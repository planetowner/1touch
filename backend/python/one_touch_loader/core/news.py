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
from urllib.parse import parse_qsl, urlencode, urljoin, urlsplit, urlunsplit
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


def parse_published_at(value: str, source_timezone: str | None, date_format: str | None = None) -> datetime | None:
    if date_format:
        # 스타뉴스의 숫자 날짜와 노컷뉴스의 숫자 월은 표준 RSS 날짜 파서가 읽지 못해요.
        try:
            parsed = datetime.strptime(value, date_format)
        except ValueError:
            return None
    else:
        try:
            parsed = parsedate_to_datetime(value)
        except (TypeError, ValueError):
            try:
                parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            except ValueError:
                return None
    if parsed.tzinfo is None:
        # 일부 한국어 매체는 한국 현지 시각을 시간대 없이 제공해요.
        if not source_timezone:
            return None
        parsed = parsed.replace(tzinfo=ZoneInfo(source_timezone))
    return parsed.astimezone(timezone.utc)


def _article(source: dict, *, title: str, url: str, published_at: str,
             image_url: str | None = None, categories: list[str] | None = None) -> dict | None:
    title = BeautifulSoup(html.unescape(title), "html.parser").get_text(" ", strip=True)
    url = canonical_url(url)
    published_at = parse_published_at(published_at, source.get("timezone"), source.get("date_format"))
    if not title or not url or published_at is None:
        return None
    return {"title": title, "url": url, "url_hash": fingerprint(url), "image_url": image_url,
            "published_at": published_at, "language": source["language"], "source_key": source["key"],
            "categories": categories or []}


def parse_news_sitemap(root: ET.Element, source: dict) -> list[dict]:
    ns = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9",
          "n": "http://www.google.com/schemas/sitemap-news/0.9"}
    if root.tag != "{" + ns["s"] + "}urlset":
        raise ValueError("News sitemap urlset is missing")
    articles = []
    for item in root.findall("s:url", ns):
        if item.findtext("n:news/n:publication/n:language", namespaces=ns) != source["language"]:
            continue
        # lastmod는 수정일이에요. 원 발행일만 쓰고, 본문 검색어인 keywords는 구단 태그로 취급하지 않아요.
        row = _article(source, title=item.findtext("n:news/n:title", "", ns),
                       url=item.findtext("s:loc", "", ns),
                       published_at=item.findtext("n:news/n:publication_date", "", ns))
        if row:
            articles.append(row)
    if len(root) and not articles:
        raise ValueError("News sitemap has no valid articles for the source language")
    return articles


def parse_feed(content: bytes, source: dict) -> list[dict]:
    # 스타뉴스·스포츠타임스는 EUC-KR XML을 보내므로 선언한 인코딩으로 먼저 읽어요.
    encoding = re.search(br'<\?xml[^>]*encoding=["\x27]([^"\x27]+)', content[:150], re.I)
    root = ET.fromstring(content.decode(encoding.group(1).decode("ascii")) if encoding else content)
    if source.get("format") == "news_sitemap":
        return parse_news_sitemap(root, source)
    channel = root.find("channel")
    if channel is None:
        raise ValueError("RSS channel is missing")
    declared_language = (channel.findtext("language") or "").lower().split("-")[0]
    # FCBinside 영어판은 기사 원문과 달리 RSS의 language를 de로 보내요. 확인한 매체만 별도로 지정해요.
    if declared_language and declared_language != source.get("feed_language", source["language"]):
        raise ValueError("RSS language does not match the source")
    articles = []
    for item in channel.findall("item"):
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
        row = _article(source, title=item.findtext("title") or "", url=item.findtext("link") or "",
                       # 일간스포츠·스포츠경향은 pubDate 대신 표준 dc:date를 제공해요.
                       published_at=item.findtext("pubDate") or item.findtext("{http://purl.org/dc/elements/1.1/}date") or "",
                       image_url=image, categories=[c.text.strip() for c in item.findall("category") if c.text])
        if row:
            articles.append(row)
    if channel.findall("item") and not articles:
        raise ValueError("RSS entries have no valid article metadata")
    return articles


def article_links(content: bytes, source: dict) -> list[str]:
    soup = BeautifulSoup(content, "html.parser")
    links = [canonical_url(urljoin(source["feed_url"], a["href"]))
             for a in soup.select(source["article_selector"])]
    return list(dict.fromkeys(url for url in links if url))


def parse_article_page(content: bytes, source: dict, url: str) -> dict | None:
    soup = BeautifulSoup(content, "html.parser")
    metadata = {tag.get("property", tag.get("name")): tag.get("content", "") for tag in soup.select("meta")}
    declared_language = (soup.html.get("lang", "") if soup.html else "").lower().split("-")[0]
    if declared_language and declared_language != source["language"]:
        raise ValueError("Article language does not match the source")
    # OSEN·스포츠서울·스포츠동아는 같은 Open Graph 발행 메타데이터를 제공해요.
    return _article(source, title=metadata.get("og:title", ""), url=url,
                    published_at=metadata.get("article:published_time", ""),
                    image_url=canonical_url(metadata.get("og:image", "")),
                    categories=[metadata[k] for k in ("article:section", "og:category") if metadata.get(k)])


class TeamNewsMatcher:
    def __init__(self, teams: list[dict], aliases: dict):
        self.team_ids = [team["team_id"] for team in teams]
        self.terms = {}
        self.exclusions = {}
        self.category_required = {}
        for team in teams:
            team_id = team["team_id"]
            saved = aliases.get(str(team_id), {})
            # 한국어 기사에도 PSG·ATL 같은 영문 구단명이 나와요. 기사 언어와 이름 표기는 별개예요.
            terms = {normalized_text(t) for language in ("ko", "en") for t in saved.get(language, [])}
            self.terms[team_id] = {term: self._pattern(term) for term in terms}
            self.exclusions[team_id] = [self._pattern(normalized_text(t))
                                        for t in saved.get("excluded_phrases", [])]
            self.category_required[team_id] = {normalized_text(t)
                                                for t in saved.get("title_requires_category", [])}

    @staticmethod
    def _pattern(term: str) -> re.Pattern:
        # '뮌헨글라트바흐' 안의 '뮌헨'은 제외하고 조사·경기 접미사('뮌헨과', '오사수나전도')는 허용해요.
        suffix = r"(?=(?:전(?:도)?|에서|으로|은|는|이|가|을|를|의|와|과|도|만|에|서|로)?(?!\w))"
        return re.compile(r"(?<!\w)" + re.escape(term) + suffix)

    def match(self, article: dict) -> list[int]:
        # 붙여 쓴 대진 표기('맨체스터 유나이티드vs리버풀')도 양쪽 팀을 구분해요.
        title = re.sub(r"(?<=[가-힣])vs(?=[가-힣])", " vs ", normalized_text(article["title"]))
        categories = {normalized_text(c) for c in article["categories"]}
        spans, category_matches = [], []
        for team_id in self.team_ids:
            terms = self.terms[team_id]
            excluded = [m.span() for pattern in self.exclusions[team_id] for m in pattern.finditer(title)]
            tagged = bool(categories.intersection(terms))
            if tagged and not excluded:
                category_matches.append(team_id)
            for term, pattern in terms.items():
                # nice는 일반 형용사이기도 해서 짧은 표기만 있을 때는 구단 태그를 함께 확인해요.
                if term in self.category_required[team_id] and not tagged:
                    continue
                for match in pattern.finditer(title):
                    start, end = match.span()
                    if not any(left <= start and end <= right for left, right in excluded):
                        spans.append((start, end, team_id))
        # Inter Milan 안의 Milan처럼 다른 구단의 긴 이름에 포함된 표기는 별도 팀으로 연결하지 않아요.
        title_matches = {team_id for start, end, team_id in spans
                         if not any(left <= start and end <= right and (left, right) != (start, end)
                                    for left, right, _ in spans)}
        # EPL Index는 비교 대상 구단도 태그에 넣어요. 제목의 팀을 먼저 연결해요.
        # 제목에 팀이 없으면 단일 팀 태그로 확인되는 기사만 연결해요.
        return ([team_id for team_id in self.team_ids if team_id in title_matches]
                or (category_matches if len(category_matches) == 1 else []))


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
