from __future__ import annotations

from typing import Any, Dict, Optional

from fastapi import HTTPException

from ..repos.users_repo import get_favorite_team_id
from ..repos.teams_repo import get_teams, list_following_team_ids
from ..repos.fixtures_repo import get_team_last_fixture, get_team_next_fixture, list_team_fixtures
from ..repos.highlights_repo import get_team_highlights
from ..repos.standings_repo import get_current_team_standing


def build_home_payload(
    user_id: int,
    start_date: Optional[str],
    end_date: Optional[str],
    viewer_country: str | None = None,
    team_id: int | None = None,
) -> Dict[str, Any]:
    following_ids = list_following_team_ids(user_id)
    following_teams = get_teams(following_ids)

    if team_id is not None and team_id not in following_ids:
        raise HTTPException(status_code=400, detail="Select a followed team to view Home")

    # 홈에서 볼 팀은 조회에만 써요. 저장된 최애팀과 7일 변경 제한은 건드리지 않아요.
    viewed_team_id = team_id if team_id is not None else get_favorite_team_id(user_id)
    viewed_team = None
    if viewed_team_id:
        for t in following_teams:
            if int(t["team_id"]) == int(viewed_team_id):
                viewed_team = t
                break
        if viewed_team is None:
            raise ValueError(
                f"viewed_team_id={viewed_team_id} is not in user {user_id}'s "
                f"following list — home/following invariant violated."
            )

    next_match = get_team_next_fixture(viewed_team_id) if viewed_team_id else None
    last_match = get_team_last_fixture(viewed_team_id) if viewed_team_id else None

    calendar = []
    if viewed_team_id and (start_date or end_date):
        calendar = list_team_fixtures(
            viewed_team_id,
            status=None,
            start_date=start_date,
            end_date=end_date,
            limit=200,
            offset=0,
        )

    return {
        # 기존 앱과의 응답 호환성을 위해 키 이름은 유지해요. 값은 현재 조회 팀이에요.
        "favorite_team": viewed_team,
        "following_teams": following_teams,
        "next_match": next_match,
        "last_match": last_match,
        "standing": get_current_team_standing(viewed_team_id) if viewed_team_id else None,
        "calendar": calendar,
        "highlights": get_team_highlights(viewed_team_id, viewer_country) if viewed_team_id and viewer_country else None,
    }
