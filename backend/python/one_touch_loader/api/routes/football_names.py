from fastapi import APIRouter, Depends

from ..deps import get_user_id
from ...core.football_names import korean_names

router = APIRouter()


@router.get("/football-names/ko")
def football_names(user_id: int = Depends(get_user_id)) -> dict[str, dict[str, str]]:
    """앱 시작 시 DB의 한국어 이름을 읽어 재빌드 없이 수정 사항을 받아요."""
    return korean_names()
