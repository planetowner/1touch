from __future__ import annotations

from typing import Any, Dict, List, Optional

from ...core.fixture_states import (
    COMPLETED_STATE_IDS,
    UPCOMING_STATE_IDS,
    screen_status_for_state_id,
    state_ids_for_screen_status,
)
from ..db import fetch_all_dict, fetch_one_dict


def _sql_placeholders(values: tuple[int, ...]) -> str:
    return ",".join("%s" for _ in values)


_BASE_SELECT = """
SELECT
  f.fixture_id,
  s.competition_id,
  s.season_id,
  c.competition_type,
  r.name AS round_name,
  f.stage_id,
  st.name AS stage_name,
  f.round_id,
  f.group_id,
  f.aggregate_id,
  f.leg,
  f.venue_id,
  v.name AS venue_name,
  f.state_id,
  fs.state_code,
  fs.name AS state_name,
  DATE_FORMAT(f.starting_at, '%Y-%m-%d %H:%i:%S') AS starting_at,
  f.home_team_id,
  f.away_team_id,
  f.home_score,
  f.away_score,
  f.home_penalty_score,
  f.away_penalty_score,
  th.name AS home_team_name,
  ta.name AS away_team_name,
  th.image_path AS home_team_logo,
  ta.image_path AS away_team_logo
FROM fixtures f
JOIN stages st ON st.stage_id = f.stage_id
JOIN seasons s ON s.season_id = st.season_id
JOIN competitions c ON c.competition_id = s.competition_id
JOIN fixture_states fs ON fs.state_id = f.state_id
LEFT JOIN rounds r ON r.round_id = f.round_id
LEFT JOIN venues v ON v.venue_id = f.venue_id
LEFT JOIN teams th ON th.team_id = f.home_team_id
LEFT JOIN teams ta ON ta.team_id = f.away_team_id
"""


