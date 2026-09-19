"""공식 영상과 남자 1군 경기 기록을 대조하고, 시청 국가별 최근 3경기를 골라요."""
from __future__ import annotations

from collections import defaultdict
import html
import json
from pathlib import Path
import re
import unicodedata

from .datetime_utils import utc_datetime


CATALOG_PATH = Path(__file__).with_name("youtube_highlights_catalog.json")
HIGHLIGHT = re.compile(r"\b(highlights?|highights|hl|resum\w*|sintesi|match recap)\b")
# 같은 채널·상대 이름이어도 유스 경기와 1군 경기가 같은 주에 열릴 수 있어요.
EXCLUDED = re.compile(
    r"\b(u[ -]?(?:1[0-9]|2[0-3])|uyl|academy|academie|youth|junior\w*|"
    r"women\w*|femenin\w*|feminin\w*|femminil\w*|frauen|primavera|next gen|"
    r"pl2|premier league 2|premier league international cup|classic\w*|rewind|"
    r"throwback|flashback|friendly|friendlies|pre season|preseason|pretemporada|"
    r"amichevol\w*|testspiel|netradio|shorts|sevilla atletico|celta fortuna|"
    r"bilbao athletic|sanse|atletico malagueno|groupe elite|n2|reserves?|"
    r"telekom cup)\b"
)
# 정상 하이라이트 설명에도 'all goals', 'full match highlights'가 쓰여요. 모음·중계 판정은 제목에만 적용해요.
FORMAT_EXCLUDED = re.compile(
    r"netradio|\b(watchparty|live|full match(?! highlights)|match complet|partido completo|"
    r"compilation|all highlights|every goal\w*|all goals|full penalty shoot)\b"
)
NON_MATCH = re.compile(
    r"\b(react\w*|interview\w*|press|pressekonferenz|konferenz|pk|vlog|pitchside|access|inside|"
    r"bench cam|player cam|all angles|behind|film|avant match|apres match)\b"
)
SCORE = re.compile(r"(?<!\d)(\d{1,2})\s*[-–—:]\s*(\d{1,2})(?!\d)")


