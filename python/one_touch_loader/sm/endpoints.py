from __future__ import annotations
from typing import Iterable
from .helpers import classify_competition, classify_fixture_state, pick_home_away_from_participants
from ..core.http import sm

# ---- Leagues ----
def leagues_search_by_name(q: str) -> list[dict]:
    return sm.get(f"leagues/search/{q}").get("data", [])

def get_league(leag_id: int) -> dict:
    return sm.get(f"leagues/{leag_id}").get("data") or {}

# ---- Seasons ----
def seasons_by_league(leag_id: int) -> list[dict]:
    # v3 dynamic filter requires include=league for league filter
    data = sm.get("seasons", params={"include":"league", "filters": f"seasonLeagues:{leag_id}", "per_page": 50})
    out = data.get("data", [])
    # paginate if needed
    meta = data.get("meta") or {}
    has_more = meta.get("has_more")
    page = 2
    while has_more:
        data = sm.get("seasons", params={"include":"league", "filters": f"seasonLeagues:{leag_id}", "per_page": 50, "page": page})
        out.extend(data.get("data", []))
        meta = data.get("meta") or {}
        has_more = meta.get("has_more")
        page += 1
    return out

# ---- Teams ----
def teams_by_season(season_id: int) -> list[dict]:
    return sm.get(f"teams/seasons/{season_id}", params={"per_page": 50}).get("data", [])

# ---- Schedules ----
def schedule_by_season(season_id: int) -> list[dict]:
    # 응답 구조: stages -> rounds -> fixtures (participants, scores, state_id 포함)
    return sm.get(f"schedules/seasons/{season_id}").get("data", [])

def schedule_by_team(team_id: int) -> list[dict]:
    return sm.get(f"schedules/teams/{team_id}").get("data", [])

# ---- States ----
def all_states() -> dict[int, dict]:
    data = sm.get("states").get("data", [])
    return {row["id"]: row for row in data}

# ---- Helpers to flatten fixtures from schedules ----
def iter_fixtures_from_schedule(schedule_blocks: Iterable[dict]):
    for stage in schedule_blocks or []:
        for rnd in stage.get("rounds", []):
            rnd_name = rnd.get("name")
            for fx in rnd.get("fixtures", []):
                yield rnd_name, fx

def normalize_fixture_row(fx: dict, rnd_name: str, state_id_to_code: dict[int, str], league_cache: dict[int, dict]) -> dict:
    # participants
    home, away = pick_home_away_from_participants(fx.get("participants") or [])
    league_id = fx.get("league_id")
    if league_id and league_id not in league_cache:
        from .endpoints import get_league
        league_cache[league_id] = get_league(league_id) or {}
    league = league_cache.get(league_id) or {}
    comp = classify_competition(league.get("sub_type"))

    state_code = None
    st_id = fx.get("state_id")
    if st_id and st_id in state_id_to_code:
        state_code = state_id_to_code[st_id]
    status = classify_fixture_state(state_code)

    return {
        "id": fx.get("id"),
        "league_id": league_id,
        "competition": comp,
        "round_name": rnd_name,
        "leg": fx.get("leg"),
        "status": status,
        "home_id": (home.get("id") if home else None),
        "home_code": (home.get("short_code") if home else None),
        "home_logo": (home.get("image_path") if home else None),
        "away_id": (away.get("id") if away else None),
        "away_code": (away.get("short_code") if away else None),
        "away_logo": (away.get("image_path") if away else None),
    }
