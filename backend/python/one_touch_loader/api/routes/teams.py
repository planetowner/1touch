from __future__ import annotations

from datetime import date
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from ..deps import get_user_id
from ..services.user_preferences import FavoriteTeamCooldownError
from ..repos.teams_repo import get_team, get_teams, list_following_team_ids, set_following_and_favorite, find_team_current_context
from ..repos.fixtures_repo import get_team_last_fixture, get_team_next_fixture, list_team_fixtures
from ..repos.standings_repo import get_team_standing
from ..repos.best_eleven_repo import get_best_eleven
from ..repos.injuries_repo import get_team_injuries
from ..repos.points_pace_repo import (
    build_current_form_comparison,
    get_points_pace_series,
    list_current_form_options,
)
from ...core.transfer_windows import get_latest_transfer_window
from ..repos.transfers_repo import get_team_transfers_by_window
from ..repos.contracts_repo import get_team_contracts
from ..schemas.common import (
    BestElevenResponse,
    CurrentFormOptionsResponse,
    CurrentFormResponse,
    TeamOut,
    TeamInjuriesResponse,
    TeamTransfersResponse,
    TransferOut,
    TeamContractsResponse,
)


router = APIRouter()


@router.get("/teams/{team_id}/contracts", response_model=TeamContractsResponse)
def team_contracts(team_id: int, descending: bool = False, user_id: int = Depends(get_user_id)):
    context = find_team_current_context(team_id)
    if context is None:
        raise HTTPException(status_code=404, detail="Current Big 5 team-season not found")
    return get_team_contracts(team_id, context[1], descending=descending)


class PutFollowingTeamsBody(BaseModel):
    teamIds: List[int] = Field(min_length=1, max_length=5)
    favoriteTeamId: int = Field(gt=0)


@router.get("/users/me/following/teams", response_model=List[TeamOut])
def get_following_teams(user_id: int = Depends(get_user_id)):
    ids = list_following_team_ids(user_id)
    by_id = {row['team_id']: row for row in get_teams(ids)}
    return [by_id[team_id] for team_id in ids]


@router.put("/users/me/following/teams")
def put_following_teams(body: PutFollowingTeamsBody, user_id: int = Depends(get_user_id)):

    try:
        set_following_and_favorite(user_id, body.teamIds, body.favoriteTeamId)
    except FavoriteTeamCooldownError as exc:
        raise HTTPException(409, {"message": str(exc), "available_at": exc.available_at.isoformat() + "Z"}) from exc
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    return {"ok": True}


@router.get("/teams/{team_id}")
def team_overview(team_id: int, user_id: int = Depends(get_user_id)):
    """
    팀 개요 MVP에 필요한 정보를 모아요.
    - 팀 정보
    - 다음 경기와 최근 경기
    - 가능하면 순위 요약
    """

    team = get_team(team_id)
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    next_match = get_team_next_fixture(team_id)
    last_match = get_team_last_fixture(team_id)

    standing = None
    ctx = find_team_current_context(team_id)
    if ctx:
        competition_id, season_id = ctx
        standing = get_team_standing(competition_id, season_id, team_id)

    return {
        "team": team,
        "next_match": next_match,
        "last_match": last_match,
        "standing": standing,
    }


@router.get("/teams/{team_id}/injuries", response_model=TeamInjuriesResponse)
def team_injuries(team_id: int, user_id: int = Depends(get_user_id)):
    context = find_team_current_context(team_id)
    if context is None:
        raise HTTPException(status_code=404, detail="Current Big 5 team-season not found")
    # 현재 부상 목록이라 과거 시즌을 지정하는 조회는 제공하지 않아요.
    return get_team_injuries(team_id, context[1])


@router.get("/teams/{team_id}/best-eleven", response_model=BestElevenResponse)
def team_best_eleven(
    team_id: int,
    season_id: int | None = Query(
        default=None,
        description=(
            "Big 5 정규리그 대표 season_id "
            "(해당 시즌명의 정규리그·컵·유럽대항전 전체 합산; 생략 시 현재 시즌)"
        ),
    ),
    formation: str | None = Query(
        default=None,
        min_length=1,
        max_length=20,
        description="선택 포메이션 (생략 시 가장 많이 사용한 포메이션)",
    ),
    user_id: int = Depends(get_user_id),
):

    sid = season_id
    if sid is None:
        ctx = find_team_current_context(team_id)
        if not ctx:
            raise HTTPException(status_code=404, detail="Team not found")
        sid = ctx[1]

    result = get_best_eleven(team_id, sid, formation=formation)
    if not result:
        detail = (
            f"Best eleven formation not available: {formation}"
            if formation is not None
            else "Best eleven not available"
        )
        raise HTTPException(status_code=404, detail=detail)
    return result


