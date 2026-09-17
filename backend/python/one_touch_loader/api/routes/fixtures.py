from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query

from ..deps import get_user_id
from ..repos.fixtures_repo import get_fixture, get_fixture_detail, list_head2head
from ..repos.opta_shots_repo import get_shotmap
from ..repos.opta_analysis_repo import get_analysis

router = APIRouter()


def _opta_fixture_data(fixture_id: int, read_data):
    if not get_fixture(fixture_id):
        raise HTTPException(status_code=404, detail="Fixture not found")
    return read_data(fixture_id)


@router.get("/fixtures/{fixture_id}/analysis")
def fixture_analysis(fixture_id: int, user_id: int = Depends(get_user_id)):
    """Opta 패스·수비 행동과 1Touch 계산 지표를 반환해요.

    teams.home/away의 events는 선수·시간·종류·지도 좌표예요. 동일 이벤트는 ID로 한 번만 제공해요.
    attack에는 어시스트를 제외한 key_passes와 completed_passes_into_final_third가 있어요.
    progression은 성공 패스에 105×68m·골문 거리 감소 30/15/10m 기준을 적용해요.
    channels는 공격 방향 기준 도착 위치의 좌·중·우예요. 전진 패스가 없으면 비율은 null이에요.
    defensive_activity.actions는 수비 행동 지도와 필터에 써요. 같은 팀 events의 ID로 선수·시간을 연결해요.
    average_regain_x는 양 팀 모두 오른쪽 공격으로 맞춘 0~100 평균 회수 위치선이에요.
    high_regains는 상대 진영 Recoveries 수이며 높이(m)는 표준 105m 경기장 환산값이에요.
    실제 압박·수비 라인·주행거리·초 단위 회복 시간·Carry는 제공하지 않아요.
    available=false이면 아직 수집하지 않았어요. 유효슈팅 지도는 /shotmap에서 조회해요.
    """
    return _opta_fixture_data(fixture_id, get_analysis)


@router.get("/fixtures/{fixture_id}/shotmap")
def fixture_shotmap(fixture_id: int, user_id: int = Depends(get_user_id)):
    """Opta의 득점 포함 유효슈팅과 시작·끝 좌표를 반환해요.

    좌표는 왼쪽 위 원점의 0~100이고 홈은 오른쪽, 원정은 왼쪽을 공격해요.
    끝점은 위젯의 표시 지점이며 공의 높이나 전체 궤적이 아니에요.
    available=false는 미수집이에요. 기존 경기 상세의 shots와 xG는 Understat 계약을 유지해요.
    """
    return _opta_fixture_data(fixture_id, get_shotmap)


@router.get("/fixtures/{fixture_id}")
def fixture_detail(fixture_id: int, user_id: int = Depends(get_user_id)):
    """경기 상세와 player_statistics의 포지션별 지표를 반환해요.

    player_statistics와 lineups는 (team_id, player_id)로 연결해요.
    categories의 순서대로 표시하고, 지표의 null은 미제공으로 구분해요.
    pair는 numerator/denominator, percentage는 0~100의 value를 사용해요.
    xG는 Understat, 나머지 선수 지표·평점·POM은 Sportmonks 값이에요.
    팀 DEFENSE는 statistics의 tackles-won·duels-won 횟수를 사용해요. 성공률·승률로 바꾸지 않아요.
    statistics의 touches는 출전 선수의 Sportmonks Touches 합계예요. 한 명이라도 값이 빠지면 null이에요.
    Error는 표시 항목에서 제외했어요.
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
