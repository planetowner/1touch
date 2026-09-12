"""커뮤니티 안내와 홈 최애팀 회원 수를 조회해요."""
from ..db import fetch_one_dict
from ..schemas.community import CommunityLanguage, CommunityRules
from ..services.community_rules import get_rules_content
from .posts_repo import community_user


def get_rules(user_id: int, team_id: int, language: CommunityLanguage) -> CommunityRules:
    community_user(user_id, team_id)
    return get_rules_content(language)


def count_followers(user_id: int, team_id: int) -> int:
    community_user(user_id, team_id)
    # 커뮤니티 참여 기준과 같게 홈 최애팀만 세요. 다른 팔로우 팀이나 차단 여부는 집계에 반영하지 않아요.
    return fetch_one_dict("SELECT COUNT(*) AS total FROM users WHERE favorite_team_id=%s", (team_id,))["total"]
