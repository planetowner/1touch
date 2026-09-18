"""하이라이트용 경기 기록을 공급자와 공식 대회 기록에서 같은 형태로 읽어요."""
from __future__ import annotations

from datetime import datetime, timezone
import re
from zoneinfo import ZoneInfo

from bs4 import BeautifulSoup

from .fixture_states import COMPLETED_STATE_IDS


def from_sportmonks(fixture: dict, season_name: str) -> dict | None:
    if fixture["state_id"] not in COMPLETED_STATE_IDS:
        return None
    # 제목에 친선전 표시가 없어도 섞이지 않게, 확인한 공식 대회 종류만 받아요.
    if fixture["league"]["sub_type"] not in {"domestic", "domestic_cup", "cup_international"}:
        return None
    participants = {p["meta"]["location"]: p for p in fixture["participants"]}
    if set(participants) != {"home", "away"}:
        raise ValueError(f"Invalid participants: fixture={fixture['id']}")
    if any(p.get("gender") != "male" for p in participants.values()):
        return None
    scores = {s["score"]["participant"]: s["score"]["goals"] for s in fixture["scores"] if s["description"] == "CURRENT"}
    if set(scores) != {"home", "away"}:
        raise ValueError(f"Missing final scores: fixture={fixture['id']}")
    return {
        "match_key": f"sportmonks:{fixture['id']}", "fixture_id": fixture["id"],
        "competition_key": f"sportmonks:{fixture['league_id']}",
        "competition_name": fixture["league"]["name"], "season_name": season_name,
        "starting_at": fixture["starting_at"].replace(" ", "T") + "Z",
        "home": {"team_id": participants["home"]["id"], "name": participants["home"]["name"]},
        "away": {"team_id": participants["away"]["id"], "name": participants["away"]["name"]},
        "score": [scores["home"], scores["away"]], "penalty_shootout": fixture["state_id"] == 8,
        "record_source": "sportmonks", "record_url": f"https://api.sportmonks.com/v3/football/fixtures/{fixture['id']}",
    }


def from_dfb_html(document: str, source: dict, team_names: dict) -> list[dict]:
    soup = BeautifulSoup(document, "html.parser")
    rows = soup.select(".c-MatchTable-body .c-MatchTable-row")
    if not rows:
        raise ValueError("DFB match table was not found")
    result = []
    for row in rows:
        score_link = row.select_one(".c-MatchTable-score a")
        if not score_link:
            continue
        score_text = score_link.get_text(" ", strip=True)
        score = re.fullmatch(r"(\d+)\s*:\s*(\d+)(?:\s+(n\.V\.|i\.E\.))?", score_text)
        if not score:
            continue
        home = row.select_one(".c-MatchTable-team--home a").get_text(strip=True)
        away = row.select_one(".c-MatchTable-team--away a").get_text(strip=True)
        if home not in team_names and away not in team_names:
            continue
        date_text = row.select_one(".c-MatchTable-description").get_text(" ", strip=True)
        stamp = re.search(r"\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}", date_text)
        if not stamp:
            raise ValueError("DFB completed match has no kick-off time")
        started = datetime.strptime(stamp[0], "%d.%m.%Y %H:%M").replace(tzinfo=ZoneInfo("Europe/Berlin"))
        match_id = row.select_one('[id^="match_"]')["id"].removeprefix("match_")
        result.append({
            "match_key": f"dfb:{match_id}", "fixture_id": None,
            "competition_key": source["competition_key"], "competition_name": source["competition_name"],
            "season_name": source["season_name"], "starting_at": started.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            "home": {"team_id": team_names.get(home), "name": home},
            "away": {"team_id": team_names.get(away), "name": away},
            "score": [int(score[1]), int(score[2])], "penalty_shootout": score[3] == "i.E.",
            "record_source": "dfb", "record_url": score_link["href"],
        })
    return result
