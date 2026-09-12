from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query

from ..deps import get_user_id
from ..repos.standings_repo import (
    get_current_season_id_for_competition,
    list_standings,
)
from ..repos.expected_goals_repo import list_xg_standings
from ...core.understat import UNDERSTAT_LEAGUES

router = APIRouter()


@router.get("/competitions/{competition_id}/xg-standings")
def competition_xg_standings(
    competition_id: int,
    season_id: int | None = Query(default=None),
    user_id: int = Depends(get_user_id),
):
    if competition_id not in UNDERSTAT_LEAGUES:
        raise HTTPException(status_code=400, detail="xG standings support Big 5 leagues only")
    sid = season_id or get_current_season_id_for_competition(competition_id)
    if sid is None:
        raise HTTPException(status_code=404, detail="Season not found for competition")
    return {"competition_id": competition_id, "season_id": sid, "provider": "understat",
            "xpts_method": "historical_draw_rate", "rows": list_xg_standings(competition_id, sid)}


@router.get("/competitions/{competition_id}/standings")
def competition_standings(
    competition_id: int,
    season_id: int | None = Query(default=None),
    user_id: int = Depends(get_user_id),
):

    sid = season_id or get_current_season_id_for_competition(competition_id)
    if not sid:
        raise HTTPException(status_code=404, detail="Season not found for competition")

    rows = list_standings(
        competition_id=competition_id,
        season_id=sid,
    )
    return {
        "competition_id": competition_id,
        "season_id": sid,
        "rows": rows,
    }
