from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from ..deps import get_user_id
from ..repos.users_repo import ensure_user
from ..schemas.common import HomeResponse, TeamOut, FixtureOut
from ..services.home_service import build_home_payload

router = APIRouter()


@router.get("/home", response_model=HomeResponse)
def home(
    start: str | None = Query(default=None, description="YYYY-MM-DD"),
    end: str | None = Query(default=None, description="YYYY-MM-DD"),
    user_id: int = Depends(get_user_id),
):
    ensure_user(user_id)

    payload = build_home_payload(user_id=user_id, start_date=start, end_date=end)
    return payload
