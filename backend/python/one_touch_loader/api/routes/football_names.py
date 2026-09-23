from typing import Literal
from fastapi import APIRouter, Depends

from ..deps import get_user_id
from ...core.football_names import korean_names, localized_names

router = APIRouter()


@router.get("/football-names/ko")
def football_names(user_id: int = Depends(get_user_id)) -> dict[str, dict[str, str]]:
    """앱 시작 시 DB의 한국어 이름을 읽어 재빌드 없이 수정 사항을 받아요."""
    return korean_names()


@router.get('/football-names/{locale}/display')
def display_names(locale: Literal['en', 'ko', 'ja', 'zh'], user_id: int = Depends(get_user_id)) -> dict[str, dict[str, str]]:
    """일반 이름과 짧은 이름을 같은 언어·같은 선수 ID로 전달해요."""
    return localized_names(locale)
