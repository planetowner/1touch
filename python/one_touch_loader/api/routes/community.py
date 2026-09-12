from fastapi import APIRouter, Depends, Query
from ..deps import get_user_id
from ..repos import community_repo
from ..schemas.community import CommunityLanguage

router = APIRouter()


@router.get("/community/followers")
def followers(team_id: int = Query(gt=0), user_id: int = Depends(get_user_id)):
    return {"team_id": team_id, "follower_count": community_repo.count_followers(user_id, team_id)}


@router.get("/community/rules")
def rules(language: CommunityLanguage, team_id: int = Query(gt=0), user_id: int = Depends(get_user_id)):
    # 국가나 팀의 연고지로 표시 언어를 추측하지 않고 앱이 선택한 언어를 받아요.
    return {"rules": community_repo.get_rules(user_id, team_id, language)}
