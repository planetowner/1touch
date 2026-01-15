from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query

from ..deps import get_user_id
from ..repos.users_repo import ensure_user
from ..repos.standings_repo import get_current_season_id_for_league, list_standings

router = APIRouter()


@router.get("/leagues/{league_id}/standings")
def league_standings(
    league_id: int,
    season_id: int | None = Query(default=None),
    phase: str = Query(default="league", description="league|group|league_phase"),
    group_name: str = Query(default="", description="group name for group-phase"),
    user_id: int = Depends(get_user_id),
):
    ensure_user(user_id)

    sid = season_id or get_current_season_id_for_league(league_id)
    if not sid:
        raise HTTPException(status_code=404, detail="Season not found for league")

    rows = list_standings(league_id=league_id, season_id=sid, phase=phase, group_name=group_name)
    return {"league_id": league_id, "season_id": sid, "phase": phase, "group_name": group_name, "rows": rows}
