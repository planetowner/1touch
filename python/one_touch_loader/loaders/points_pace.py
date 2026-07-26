from __future__ import annotations

from collections import defaultdict
from datetime import datetime
from typing import Dict, List, Tuple

from ..core.db import fetch_all, transaction


# =========================================================
# Constants
# =========================================================

BIG5_LEAGUE_IDS: Tuple[int, ...] = (8, 82, 301, 384, 564)

MIN_SEASON_START_YEAR = 2017

# Verified via DB scan on Big5 league fixtures:
# round_name is always a pure digit string ("1".."38") for
# competition_type='league' Big5 fixtures, except for a single
# Serie A 2022/2023 row: Spezia 1-3 Hellas Verona on 2023-06-11,
# a one-off relegation playoff held after the regular 38-round season.
# Excluded from the cumulative-points curve because including a 39th
# round for only 2 teams would distort the chart.
RELEGATION_DECIDER_ROUND_NAME = "Relegation Decider"


# =========================================================
# SQL
# =========================================================

SQL_SELECT_FIXTURES_FOR_LEAGUE_SEASON = """
SELECT
    f.starting_at,
    f.home_team_id,
    f.away_team_id,
    f.home_score,
    f.away_score,
    CAST(f.round_name AS UNSIGNED) AS round_no
FROM fixtures f
WHERE f.league_id = %s
  AND f.season_id = %s
  AND f.competition_type = 'league'
  AND f.status = 'past'
  AND f.home_score IS NOT NULL
  AND f.away_score IS NOT NULL
  AND f.round_name REGEXP '^[0-9]+$'
  AND f.round_name <> %s
ORDER BY round_no, f.starting_at, f.fixture_id
"""

SQL_SELECT_SEASONS_SINCE_MIN_YEAR = """
SELECT s.season_id
FROM seasons s
WHERE s.league_id = %s
  AND YEAR(s.starting_at) >= %s
ORDER BY s.starting_at
"""

SQL_SELECT_CURRENT_SEASON_ID = """
SELECT s.season_id
FROM seasons s
WHERE s.league_id = %s
  AND s.is_current = 1
"""

SQL_DELETE_POINTS_PACE = """
DELETE FROM points_pace
WHERE league_id = %s AND season_id = %s
"""

SQL_INSERT_POINTS_PACE = """
INSERT INTO points_pace (
  league_id, season_id, team_id, round_no, match_date, cumulative_points
) VALUES (%s,%s,%s,%s,%s,%s)
"""

SQL_SELECT_STORED_POINTS_PACE = """
SELECT
  league_id, season_id, team_id, round_no, match_date, cumulative_points
FROM points_pace
WHERE league_id = %s AND season_id = %s
ORDER BY team_id, round_no
"""

SQL_INVALID_ROUNDS = """
SELECT league_id, season_id, team_id, round_no, match_date, cumulative_points
FROM points_pace
WHERE round_no < 1 OR round_no > 38
ORDER BY league_id, season_id, team_id, round_no
"""


# =========================================================
# Strict helpers
# =========================================================

def _require_int(value, field_name: str) -> int:
    if type(value) is not int:
        raise ValueError(f"Missing or invalid integer field: {field_name}={value!r}")

    return value


def _require_datetime(value, field_name: str) -> datetime:
    if not isinstance(value, datetime):
        raise ValueError(f"Missing or invalid datetime field: {field_name}={value!r}")

    return value


# =========================================================
# Points calculation
# =========================================================

def _calc_points(home_score: int, away_score: int) -> Tuple[int, int]:
    if home_score > away_score:
        return 3, 0

    if home_score < away_score:
        return 0, 3

    return 1, 1


def _rows_for_league_season(league_id: int, season_id: int) -> List[Tuple]:
    fixtures = fetch_all(
        SQL_SELECT_FIXTURES_FOR_LEAGUE_SEASON,
        (league_id, season_id, RELEGATION_DECIDER_ROUND_NAME),
    )

    per_team: Dict[int, List[Tuple[int, datetime, int]]] = defaultdict(list)

    for row in fixtures:
        starting_at = _require_datetime(row[0], "fixtures.starting_at")
        home_team_id = _require_int(row[1], "fixtures.home_team_id")
        away_team_id = _require_int(row[2], "fixtures.away_team_id")
        home_score = _require_int(row[3], "fixtures.home_score")
        away_score = _require_int(row[4], "fixtures.away_score")
        round_no = _require_int(row[5], "fixtures.round_no")

        home_points, away_points = _calc_points(home_score, away_score)

        per_team[home_team_id].append((round_no, starting_at, home_points))
        per_team[away_team_id].append((round_no, starting_at, away_points))

    upserts: List[Tuple] = []

    for team_id, items in per_team.items():
        items.sort(key=lambda t: (t[0], t[1]))

        cumulative = 0
        seen_rounds = set()

        for round_no, match_dt, gained in items:
            if round_no in seen_rounds:
                raise ValueError(
                    f"league_id={league_id} season_id={season_id} "
                    f"team_id={team_id} has multiple league fixtures for "
                    f"round_no={round_no}"
                )
            seen_rounds.add(round_no)
            cumulative += gained
            upserts.append(
                (league_id, season_id, team_id, round_no, match_dt, cumulative)
            )

    return sorted(upserts, key=lambda row: (int(row[2]), int(row[3])))


