from fastapi import APIRouter, Depends, Query
from ..deps import get_user_id
from ..repos import community_repo
from ..schemas.community import CommunityRulesResponse, CommunitySuspensionResponse

router = APIRouter()


@router.get("/community/suspension", response_model=CommunitySuspensionResponse)
def suspension(user_id: int = Depends(get_user_id)):
    return {"suspension": community_repo.get_suspension(user_id)}


@router.get("/community/followers")
def followers(team_id: int = Query(gt=0), user_id: int = Depends(get_user_id)):
    return {"team_id": team_id, "follower_count": community_repo.count_followers(user_id, team_id)}


@router.get("/community/rules", response_model=CommunityRulesResponse)
def rules(team_id: int = Query(gt=0), user_id: int = Depends(get_user_id)):
    # 화면 언어는 앱이 메시지 키를 번역할 때 적용해요.
    return {"rules": community_repo.get_rules(user_id, team_id)}
