from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from ..deps import get_user_id
from ..schemas.common import HomeResponse
from ..services.home_service import build_home_payload

router = APIRouter()


@router.get("/home", response_model=HomeResponse)
def home(
    start: str | None = Query(default=None, description="YYYY-MM-DD"),
    end: str | None = Query(default=None, description="YYYY-MM-DD"),
    viewer_country: str | None = Query(default=None, pattern="^[A-Za-z]{2}$", description="하이라이트를 볼 실제 국가 코드예요. 언어·국적과 별개예요."),
    user_id: int = Depends(get_user_id),
):

    payload = build_home_payload(user_id=user_id, start_date=start, end_date=end, viewer_country=viewer_country)
    return payload
