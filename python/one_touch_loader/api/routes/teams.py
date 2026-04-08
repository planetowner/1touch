from __future__ import annotations

from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from ..deps import get_user_id
from ..repos.users_repo import ensure_user, set_favorite_team_id
from ..repos.teams_repo import get_team, get_teams, list_following_team_ids, set_following_teams, find_team_current_context
from ..repos.fixtures_repo import get_team_last_fixture, get_team_next_fixture, list_team_fixtures
from ..repos.standings_repo import get_team_standing
from ..repos.best_eleven_repo import get_best_eleven
from ..repos.transfers_repo import get_latest_window, get_team_transfers_by_window
from ..schemas.common import TeamOut, FixtureOut, StandingRowOut, BestElevenResponse, TeamTransfersResponse, TransferOut


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


@router.get("/teams/{team_id}/best-eleven", response_model=BestElevenResponse)
def team_best_eleven(
    team_id: int,
    season_id: int | None = Query(default=None, description="season_id (생략 시 최신 시즌)"),
    user_id: int = Depends(get_user_id),
):
    ensure_user(user_id)

    sid = season_id
    if sid is None:
        ctx = find_team_current_context(team_id)
        if not ctx:
            raise HTTPException(status_code=404, detail="Team not found")
        sid = ctx[1]

    result = get_best_eleven(team_id, sid)
    if not result:
        raise HTTPException(status_code=404, detail="Best eleven not available")
    return result


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


# ---------------------------------------------------------------------------
# Transfers
# ---------------------------------------------------------------------------

_LOAN_TYPE_IDS = {219, 220}  # SportMonks type IDs for loan-related transfers


def _make_display_type(type_name: str | None, type_id: int | None, amount: int | None) -> str | None:
    if type_id and type_id in _LOAN_TYPE_IDS:
        return "On Loan"
    if type_name and "loan" in type_name.lower():
        return "On Loan"
    if type_name and "free" in type_name.lower():
        return "Free Agent"
    if amount and amount > 0:
        if amount >= 1_000_000:
            return f"\u20ac{amount / 1_000_000:.1f}M".replace(".0M", "M")
        elif amount >= 1_000:
            return f"\u20ac{amount / 1_000:.0f}K"
        else:
            return f"\u20ac{amount}"
    if type_name:
        return type_name
    return None


def _build_transfer_out(row: dict, team_id: int) -> TransferOut:
    is_in = row.get("to_team_id") == team_id
    direction = "in" if is_in else "out"

    if is_in:
        other_team_id = row.get("from_team_id")
        other_team_name = row.get("from_team_name")
    else:
        other_team_id = row.get("to_team_id")
        other_team_name = row.get("to_team_name")

    return TransferOut(
        transfer_id=row["transfer_id"],
        player_id=row["player_id"],
        player_name=row.get("player_name"),
        player_image=row.get("player_image"),
        direction=direction,
        other_team_id=other_team_id,
        other_team_name=other_team_name,
        display_type=_make_display_type(row.get("type_name"), row.get("type_id"), row.get("amount")),
        amount=row.get("amount"),
        transfer_date=str(row["transfer_date"]) if row.get("transfer_date") else None,
    )


@router.get("/teams/{team_id}/transfers", response_model=TeamTransfersResponse)
def team_transfers(
    team_id: int,
    user_id: int = Depends(get_user_id),
):
    ensure_user(user_id)

    window = get_latest_window()
    if not window:
        raise HTTPException(status_code=404, detail="No transfer window found")

    rows = get_team_transfers_by_window(team_id, window["id"])

    transfers_in = []
    transfers_out = []
    for row in rows:
        t = _build_transfer_out(row, team_id)
        if t.direction == "in":
            transfers_in.append(t)
        else:
            transfers_out.append(t)

    window_key = f"{window['season_year']} {window['window_name']}"

    return TeamTransfersResponse(
        window_key=window_key,
        transfers_in=transfers_in,
        transfers_out=transfers_out,
    )
