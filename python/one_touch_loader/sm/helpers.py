from __future__ import annotations
from typing import Any

def pick_home_away_from_participants(participants: list[dict]) -> tuple[dict, dict]:
    home = away = None
    for p in participants or []:
        loc = ((p.get("meta") or {}).get("location") or "").lower()
        if loc == "home":
            home = p
        elif loc == "away":
            away = p
    return home or {}, away or {}

def classify_competition(sub_type: str | None) -> str:
    """
    Map league sub_type/type to our 3-way classification.
    - domestic -> 'league'
    - domestic_cup -> 'cup' (요청 표현 '리그컵')
    - cup_international -> 'europe'
    기타는 league 기본값
    """
    if not sub_type:
        return "league"
    sub_type = sub_type.lower()
    if sub_type == "domestic_cup":
        return "cup"
    if sub_type in ("cup_international",):
        return "europe"
    return "league"

def classify_fixture_state(state_code: str | None) -> str:
    """
    Reduce Sportmonks 'state' code to past/live/upcoming.
    """
    if not state_code:
        return "upcoming"
    code = state_code.upper()
    if code in ("NS", "TBA", "TBD", "POSTP"):
        return "upcoming"
    if code.startswith("INPLAY") or code in ("LIVE", "HT", "ET", "ET_BREAK", "PEN_LIVE"):
        return "live"
    # finished / abandoned / awarded 등은 past 로 본다
    return "past"
