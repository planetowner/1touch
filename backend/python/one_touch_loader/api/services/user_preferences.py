"""가입과 설정 변경이 같은 최애팀 선택 규칙을 사용해요."""
from __future__ import annotations

from datetime import datetime


def validate_team_selection(
    team_ids: list[int], favorite_team_id: int, current_league_by_team: dict[int, int]
) -> None:
    # 후보는 현재 Big 5의 team_seasons에서 읽어요. 팀 이름이나 최근 경기로 리그를 추정하지 않아요.
    if not 1 <= len(team_ids) <= 5:
        raise ValueError("Select between one and five teams")
    if len(set(team_ids)) != len(team_ids):
        raise ValueError("Each selected team must be unique")
    if favorite_team_id not in team_ids:
        raise ValueError("The home favorite team must be one of the selected teams")
    if any(team_id not in current_league_by_team for team_id in team_ids):
        raise ValueError("Select teams from the current Big 5 leagues")
    leagues = [current_league_by_team[team_id] for team_id in team_ids]
    if len(set(leagues)) != len(leagues):
        raise ValueError("Select at most one team from each league")


def favorite_changed_at_after_update(
    previous_team_id: int | None,
    previous_changed_at: datetime | None,
    next_team_id: int,
    now: datetime,
) -> datetime | None:
    # 최초 선택이나 팔로우 팀만 바꾼 요청은 최애팀 변경으로 세지 않아요.
    return now if previous_team_id is not None and previous_team_id != next_team_id else previous_changed_at
