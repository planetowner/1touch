"""커뮤니티 안내와 홈 최애팀 회원 수를 조회해요."""
from datetime import timezone

from ..db import fetch_one_dict
from ..schemas.community import CommunityRules, CommunitySuspension
from ..services.community_rules import get_rules_content
from .posts_repo import community_user
from .users_repo import get_user


def get_suspension(user_id: int) -> CommunitySuspension | None:
    # 제재된 회원도 자기 사유와 종료 시각은 확인할 수 있어야 해요.
    user = get_user(user_id)
    until = user["suspended_until"]
    if until is None:
        return None
    # 만료 후에도 마지막 제재를 반환해 앱에서 복귀 이용규칙을 안내해요.
    return CommunitySuspension(reason=user["suspension_reason"],
                               ends_at=until.replace(tzinfo=timezone.utc))


def get_rules(user_id: int, team_id: int) -> CommunityRules:
    community_user(user_id, team_id, read_only=True)
    return get_rules_content()


def count_followers(user_id: int, team_id: int) -> int:
    community_user(user_id, team_id, read_only=True)
    # 커뮤니티 참여 기준과 같게 홈 최애팀만 세요. 다른 팔로우 팀이나 차단 여부는 집계에 반영하지 않아요.
    return fetch_one_dict("SELECT COUNT(*) AS total FROM users WHERE favorite_team_id=%s", (team_id,))["total"]
