from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from ..deps import get_user_id
from ..schemas.common import HomeResponse
from ..services.home_service import build_home_payload
from ..services.request_country import get_request_country

router = APIRouter()


@router.get("/home", response_model=HomeResponse)
def home(
    start: str | None = Query(default=None, description="YYYY-MM-DD"),
    end: str | None = Query(default=None, description="YYYY-MM-DD"),
    team_id: int | None = Query(default=None, gt=0, description="홈에서 볼 팔로우 팀 ID예요. 생략하면 최애팀을 조회하며, 최애팀 설정은 바꾸지 않아요."),
    user_id: int = Depends(get_user_id),
    viewer_country: str | None = Depends(get_request_country),
):

    payload = build_home_payload(user_id=user_id, start_date=start, end_date=end, viewer_country=viewer_country, team_id=team_id)
    return payload
