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

    # favorite_team_id는 PUT 엔드포인트에서 following과 한 트랜잭션으로 저장되며
    # favorite ∈ following이 강제되므로, following_teams 안에서 반드시 찾을 수 있다.
    # 못 찾으면 데이터 불변식이 깨진 것이라 조용히 None으로 넘기지 않고 표면화한다.
    favorite_team = None
    if favorite_team_id:
        for t in following_teams:
            if int(t["team_id"]) == int(favorite_team_id):
                favorite_team = t
                break
        if favorite_team is None:
            raise ValueError(
                f"favorite_team_id={favorite_team_id} is not in user {user_id}'s "
                f"following list — favorite/following invariant violated."
            )

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
