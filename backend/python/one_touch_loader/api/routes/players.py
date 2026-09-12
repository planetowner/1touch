from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException

from ..db import fetch_one_dict
from ..deps import get_user_id
from ..repos.transfers_repo import get_player_club_history

router = APIRouter()


@router.get("/players/{player_id}/club-history")
def player_club_history(player_id: int, user_id: int = Depends(get_user_id)):
    if fetch_one_dict("SELECT player_id FROM players WHERE player_id=%s", (player_id,)) is None:
        raise HTTPException(status_code=404, detail="Player not found")
    return get_player_club_history(player_id, date.today())
