from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query

from ..deps import get_user_id
from ..repos.users_repo import ensure_user
from ..repos.fixtures_repo import get_fixture, list_head2head

router = APIRouter()


@router.get("/fixtures/{fixture_id}")
def fixture_detail(fixture_id: int, user_id: int = Depends(get_user_id)):
    ensure_user(user_id)
    fx = get_fixture(fixture_id)
    if not fx:
        raise HTTPException(status_code=404, detail="Fixture not found")
    return fx


@router.get("/fixtures/{fixture_id}/head2head")
def fixture_head2head(
    fixture_id: int,
    limit: int = Query(default=10, ge=1, le=50),
    user_id: int = Depends(get_user_id),
):
    ensure_user(user_id)
    fx = get_fixture(fixture_id)
    if not fx:
        raise HTTPException(status_code=404, detail="Fixture not found")

    team_a = int(fx["home_team_id"])
    team_b = int(fx["away_team_id"])
    items = list_head2head(team_a, team_b, limit=limit)
    return {"fixture_id": fixture_id, "team_a": team_a, "team_b": team_b, "items": items}
