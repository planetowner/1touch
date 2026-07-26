from __future__ import annotations

from datetime import date, datetime
from typing import Any, Dict, List, Optional

from ..db import fetch_all_dict


BIG5_LEAGUE_IDS = (8, 82, 301, 384, 564)
BIG5_LEAGUE_IDS_SQL = ", ".join(str(league_id) for league_id in BIG5_LEAGUE_IDS)


def _date_string(value: date | datetime | None) -> Optional[str]:
    if value is None:
        return None
    return value.isoformat()


def get_points_pace_series(
    team_id: int,
    season_id: int,
) -> Optional[Dict[str, Any]]:
    """Return one Big 5 domestic-league cumulative-points series.

    A valid team-season with no completed match still returns a round-zero
    series so a newly started current season can render an empty chart.
    """
    metadata_rows = fetch_all_dict(
        f"""
        SELECT
          t.team_id,
          t.name AS team_name,
          t.short_code AS team_short_code,
          t.image_path AS team_logo,
          s.league_id,
          s.season_id,
          s.name AS season_name,
          s.starting_at,
          s.ending_at,
          s.is_current
        FROM team_seasons ts
        JOIN teams t ON t.team_id = ts.team_id
        JOIN seasons s
          ON s.season_id = ts.season_id
         AND s.league_id = ts.league_id
        WHERE ts.team_id = %s
          AND ts.season_id = %s
          AND s.league_id IN ({BIG5_LEAGUE_IDS_SQL})
        LIMIT 2
        """,
        (team_id, season_id),
    )
    if not metadata_rows:
        return None
    if len(metadata_rows) > 1:
        raise ValueError(
            f"team_id={team_id} season_id={season_id} has duplicate "
            "Big 5 team_seasons memberships"
        )

    metadata = metadata_rows[0]
    point_rows = fetch_all_dict(
        """
        SELECT round_no, match_date, cumulative_points
        FROM points_pace
        WHERE league_id = %s
          AND season_id = %s
          AND team_id = %s
        ORDER BY round_no
        """,
        (
            int(metadata["league_id"]),
            int(metadata["season_id"]),
            int(metadata["team_id"]),
        ),
    )

    points = [
        {
            "round_no": 0,
            "match_date": None,
            "cumulative_points": 0,
        }
    ]
    points.extend(
        {
            "round_no": int(row["round_no"]),
            "match_date": _date_string(row["match_date"]),
            "cumulative_points": int(row["cumulative_points"]),
        }
        for row in point_rows
    )

    return {
        "team_id": int(metadata["team_id"]),
        "team_name": metadata["team_name"],
        "team_short_code": metadata["team_short_code"],
        "team_logo": metadata["team_logo"],
        "league_id": int(metadata["league_id"]),
        "season_id": int(metadata["season_id"]),
        "season_name": metadata["season_name"],
        "season_starting_at": _date_string(metadata["starting_at"]),
        "season_ending_at": _date_string(metadata["ending_at"]),
        "is_current": int(metadata["is_current"]) == 1,
        "points": points,
    }


def build_current_form_comparison(
    current: Dict[str, Any],
    comparison: Dict[str, Any],
) -> Dict[str, Any]:
    all_points = current["points"] + comparison["points"]
    return {
        "current": current,
        "comparison": comparison,
        "max_round": max(int(point["round_no"]) for point in all_points),
        "max_points": max(
            int(point["cumulative_points"]) for point in all_points
        ),
    }


def list_current_form_options(
    *,
    search: Optional[str],
    limit: int,
) -> List[Dict[str, Any]]:
    """List Big 5 team-seasons that have a stored points curve."""
    normalized_search = (search or "").strip()
    rows = fetch_all_dict(
        f"""
        SELECT
          t.team_id,
          t.name AS team_name,
          t.short_code AS team_short_code,
          t.image_path AS team_logo,
          s.league_id,
          s.season_id,
          s.name AS season_name,
          s.starting_at,
          s.ending_at,
          COUNT(pp.round_no) AS rounds_available,
          MAX(pp.round_no) AS latest_round
        FROM team_seasons ts
        JOIN teams t ON t.team_id = ts.team_id
        JOIN seasons s
          ON s.season_id = ts.season_id
         AND s.league_id = ts.league_id
        JOIN points_pace pp
          ON pp.league_id = ts.league_id
         AND pp.season_id = ts.season_id
         AND pp.team_id = ts.team_id
        WHERE s.league_id IN ({BIG5_LEAGUE_IDS_SQL})
          AND (
            %s = ''
            OR t.name LIKE CONCAT('%%', %s, '%%')
            OR COALESCE(t.short_code, '') LIKE CONCAT('%%', %s, '%%')
          )
        GROUP BY
          t.team_id, t.name, t.short_code, t.image_path,
          s.league_id, s.season_id, s.name, s.starting_at, s.ending_at
        ORDER BY s.starting_at DESC, t.name ASC
        LIMIT %s
        """,
        (
            normalized_search,
            normalized_search,
            normalized_search,
            limit,
        ),
    )

    return [
        {
            "team_id": int(row["team_id"]),
            "team_name": row["team_name"],
            "team_short_code": row["team_short_code"],
            "team_logo": row["team_logo"],
            "league_id": int(row["league_id"]),
            "season_id": int(row["season_id"]),
            "season_name": row["season_name"],
            "season_starting_at": _date_string(row["starting_at"]),
            "season_ending_at": _date_string(row["ending_at"]),
            "rounds_available": int(row["rounds_available"]),
            "latest_round": int(row["latest_round"]),
        }
        for row in rows
    ]
