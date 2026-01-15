from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from ..repos.users_repo import get_favorite_team_id
from ..repos.teams_repo import get_teams, list_following_team_ids
from ..repos.fixtures_repo import get_team_last_fixture, get_team_next_fixture, list_team_fixtures


def build_home_payload(
    user_id: int,
    start_date: Optional[str],
    end_date: Optional[str],
) -> Dict[str, Any]:
    following_ids = list_following_team_ids(user_id)
    following_teams = get_teams(following_ids)

    favorite_team_id = get_favorite_team_id(user_id)
    if favorite_team_id is None and following_ids:
        favorite_team_id = following_ids[0]

    favorite_team = None
    if favorite_team_id:
        for t in following_teams:
            if int(t["team_id"]) == int(favorite_team_id):
                favorite_team = t
                break
        if favorite_team is None:
            # 팔로우 목록에 없더라도 팀 테이블에 있으면 반환
            one = get_teams([favorite_team_id])
            favorite_team = one[0] if one else None

    next_match = get_team_next_fixture(favorite_team_id) if favorite_team_id else None
    last_match = get_team_last_fixture(favorite_team_id) if favorite_team_id else None

    calendar = []
    if favorite_team_id and (start_date or end_date):
        calendar = list_team_fixtures(
            favorite_team_id,
            status=None,
            start_date=start_date,
            end_date=end_date,
            limit=200,
            offset=0,
        )

    return {
        "favorite_team": favorite_team,
        "following_teams": following_teams,
        "next_match": next_match,
        "last_match": last_match,
        "calendar": calendar,
    }