@router.get(
    "/teams/{team_id}/current-form/options",
    response_model=CurrentFormOptionsResponse,
)
def team_current_form_options(
    team_id: int,
    search: str | None = Query(default=None, max_length=100),
    limit: int = Query(default=200, ge=1, le=1000),
    user_id: int = Depends(get_user_id),
):
    if not get_team(team_id):
        raise HTTPException(status_code=404, detail="Team not found")

    return {
        "items": list_current_form_options(search=search, limit=limit),
        "limit": limit,
    }


@router.get(
    "/teams/{team_id}/current-form",
    response_model=CurrentFormResponse,
)
def team_current_form(
    team_id: int,
    compare_team_id: int = Query(gt=0),
    compare_season_id: int = Query(gt=0),
    season_id: int | None = Query(
        default=None,
        description="현재 팀의 Big 5 정규리그 season_id (생략 시 현재 시즌)",
    ),
    user_id: int = Depends(get_user_id),
):

    current_season_id = season_id
    if current_season_id is None:
        context = find_team_current_context(team_id)
        if context is None:
            raise HTTPException(
                status_code=404,
                detail="Current Big 5 team-season not found",
            )
        current_season_id = context[1]

    current = get_points_pace_series(team_id, current_season_id)
    if current is None:
        raise HTTPException(
            status_code=404,
            detail="Current team-season not available for points pace",
        )

    comparison = get_points_pace_series(
        compare_team_id,
        compare_season_id,
    )
    if comparison is None:
        raise HTTPException(
            status_code=404,
            detail="Comparison team-season not available for points pace",
        )

    return build_current_form_comparison(current, comparison)


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
    items = list_team_fixtures(team_id, status=status, start_date=start, end_date=end, limit=limit, offset=offset)
    return {"items": items, "limit": limit, "offset": offset}


# ---------------------------------------------------------------------------
# 이적
# ---------------------------------------------------------------------------

def _build_transfer_out(row: dict, team_id: int) -> TransferOut:
    is_in = row["to_team_id"] == team_id
    side = "from" if is_in else "to"
    # 금액 0이나 NULL로 자유 이적을 추정하지 않아요. 통화 미확인 금액에 유로 기호도 붙이지 않아요.
    return TransferOut(
        transfer_id=row["transfer_id"], player_id=row["player_id"],
        player_name=row["player_name"], player_image=row["player_image"],
        direction="in" if is_in else "out", other_team_id=row[f"{side}_team_id"],
        other_team_name=row[f"{side}_team_name"], other_team_image=row[f"{side}_team_image"],
        jersey_number=row["jersey_number"], type_id=row["type_id"],
        display_type=row["type_name"], amount=row["amount"], currency=None,
        transfer_date=str(row["transfer_date"]),
        contract_start_date=row["contract_start_date"], contract_end_date=row["contract_end_date"],
    )


@router.get("/teams/{team_id}/transfers", response_model=TeamTransfersResponse)
def team_transfers(team_id: int, user_id: int = Depends(get_user_id)):
    context = find_team_current_context(team_id)
    if context is None:
        raise HTTPException(status_code=404, detail="Current Big 5 team-season not found")
    as_of = date.today()
    window = get_latest_transfer_window(context[0], as_of)
    if window is None:
        raise HTTPException(status_code=404, detail="No verified transfer window found")
    rows = get_team_transfers_by_window(team_id, context[1], window, as_of)
    items = [_build_transfer_out(row, team_id) for row in rows]
    return TeamTransfersResponse(
        window_key=f"{window['season_name']} {window['window_name']}",
        transfers_in=[item for item in items if item.direction == "in"],
        transfers_out=[item for item in items if item.direction == "out"],
    )
