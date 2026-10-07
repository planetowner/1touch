from fastapi import APIRouter, Depends, Query

from ..deps import get_user_id
from ..repos.search_repo import search
from ..schemas.search import SearchResponse

router = APIRouter()


@router.get("/search", response_model=SearchResponse)
def global_search(q: str = Query(max_length=100),
                  limit: int = Query(default=12, ge=1, le=100, description="선수·팀 각각의 최대 개수예요. 경기는 진행 중 전체, 과거 5개, 예정 5개 순서로 반환해요."),
                  user_id: int = Depends(get_user_id)):
    return search(q, limit)