def _replace_points_pace(
    league_id: int,
    season_id: int,
    rows: List[Tuple],
) -> None:
    """Atomically replace one derived league-season curve set."""
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(SQL_DELETE_POINTS_PACE, (league_id, season_id))
            if rows:
                cur.executemany(SQL_INSERT_POINTS_PACE, rows)


# =========================================================
# Public API
# =========================================================

def build_points_pace_all() -> None:
    """Big5 전 시즌(MIN_SEASON_START_YEAR 이후) 누적 승점 곡선 전량 빌드."""
    for league_id in BIG5_LEAGUE_IDS:
        season_rows = fetch_all(
            SQL_SELECT_SEASONS_SINCE_MIN_YEAR,
            (league_id, MIN_SEASON_START_YEAR),
        )

        total = 0

        for season_row in season_rows:
            season_id = _require_int(season_row[0], "seasons.season_id")
            rows = _rows_for_league_season(league_id, season_id)
            _replace_points_pace(league_id, season_id, rows)
            total += len(rows)

        print(f"[points_pace] league {league_id} rebuilt rows: {total}")


def refresh_points_pace_current() -> None:
    """Big5 각 리그의 is_current 시즌만 경량 갱신."""
    for league_id in BIG5_LEAGUE_IDS:
        season_rows = fetch_all(SQL_SELECT_CURRENT_SEASON_ID, (league_id,))
        # A league must have exactly one is_current season. 0 rows or >=2 (no DB
        # uniqueness constraint enforces it) are both errors to surface, not a
        # missing-row crash or an arbitrary first-row pick.
        if len(season_rows) != 1:
            raise ValueError(
                f"league {league_id} must have exactly one is_current season, "
                f"found {len(season_rows)}"
            )
        season_id = _require_int(season_rows[0][0], "seasons.season_id")

        rows = _rows_for_league_season(league_id, season_id)
        _replace_points_pace(league_id, season_id, rows)

        print(
            f"[points_pace] league {league_id} current season {season_id} "
            f"refreshed: {len(rows)} rows"
        )


def validate_points_pace() -> None:
    """Validate every stored Big 5 curve against its fixture-derived source."""
    invalid_rounds = fetch_all(SQL_INVALID_ROUNDS)
    print(f"[validate points_pace] 0) Invalid rounds: {len(invalid_rounds)}")
    for row in invalid_rounds[:10]:
        print(
            f"  league={row[0]} season={row[1]} team={row[2]} "
            f"round={row[3]} date={row[4]} points={row[5]}"
        )
    if len(invalid_rounds) > 10:
        print(f"  ... and {len(invalid_rounds) - 10} more")

    checked = 0
    mismatches = []

    for league_id in BIG5_LEAGUE_IDS:
        season_rows = fetch_all(
            SQL_SELECT_SEASONS_SINCE_MIN_YEAR,
            (league_id, MIN_SEASON_START_YEAR),
        )

        for season_row in season_rows:
            season_id = _require_int(season_row[0], "seasons.season_id")
            expected = _rows_for_league_season(league_id, season_id)
            actual = fetch_all(
                SQL_SELECT_STORED_POINTS_PACE,
                (league_id, season_id),
            )
            checked += 1

            if expected != actual:
                mismatches.append(
                    (league_id, season_id, len(expected), len(actual))
                )

    print(
        "[validate points_pace] 1) Fixture/source mismatches: "
        f"{len(mismatches)} / {checked} seasons"
    )
    for league_id, season_id, expected_count, actual_count in mismatches[:10]:
        print(
            f"  league={league_id} season={season_id}: "
            f"expected={expected_count} actual={actual_count}"
        )
    if len(mismatches) > 10:
        print(f"  ... and {len(mismatches) - 10} more")

    passed = not invalid_rounds and not mismatches
    print(
        "[validate points_pace] Summary: "
        f"status={'PASS' if passed else 'FAIL'}, seasons={checked}"
    )