def _with_status(row: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if row is None:
        return None
    row["status"] = screen_status_for_state_id(int(row["state_id"]))
    return row


def _with_status_many(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    for row in rows:
        _with_status(row)
    return rows


def get_fixture(fixture_id: int) -> Optional[Dict[str, Any]]:
    return _with_status(
        fetch_one_dict(
            _BASE_SELECT + " WHERE f.fixture_id=%s",
            (fixture_id,),
        )
    )


def get_fixture_detail(fixture_id: int) -> Optional[Dict[str, Any]]:
    fixture = get_fixture(fixture_id)
    if fixture is None:
        return None

    fixture["events"] = fetch_all_dict(
        """
        SELECT
          fe.event_id,
          fe.team_id,
          fe.event_type_id,
          fet.code AS event_type_code,
          fet.name AS event_type_name,
          fe.player_id,
          p.display_name AS player_name,
          p.image_path AS player_image,
          fe.related_player_id,
          rp.display_name AS related_player_name,
          rp.image_path AS related_player_image,
          fe.minute,
          fe.extra_minute,
          fe.on_bench
        FROM fixture_events fe
        JOIN fixture_event_types fet
          ON fet.event_type_id = fe.event_type_id
        LEFT JOIN players p ON p.player_id = fe.player_id
        LEFT JOIN players rp ON rp.player_id = fe.related_player_id
        WHERE fe.fixture_id = %s
        ORDER BY fe.minute, fe.extra_minute, fe.event_id
        """,
        (fixture_id,),
    )
    fixture["statistics"] = fetch_all_dict(
        """
        SELECT
          fts.team_id,
          fts.stat_type_id,
          fst.code AS stat_code,
          fst.name AS stat_name,
          fts.stat_value AS value
        FROM fixture_team_stats fts
        JOIN fixture_stat_types fst ON fst.stat_type_id = fts.stat_type_id
        WHERE fts.fixture_id = %s
        ORDER BY fts.team_id, fts.stat_type_id
        """,
        (fixture_id,),
    )
    fixture["lineups"] = fetch_all_dict(
        """
        SELECT
          fl.team_id,
          fl.player_id,
          p.display_name AS player_name,
          p.image_path AS player_image,
          p.position_id,
          fl.lineup_type_id,
          fl.formation_field,
          fl.jersey_number,
          fl.minutes_played,
          fl.rating
        FROM fixture_lineups fl
        JOIN players p ON p.player_id = fl.player_id
        WHERE fl.fixture_id = %s
        ORDER BY fl.team_id, fl.lineup_type_id, fl.formation_field, fl.player_id
        """,
        (fixture_id,),
    )
    fixture["formations"] = fetch_all_dict(
        """
        SELECT team_id, formation
        FROM fixture_formations
        WHERE fixture_id = %s
        ORDER BY team_id
        """,
        (fixture_id,),
    )
    fixture["coaches"] = fetch_all_dict(
        """
        SELECT fc.team_id, fc.coach_id, c.name
        FROM fixture_coaches fc
        JOIN coaches c ON c.coach_id = fc.coach_id
        WHERE fc.fixture_id = %s
        ORDER BY fc.team_id
        """,
        (fixture_id,),
    )
    fixture["pressure"] = fetch_all_dict(
        """
        SELECT team_id, minute, pressure
        FROM fixture_pressures
        WHERE fixture_id = %s
        ORDER BY minute, team_id
        """,
        (fixture_id,),
    )
    return fixture


def get_team_next_fixture(team_id: int) -> Optional[Dict[str, Any]]:
    state_ids = UPCOMING_STATE_IDS
    return _with_status(
        fetch_one_dict(
            _BASE_SELECT
            + f"""
            WHERE (f.home_team_id=%s OR f.away_team_id=%s)
              AND f.state_id IN ({_sql_placeholders(state_ids)})
              AND f.starting_at IS NOT NULL
              AND f.starting_at >= NOW() - INTERVAL 2 HOUR
            ORDER BY f.starting_at ASC
            LIMIT 1
            """,
            (team_id, team_id, *state_ids),
        )
    )


def get_team_last_fixture(team_id: int) -> Optional[Dict[str, Any]]:
    return _with_status(
        fetch_one_dict(
            _BASE_SELECT
            + f"""
            WHERE (f.home_team_id=%s OR f.away_team_id=%s)
              AND f.state_id IN ({_sql_placeholders(COMPLETED_STATE_IDS)})
            ORDER BY f.starting_at DESC
            LIMIT 1
            """,
            (team_id, team_id, *COMPLETED_STATE_IDS),
        )
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
        state_ids = state_ids_for_screen_status(status)
        clauses.append(f"f.state_id IN ({_sql_placeholders(state_ids)})")
        params.extend(state_ids)

    if start_date:
        clauses.append("DATE(f.starting_at) >= %s")
        params.append(start_date)

    if end_date:
        clauses.append("DATE(f.starting_at) <= %s")
        params.append(end_date)

    where = " AND ".join(clauses)
    return _with_status_many(
        fetch_all_dict(
            _BASE_SELECT
            + f"""
            WHERE {where}
            ORDER BY f.starting_at DESC
            LIMIT %s OFFSET %s
            """,
            tuple(params + [limit, offset]),
        )
    )


def list_head2head(team_a: int, team_b: int, limit: int = 10) -> List[Dict[str, Any]]:
    return _with_status_many(
        fetch_all_dict(
            _BASE_SELECT
            + f"""
            WHERE f.state_id IN ({_sql_placeholders(COMPLETED_STATE_IDS)})
              AND (
                (f.home_team_id=%s AND f.away_team_id=%s)
                OR
                (f.home_team_id=%s AND f.away_team_id=%s)
              )
            ORDER BY f.starting_at DESC
            LIMIT %s
            """,
            (*COMPLETED_STATE_IDS, team_a, team_b, team_b, team_a, limit),
        )
    )
