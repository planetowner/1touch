from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Path, Query
from fastapi.responses import Response

from ..db import fetch_one_dict
from ..deps import get_user_id
from ..repos.transfers_repo import get_player_club_history
from ..repos.player_rankings_repo import get_player_rankings
from ..schemas.player_rankings import PlayerRankingsResponse
from ..services.media_storage import player_image_content
from ...core.player_images import IMAGE_ROUTE

router = APIRouter()


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

    Sportmonks 경기 평점만 사용하며, 평점이 있는 10경기 이상이 대상이에요.
    기준은 같은 리그의 2020/21~2024/25 선수·시즌 평균 분포예요.
    점수는 리그 간 절대 능력 비교값이 아니며 화면에는 display_score를 한 자리로 표시해요.
    """
    result = get_player_rankings(season_id, limit=limit, offset=offset)
    if result is None:
        raise HTTPException(404, "Season or fixed historical rating reference not found")
    return result


@router.get("/players/{player_id}/club-history")
def player_club_history(player_id: int, user_id: int = Depends(get_user_id)):
    if fetch_one_dict("SELECT player_id FROM players WHERE player_id=%s", (player_id,)) is None:
        raise HTTPException(status_code=404, detail="Player not found")
    return get_player_club_history(player_id, date.today())