def load_catalog() -> dict:
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKD", html.unescape(value)).casefold()
    value = "".join(c for c in value if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", value).strip()


def name_variants(team: dict, aliases: dict) -> list[str]:
    variants = aliases.get(str(team.get("team_id")), []) + aliases.get(team["name"], [])
    # Sportmonks의 Paris는 Paris FC예요. Paris만 찾으면 PSG 영상까지 섞여요.
    if team.get("team_id") != 4508:
        canonical = normalize(team["name"])
        variants = [canonical, re.sub(r"\b(fc|afc|cf|fsv|tsg|sc|vfb|vfl|tsv|sv|ac|as|ssc|rcd|rc|ogc|sco|1899|1907|1893)\b", "", canonical), *variants, *team.get("aliases", [])]
    return sorted({normalize(v) for v in variants if len(normalize(v)) >= 2})


def contains_team(text: str, team: dict, aliases: dict) -> bool:
    return team_match_length(text, team, aliases) > 0


def team_match_length(text: str, team: dict, aliases: dict) -> int:
    return max((len(name) for name in name_variants(team, aliases) if f" {name} " in f" {text} "), default=0)


def title_has_home_away_order(title: str, match: dict, aliases: dict) -> bool:
    # 같은 상대와 치른 1·2차전도 제목의 '홈팀 v 원정팀' 순서로 구분해요.
    return any(f" {home} {separator} {away} " in f" {title} "
               for home in name_variants(match["home"], aliases)
               for away in name_variants(match["away"], aliases)
               for separator in ("v", "vs"))


def duration_seconds(value: str) -> int:
    match = re.fullmatch(r"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?", value)
    if not match:
        raise ValueError("Invalid YouTube duration")
    return sum(int(v or 0) * factor for v, factor in zip(match.groups(), (3600, 60, 1)))


def normalize_video(item: dict) -> dict | None:
    if item.get("unavailable"):
        return None
    snippet, content, status = item["snippet"], item["contentDetails"], item["status"]
    if status.get("privacyStatus") != "public" or status.get("uploadStatus") != "processed":
        return None
    if snippet.get("liveBroadcastContent", "none") != "none":
        return None
    player = item.get("player", {})
    # 70초짜리 정식 하이라이트도 있어요. 길이 대신 확인된 세로 영상과 Shorts 표기를 제외해요.
    if player.get("embedWidth") and player.get("embedHeight"):
        if int(player["embedHeight"]) >= int(player["embedWidth"]):
            return None
    thumbnails = snippet.get("thumbnails", {})
    thumbnail = next((thumbnails[s]["url"] for s in ("maxres", "standard", "high", "medium", "default") if s in thumbnails), None)
    return {
        "video_id": item["id"], "video_url": f"https://www.youtube.com/watch?v={item['id']}",
        "title": html.unescape(snippet["title"]), "description": snippet.get("description", ""),
        "channel_id": snippet["channelId"], "channel_name": snippet["channelTitle"],
        "thumbnail_url": thumbnail, "published_at": snippet["publishedAt"],
        "duration_seconds": duration_seconds(content["duration"]),
        "region_restriction": content.get("regionRestriction", {}),
        "embeddable": bool(status.get("embeddable")),
        "is_extended": "extended" in normalize(snippet["title"]),
    }


def match_video(video: dict, matches: list[dict], source: dict, aliases: dict,
                highlight_ids: set[str]) -> tuple[dict | None, str]:
    if video["channel_id"] != source["channel_id"]:
        return None, "different_channel"
    title = normalize(video["title"])
    # 설명 하단의 다음 경기 광고·공통 안내는 상대 팀 판정에 쓰지 않아요.
    description = normalize(video["description"].split("\n\n")[0][:650])
    text = title + " " + description
    if EXCLUDED.search(title) or EXCLUDED.search(description) or FORMAT_EXCLUDED.search(title):
        return None, "not_first_team_match_highlights"
    explicit = bool(HIGHLIGHT.search(title))
    if not explicit and NON_MATCH.search(title):
        return None, "non_match_format"
    scores = [sorted((int(a), int(b))) for a, b in SCORE.findall(video["title"]) if int(a) < 20 and int(b) < 20]
    accepted_format = explicit or bool(HIGHLIGHT.search(description)) or video["video_id"] in highlight_ids
    if source.get("score_title") and scores:
        accepted_format = True
    if any(re.search(pattern, title) for pattern in source.get("title_patterns", [])):
        accepted_format = True
    if not accepted_format:
        return None, "unconfirmed_highlight_format"
    published = utc_datetime(video["published_at"])
    possible = []
    for match in matches:
        if published < utc_datetime(match["starting_at"]):
            continue
        # 과거 시즌을 제목에 명시한 재업로드는 현재 시즌의 같은 대진에 연결하지 않아요.
        years = re.findall(r"\b(20\d{2})\s*[/–-]\s*(?:20)?\d{2}\b", video["title"])
        if years and int(match["season_name"][:4]) not in [int(y) for y in years]:
            continue
        if source["kind"] == "club":
            if source["team_id"] not in (match["home"].get("team_id"), match["away"].get("team_id")):
                continue
            required = [p for p in (match["home"], match["away"]) if p.get("team_id") != source["team_id"]]
        else:
            if match["competition_key"] not in source["competition_keys"]:
                continue
            required = [match["home"], match["away"]]
        if not all(contains_team(text, p, aliases) for p in required):
            continue
        # 컵 영상에는 승부차기만 쓰거나 본경기 득점까지 더한 실제 표기가 모두 있어요.
        if scores and not match["penalty_shootout"] and sorted(match["score"]) not in scores:
            continue
        # HEBC의 전체 이름에도 Hamburg가 들어가요. 같은 글에서는 더 구체적인 팀명을 우선해요.
        evidence = (all(contains_team(title, p, aliases) for p in required),
                    sum(team_match_length(text, p, aliases) for p in required),
                    title_has_home_away_order(title, match, aliases))
        possible.append((match, evidence))
    best_evidence = max((evidence for _, evidence in possible), default=None)
    possible_matches = [match for match, evidence in possible if evidence == best_evidence]
    if len(possible_matches) != 1:
        return None, "ambiguous_match" if possible_matches else "no_matching_fixture"
    return possible_matches[0], "matched"


def available_in(video: dict, viewer_country: str) -> bool:
    restriction = video.get("region_restriction") or {}
    return viewer_country not in restriction.get("blocked", []) and (
        "allowed" not in restriction or viewer_country in restriction["allowed"]
    )


def select_latest_matches(candidates: list[dict], viewer_country: str | None, limit: int = 3) -> list[dict]:
    country = viewer_country.upper() if viewer_country is not None else None
    if country is not None and not re.fullmatch(r"[A-Z]{2}", country):
        raise ValueError("viewer_country must be a two-letter country code")
    by_match = defaultdict(list)
    for candidate in candidates:
        # 국가를 보내지 않는 경기 화면은 외부 YouTube에서 재생 가능 여부를 판단해요.
        if country is None or available_in(candidate, country):
            by_match[candidate["match"]["match_key"]].append(candidate)
    selected = []
    for choices in by_match.values():
        # 국가 제한을 먼저 적용해야 막힌 구단 영상 대신 같은 경기의 대회 영상을 고를 수 있어요.
        choices.sort(key=lambda v: (v["source_type"] != "club", v["is_extended"],
                                    utc_datetime(v["published_at"]), v["video_id"]))
        selected.append(choices[0])
    selected.sort(key=lambda v: (v["match"]["starting_at"], v["match"]["match_key"]), reverse=True)
    return selected[:limit]
