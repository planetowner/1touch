from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from ..db import fetch_all_dict, fetch_one_dict


_BASE_SELECT = """
SELECT
  f.fixture_id, f.league_id, f.season_id,
  f.competition_type, f.round_name, f.stage_id, f.group_id, f.leg_number,
  f.status, DATE_FORMAT(f.starting_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS starting_at,
  f.home_team_id, f.away_team_id,
  f.home_score, f.away_score, f.home_penalty_score, f.away_penalty_score,
  th.name AS home_team_name, ta.name AS away_team_name,
  th.image_path AS home_team_logo, ta.image_path AS away_team_logo
FROM fixtures f
LEFT JOIN teams th ON th.team_id = f.home_team_id
LEFT JOIN teams ta ON ta.team_id = f.away_team_id
"""


def get_fixture(fixture_id: int) -> Optional[Dict[str, Any]]:
    return fetch_one_dict(
        _BASE_SELECT + " WHERE f.fixture_id=%s",
        (fixture_id,),
    )


def get_team_next_fixture(team_id: int) -> Optional[Dict[str, Any]]:
    return fetch_one_dict(
        _BASE_SELECT
        + """
        WHERE (f.home_team_id=%s OR f.away_team_id=%s)
          AND f.status IN ('upcoming','live')
          AND (f.starting_at IS NULL OR f.starting_at >= NOW() - INTERVAL 2 HOUR)
        ORDER BY f.starting_at ASC
        LIMIT 1
        """,
        (team_id, team_id),
    )


def get_team_last_fixture(team_id: int) -> Optional[Dict[str, Any]]:
    return fetch_one_dict(
        _BASE_SELECT
        + """
        WHERE (f.home_team_id=%s OR f.away_team_id=%s)
          AND f.status='past'
        ORDER BY f.starting_at DESC
        LIMIT 1
        """,
        (team_id, team_id),
    )


def list_team_fixtures(
    team_id: int,
    status: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
) -> List[Dict[str, Any]]:
    clauses = ["(f.home_team_id=%s OR f.away_team_id=%s)"]
    params: List[Any] = [team_id, team_id]

    if status:
        clauses.append("f.status=%s")
        params.append(status)

    if start_date:
        clauses.append("DATE(f.starting_at) >= %s")
        params.append(start_date)

    if end_date:
        clauses.append("DATE(f.starting_at) <= %s")
        params.append(end_date)

    where = " AND ".join(clauses)
    return fetch_all_dict(
        _BASE_SELECT
        + f"""
        WHERE {where}
        ORDER BY f.starting_at DESC
        LIMIT %s OFFSET %s
        """,
        tuple(params + [limit, offset]),
    )


def list_head2head(team_a: int, team_b: int, limit: int = 10) -> List[Dict[str, Any]]:
    return fetch_all_dict(
        _BASE_SELECT
        + """
        WHERE f.status='past'
          AND (
            (f.home_team_id=%s AND f.away_team_id=%s)
            OR
            (f.home_team_id=%s AND f.away_team_id=%s)
          )
        ORDER BY f.starting_at DESC
        LIMIT %s
        """,
        (team_a, team_b, team_b, team_a, limit),
    )
