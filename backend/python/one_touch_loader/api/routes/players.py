from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Path, Query
from fastapi.responses import Response

from ..db import fetch_one_dict
from ..deps import get_user_id
from ..repos.transfers_repo import get_player_club_history
from ..repos.player_rankings_repo import get_player_rankings
from ..schemas.player_rankings import PlayerRankingsResponse
from ..repos.player_indicators_repo import get_current_player_indicators
from ..schemas.player_indicators import PlayerIndicatorsResponse
from ..services.media_storage import player_image_content
from ...core.player_images import IMAGE_ROUTE
from ..repos.player_detail_repo import get_player_detail, list_player_comparison_candidates
from ..repos.player_directory_repo import get_current_ranking, get_ones_to_watch
from typing import Literal
from ..schemas.players import (
    CurrentPlayerRankingResponse, PlayerCandidatesResponse, PlayerDetailResponse,
    PlayerClubHistoryResponse, PlayersToWatchResponse,
)

router = APIRouter()


@router.get('/players/ranking-current', response_model=CurrentPlayerRankingResponse)
def current_ranking(competition_id: int | None = Query(default=None, gt=0),
                    position: Literal['GK', 'DF', 'MF', 'FW'] | None = None,
                    limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
                    user_id: int = Depends(get_user_id)):
    if competition_id is not None and competition_id not in (8, 82, 301, 384, 564):
        raise HTTPException(422, 'Unsupported league')
    return get_current_ranking(competition_id, position, limit=limit, offset=offset)


@router.get('/players/ones-to-watch', response_model=PlayersToWatchResponse)
def ones_to_watch(user_id: int = Depends(get_user_id)):
    return get_ones_to_watch()


@router.get("/players/comparison-candidates", response_model=PlayerCandidatesResponse)
def comparison_candidates(q: str = Query(default="", max_length=100), user_id: int = Depends(get_user_id)):
    return {"players": list_player_comparison_candidates(q)}


@router.get("/players/{player_id}/detail", response_model=PlayerDetailResponse)
def player_detail(player_id: int = Path(gt=0), season_id: int | None = Query(default=None, gt=0),
                  user_id: int = Depends(get_user_id)):
    try:
        result = get_player_detail(player_id, season_id)
    except ValueError as exc:
        raise HTTPException(404, str(exc)) from exc
    if result is None:
        raise HTTPException(404, "Player not found")
    return result


@router.get("/players/{player_id}/indicators", response_model=PlayerIndicatorsResponse)
def player_indicators(player_id: int = Path(gt=0), user_id: int = Depends(get_user_id)):
    """현재 시즌 5대 리그 전체 선수를 비교해요. 과거 시즌 조회·DB 갱신은 하지 않아요."""
    result = get_current_player_indicators(player_id)
    if result is None:
        raise HTTPException(404, "Player not in a current five-league squad")
    return result


@router.get(f"{IMAGE_ROUTE}/{{digest}}.png", response_class=Response)
def player_image(digest: str = Path(pattern=r"^[0-9a-f]{64}$")):
    """공개 선수 사진만 반환해요. 회원 사진·첨부파일의 접근 권한은 바꾸지 않아요."""
    return player_image_content(digest)


@router.get("/players/rankings", response_model=PlayerRankingsResponse)
def player_rankings(
    season_id: int = Query(gt=0, description="조회할 리그의 시즌 ID예요."),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    user_id: int = Depends(get_user_id),
):
    """포지션 구분 없이 저장된 시즌 랭킹을 조회해요. 조회 시 평점이나 기준을 갱신하지 않아요.

    Sportmonks 경기 평점만 사용하며, 시즌 중반 전에는 1경기, 이후에는 10경기 이상이 대상이에요.
    목록은 선택한 리그·시즌이지만 점수는 5대 리그를 합친 2017/18~해당 시즌 기록과 비교해요.
    이후 시즌은 비교에 넣지 않으며 화면에는 display_score를 한 자리로 표시해요.
    """
    result = get_player_rankings(season_id, limit=limit, offset=offset)
    if result is None:
        raise HTTPException(404, "Season or cumulative five-league rating reference not found")
    return result


@router.get("/players/{player_id}/club-history", response_model=PlayerClubHistoryResponse)
def player_club_history(player_id: int, user_id: int = Depends(get_user_id)):
    if fetch_one_dict("SELECT player_id FROM players WHERE player_id=%s", (player_id,)) is None:
        raise HTTPException(status_code=404, detail="Player not found")
    return get_player_club_history(player_id, date.today())
