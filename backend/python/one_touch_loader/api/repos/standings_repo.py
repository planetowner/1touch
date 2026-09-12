from __future__ import annotations

from collections import defaultdict
from typing import Any, Dict, List, Optional

from ...core.fixture_states import COMPLETED_STATE_IDS
from ..db import fetch_all_dict


def get_current_season_id_for_competition(competition_id: int) -> Optional[int]:
    rows = fetch_all_dict(
        """
        SELECT season_id
        FROM seasons
        WHERE competition_id = %s AND is_current = 1
        """,
        (competition_id,),
    )
    if not rows:
        return None
    return int(rows[0]["season_id"])


def _result_for_team(fixture: Dict[str, Any], team_id: int) -> str:
    is_home = fixture["home_team_id"] == team_id
    team_score = fixture["home_score"] if is_home else fixture["away_score"]
    opponent_score = fixture["away_score"] if is_home else fixture["home_score"]

    if team_score > opponent_score:
        return "W"
    if team_score < opponent_score:
        return "L"
    return "D"


def _last_five_by_team(season_id: int) -> Dict[int, List[str]]:
    placeholders = ",".join("%s" for _ in COMPLETED_STATE_IDS)
    fixtures = fetch_all_dict(
        f"""
        SELECT
          f.home_team_id,
          f.away_team_id,
          f.home_score,
          f.away_score
        FROM fixtures f
        JOIN stages st ON st.stage_id = f.stage_id
        JOIN rounds r ON r.round_id = f.round_id
        WHERE st.season_id = %s
          AND f.state_id IN ({placeholders})
          AND r.name REGEXP '^[0-9]+$'
        ORDER BY f.starting_at DESC, f.fixture_id DESC
        """,
        (season_id, *COMPLETED_STATE_IDS),
    )

    recent: Dict[int, List[str]] = defaultdict(list)
    for fixture in fixtures:
        for team_id in (fixture["home_team_id"], fixture["away_team_id"]):
            if len(recent[team_id]) < 5:
                recent[team_id].append(_result_for_team(fixture, team_id))

    return {team_id: list(reversed(results)) for team_id, results in recent.items()}


def list_standings(
    competition_id: int,
    season_id: int,
) -> List[Dict[str, Any]]:
    rows = fetch_all_dict(
        """
        SELECT
          st.position,
          st.previous_position,
          st.team_id,
          t.name AS team_name,
          t.image_path AS team_logo,
          st.won,
          st.draw,
          st.lost,
          st.goals_for,
          st.goals_against,
          st.points
        FROM standings st
        JOIN seasons s ON s.season_id = st.season_id
        JOIN teams t ON t.team_id = st.team_id
        WHERE st.season_id = %s
          AND s.competition_id = %s
        ORDER BY st.position, st.team_id
        """,
        (season_id, competition_id),
    )
    last_five = _last_five_by_team(season_id)

    for row in rows:
        row["matches_played"] = row["won"] + row["draw"] + row["lost"]
        row["goal_diff"] = row["goals_for"] - row["goals_against"]
        previous_position = row.pop("previous_position")
        row["rank_delta"] = (
            previous_position - row["position"]
            if previous_position is not None
            else None
        )
        # 현재 시즌처럼 완료 fixtures가 아직 없으면 최근 경기 배열도 비어 있어요.
        row["last5_form"] = last_five.get(row["team_id"], [])

    return rows


def get_team_standing(
    competition_id: int,
    season_id: int,
    team_id: int,
) -> Optional[Dict[str, Any]]:
    for row in list_standings(competition_id, season_id):
        if row["team_id"] == team_id:
            return row
    return None
