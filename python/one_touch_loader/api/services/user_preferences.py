"""가입과 설정 변경이 같은 최애팀 선택 규칙을 사용해요."""
from __future__ import annotations

from datetime import datetime, timedelta


class FavoriteTeamCooldownError(ValueError):
    def __init__(self, available_at: datetime):
        self.available_at = available_at
        super().__init__("The home favorite team can be changed once every seven days")


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
    # 최초 가입 선택은 변경권을 쓰지 않아요. 첫 실제 변경 시각부터 7일 간격을 계산해요.
    # 입력 시각은 같은 UTC 기준을 사용해요. 서버의 EDT나 사용자의 현지 날짜로 세지 않아요.
    if previous_team_id is None:
        return None
    if previous_team_id == next_team_id:
        # 다른 팔로우 팀만 편집하거나 같은 요청을 다시 보내도 대기 기간을 늘리지 않아요.
        return previous_changed_at
    if previous_changed_at is not None:
        available_at = previous_changed_at + timedelta(days=7)
        if now < available_at:
            raise FavoriteTeamCooldownError(available_at)
    return now
