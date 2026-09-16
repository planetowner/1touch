"""Analyst 공개 일정 페이지에 포함된 시즌 전체 경기 목록을 읽어요."""

from __future__ import annotations

import json
from datetime import datetime
from urllib.parse import urlencode

from bs4 import BeautifulSoup
import requests


# 2026-09-13 각 대회 페이지의 Fixtures 링크와 competition ID를 직접 대조했어요.
COMPETITIONS = {
    8: ("premier-league", "2kwbbcootiqqgmrzs6o5inle5"),
    82: ("bundesliga", "6by3h89i2eykc341oz7lv1ddd"),
    301: ("ligue-1", "dm5ka0os1e3dxcp3vh05kmp33"),
    384: ("serie-a", "1r097lpxe0xn03ihb7wi98kao"),
    564: ("la-liga", "34pl8szyvrbwcmfkuocjm3r6t"),
    2: ("uefa-champions-league", "4oogyu6o156iphvdvphwpck10"),
    5: ("uefa-europa-league", "4c1nfi2j1m731hcay25fcgndq"),
    2286: ("uefa-conference-league", "c7b8o53flg36wbuevfzy3lb10"),
}


def normalize_schedule(attributes: dict, schedule: dict, competition_id: int) -> dict:
    calendar = schedule["tournamentCalendar"]
    external_competition = COMPETITIONS[competition_id][1]
    if attributes["comp"] != external_competition or attributes["tmcl"] != calendar["id"]:
        raise ValueError("일정의 대회·시즌 ID가 페이지 설정과 달라요.")
    matches = {}
    for day in schedule["matchDate"]:
        for match in day["match"]:
            ids = {"competitionId": external_competition, "seasonId": calendar["id"], "matchId": match["id"]}
            item = {
                "external_fixture_id": match["id"],
                "home_external_team_id": match["homeContestantId"],
                "away_external_team_id": match["awayContestantId"],
                "date": match["date"].removesuffix("Z"),
                "time": match.get("time"),
                "url": "https://theanalyst.com/opta-football-match-centre?" + urlencode(ids),
            }
            datetime.strptime(item["date"], "%Y-%m-%d")
            if item["external_fixture_id"] in matches and matches[item["external_fixture_id"]] != item:
                raise ValueError("같은 Opta 경기 ID의 일정이 달라요.")
            matches[item["external_fixture_id"]] = item
    return {"competition_id": competition_id, "season_name": calendar["name"],
            "external_season_id": calendar["id"],
            "matches": sorted(matches.values(), key=lambda m: (m["date"], m["time"] or "", m["external_fixture_id"]))}


def fetch_schedule(competition_id: int) -> dict:
    slug, _ = COMPETITIONS[competition_id]
    url = f"https://theanalyst.com/competition/{slug}/fixtures"
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    block = BeautifulSoup(response.text, "html.parser").select_one(".wp-block-sdapi-blocks-fixtures-and-results")
    if block is None or block.select_one(".schedule") is None or block.select_one(".attributes") is None:
        raise ValueError(f"공개 일정 페이지에서 경기 목록을 찾지 못했어요: {url}")
    # 로그인이나 피드 키 없이 내려오는 공개 HTML이에요. 페이지의 전체 시즌 목록을 사용해요.
    result = normalize_schedule(json.loads(block.select_one(".attributes").get_text()),
                                json.loads(block.select_one(".schedule").get_text()), competition_id)
    result["source_url"] = url
    return result
