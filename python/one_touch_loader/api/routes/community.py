from fastapi import APIRouter, Depends, Query
from ..deps import get_user_id
from ..repos import community_repo

router = APIRouter()


@router.get("/community/rules")
def rules(team_id: int = Query(gt=0), user_id: int = Depends(get_user_id)):
    return {"rules": community_repo.get_rules(user_id, team_id)}
