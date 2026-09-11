from fastapi import APIRouter, Depends, Query
from ..deps import get_user_id
from ..repos import community_repo

router = APIRouter()


@router.get("/community/followers")
def followers(team_id: int = Query(gt=0), user_id: int = Depends(get_user_id)):
    return {"team_id": team_id, "follower_count": community_repo.count_followers(user_id, team_id)}


@router.get("/community/rules")
def rules(team_id: int = Query(gt=0), user_id: int = Depends(get_user_id)):
    return {"rules": community_repo.get_rules(user_id, team_id)}
