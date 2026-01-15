from __future__ import annotations

from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from ..deps import get_user_id
from ..repos.users_repo import ensure_user, set_favorite_team_id
from ..repos.teams_repo import get_team, get_teams, list_following_team_ids, set_following_teams, find_team_current_context
from ..repos.fixtures_repo import get_team_last_fixture, get_team_next_fixture, list_team_fixtures
from ..repos.standings_repo import get_team_standing
from ..schemas.common import TeamOut, FixtureOut, StandingRowOut


router = APIRouter()


class PutFollowingTeamsBody(BaseModel):
    teamIds: List[int] = Field(default_factory=list)
    favoriteTeamId: Optional[int] = None


@router.get("/users/me/following/teams", response_model=List[TeamOut])
def get_following_teams(user_id: int = Depends(get_user_id)):
    ensure_user(user_id)
    ids = list_following_team_ids(user_id)
    return get_teams(ids)


@router.put("/users/me/following/teams")
def put_following_teams(body: PutFollowingTeamsBody, user_id: int = Depends(get_user_id)):
    ensure_user(user_id)
    set_following_teams(user_id, body.teamIds)
    set_favorite_team_id(user_id, body.favoriteTeamId)
    return {"ok": True}


@router.get("/teams/{team_id}")
def team_overview(team_id: int, user_id: int = Depends(get_user_id)):
    """
    Team Overview MVP:
    - team info
    - next/last match
    - standing summary (가능하면)
    """
    ensure_user(user_id)

    team = get_team(team_id)
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    next_match = get_team_next_fixture(team_id)
    last_match = get_team_last_fixture(team_id)

    standing = None
    ctx = find_team_current_context(team_id)
    if ctx:
        league_id, season_id = ctx
        standing = get_team_standing(league_id, season_id, team_id)

    return {
        "team": team,
        "next_match": next_match,
        "last_match": last_match,
        "standing": standing,
    }


@router.get("/teams/{team_id}/matches")
def team_matches(
    team_id: int,
    status: str | None = Query(default=None, description="past|live|upcoming"),
    start: str | None = Query(default=None, description="YYYY-MM-DD"),
    end: str | None = Query(default=None, description="YYYY-MM-DD"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    user_id: int = Depends(get_user_id),
):
    ensure_user(user_id)
    items = list_team_fixtures(team_id, status=status, start_date=start, end_date=end, limit=limit, offset=offset)
    return {"items": items, "limit": limit, "offset": offset}
