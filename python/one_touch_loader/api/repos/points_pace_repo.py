from __future__ import annotations

from datetime import date, datetime
from typing import Any, Dict, List, Optional

from ..db import fetch_all_dict, fetch_one_dict
from ...core.fixture_states import COMPLETED_STATE_IDS


BIG5_COMPETITION_IDS = (8, 82, 301, 384, 564)
BIG5_COMPETITION_IDS_SQL = ", ".join(
    str(competition_id) for competition_id in BIG5_COMPETITION_IDS
)
# AWARDED(17)는 리그가 결과를 확정한 상태라 완료 경기와 함께 계산해요.
RESULT_STATE_IDS = (*COMPLETED_STATE_IDS, 17)
RESULT_STATE_IDS_SQL = ", ".join(str(state_id) for state_id in RESULT_STATE_IDS)

# DB의 중단 경기 가운데 리그가 스코어를 확정한 두 경기만 결과로 계산해요.
RATIFIED_ABANDONED_FIXTURE_IDS = (19139879, 19433450)
RATIFIED_ABANDONED_FIXTURE_IDS_SQL = ", ".join(
    str(fixture_id) for fixture_id in RATIFIED_ABANDONED_FIXTURE_IDS
)
ELIGIBLE_RESULT_SQL = f"""(
  f.state_id IN ({RESULT_STATE_IDS_SQL})
  OR f.fixture_id IN ({RATIFIED_ABANDONED_FIXTURE_IDS_SQL})
)"""


def _date_string(value: date | datetime | None) -> Optional[str]:
    if value is None:
        return None
    return value.isoformat()


def _gained_points(fixture: Dict[str, Any], team_id: int) -> int:
    home_score = int(fixture["home_score"])
    away_score = int(fixture["away_score"])
    if home_score == away_score:
        return 1

    is_home = int(fixture["home_team_id"]) == team_id
    won = home_score > away_score if is_home else away_score > home_score
    return 3 if won else 0


def get_points_pace_series(
    team_id: int,
    season_id: int,
) -> Optional[Dict[str, Any]]:
    """Big 5 자국 리그 한 팀의 경기별 누적 승점 곡선을 반환해요."""
    metadata = fetch_one_dict(
        f"""
        SELECT
          t.team_id,
          t.name AS team_name,
          t.short_code AS team_short_code,
          t.image_path AS team_logo,
          s.competition_id,
          s.season_id,
          s.name AS season_name,
          s.is_current
        FROM team_seasons ts
        JOIN teams t ON t.team_id = ts.team_id
        JOIN seasons s ON s.season_id = ts.season_id
        WHERE ts.team_id = %s
          AND ts.season_id = %s
          AND s.competition_id IN ({BIG5_COMPETITION_IDS_SQL})
        """,
        (team_id, season_id),
    )
    if metadata is None:
        return None

    fixture_rows = fetch_all_dict(
        f"""
        SELECT
          f.fixture_id,
          CAST(r.name AS UNSIGNED) AS round_no,
          f.starting_at AS match_date,
          f.home_team_id,
          f.away_team_id,
          f.home_score,
          f.away_score
        FROM fixtures f
        JOIN stages st ON st.stage_id = f.stage_id
        JOIN rounds r ON r.round_id = f.round_id
        WHERE st.season_id = %s
          AND (f.home_team_id = %s OR f.away_team_id = %s)
          AND {ELIGIBLE_RESULT_SQL}
          AND f.home_score IS NOT NULL
          AND f.away_score IS NOT NULL
          AND r.name REGEXP '^[0-9]+$'
        ORDER BY round_no, f.starting_at, f.fixture_id
        """,
        (season_id, team_id, team_id),
    )

    cumulative_points = 0
    points = [
        {
            "round_no": 0,
            "match_date": None,
            "cumulative_points": 0,
        }
    ]
    for fixture in fixture_rows:
        cumulative_points += _gained_points(fixture, team_id)
        points.append(
            {
                "round_no": int(fixture["round_no"]),
                "match_date": _date_string(fixture["match_date"]),
                "cumulative_points": cumulative_points,
            }
        )

    return {
        "team_id": int(metadata["team_id"]),
        "team_name": metadata["team_name"],
        "team_short_code": metadata["team_short_code"],
        "team_logo": metadata["team_logo"],
        "competition_id": int(metadata["competition_id"]),
        "season_id": int(metadata["season_id"]),
        "season_name": metadata["season_name"],
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
    """계산할 리그 경기 결과가 있는 Big 5 팀 시즌을 조회해요."""
    normalized_search = (search or "").strip()
    rows = fetch_all_dict(
        f"""
        SELECT
          t.team_id,
          t.name AS team_name,
          t.short_code AS team_short_code,
          t.image_path AS team_logo,
          s.competition_id,
          s.season_id,
          s.name AS season_name,
          COUNT(f.fixture_id) AS rounds_available,
          MAX(CAST(r.name AS UNSIGNED)) AS latest_round
        FROM team_seasons ts
        JOIN teams t ON t.team_id = ts.team_id
        JOIN seasons s ON s.season_id = ts.season_id
        JOIN stages st ON st.season_id = ts.season_id
        JOIN fixtures f
          ON f.stage_id = st.stage_id
         AND (f.home_team_id = ts.team_id OR f.away_team_id = ts.team_id)
        JOIN rounds r ON r.round_id = f.round_id
        WHERE s.competition_id IN ({BIG5_COMPETITION_IDS_SQL})
          AND {ELIGIBLE_RESULT_SQL}
          AND f.home_score IS NOT NULL
          AND f.away_score IS NOT NULL
          AND r.name REGEXP '^[0-9]+$'
          AND (
            %s = ''
            OR t.name LIKE CONCAT('%%', %s, '%%')
            OR COALESCE(t.short_code, '') LIKE CONCAT('%%', %s, '%%')
          )
        GROUP BY
          t.team_id, t.name, t.short_code, t.image_path,
          s.competition_id, s.season_id, s.name
        ORDER BY s.name DESC, t.name ASC
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
            "competition_id": int(row["competition_id"]),
            "season_id": int(row["season_id"]),
            "season_name": row["season_name"],
            "rounds_available": int(row["rounds_available"]),
            "latest_round": int(row["latest_round"]),
        }
        for row in rows
    ]
