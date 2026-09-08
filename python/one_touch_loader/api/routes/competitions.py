from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query

from ..deps import get_user_id
from ..repos.standings_repo import (
    get_current_season_id_for_competition,
    list_standings,
)
from ..repos.users_repo import ensure_user

router = APIRouter()


@router.get("/competitions/{competition_id}/standings")
def competition_standings(
    competition_id: int,
    season_id: int | None = Query(default=None),
    user_id: int = Depends(get_user_id),
):
    ensure_user(user_id)

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
