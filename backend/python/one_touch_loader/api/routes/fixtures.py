from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query

from ..deps import get_user_id
from ..repos.fixtures_repo import get_fixture, get_fixture_detail, list_head2head

router = APIRouter()


@router.get("/fixtures/{fixture_id}")
def fixture_detail(fixture_id: int, user_id: int = Depends(get_user_id)):
    """경기 상세와 player_statistics의 포지션별 지표를 반환해요.

    player_statistics와 lineups는 (team_id, player_id)로 연결해요.
    categories의 순서대로 표시하고, 지표의 null은 미제공으로 구분해요.
    pair는 numerator/denominator, percentage는 0~100의 value를 사용해요.
    xG는 Understat, 나머지 선수 지표·평점·POM은 Sportmonks 값이에요.
    """
    fx = get_fixture_detail(fixture_id)
    if not fx:
        raise HTTPException(status_code=404, detail="Fixture not found")
    return fx


@router.get("/fixtures/{fixture_id}/head2head")
def fixture_head2head(
    fixture_id: int,
    limit: int = Query(default=10, ge=1, le=50),
    user_id: int = Depends(get_user_id),
):
    fx = get_fixture(fixture_id)
    if not fx:
        raise HTTPException(status_code=404, detail="Fixture not found")

    team_a = int(fx["home_team_id"])
    team_b = int(fx["away_team_id"])
    items = list_head2head(team_a, team_b, limit=limit)
    return {"fixture_id": fixture_id, "team_a": team_a, "team_b": team_b, "items": items}
