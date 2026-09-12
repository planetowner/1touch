from __future__ import annotations

from typing import Optional

from ..core.db import fetch_all
from ..core.fixture_states import state_ids_for_screen_status
from ..core.sportmonks import SportmonksClient
from .fixture_details_loader import normalize_fixture_statistics, replace_fixture_detail_rows


# =========================================================
# SQL 쿼리
# =========================================================

SQL_SELECT_FIXTURE_BY_ID = """
SELECT fixture_id FROM fixtures WHERE fixture_id = %s
"""

SQL_SELECT_FIXTURE_IDS_BY_SEASON = """
SELECT
    f.fixture_id
FROM fixtures f
JOIN stages st ON st.stage_id = f.stage_id
WHERE st.season_id = %s
ORDER BY f.starting_at, f.fixture_id
"""

SQL_SELECT_FIXTURE_IDS_BY_SEASON_AND_STATES = """
SELECT
    f.fixture_id
FROM fixtures f
JOIN stages st ON st.stage_id = f.stage_id
WHERE st.season_id = %s
  AND f.state_id IN ({placeholders})
ORDER BY f.starting_at, f.fixture_id
"""

SQL_SELECT_CURRENT_BIG5_SEASON_IDS = """
SELECT s.season_id
FROM seasons s
WHERE s.is_current = 1
  AND s.competition_id IN (8,82,301,384,564)
ORDER BY s.competition_id, s.season_id
"""

def refresh_fixture_team_stats(fixture_id: int) -> None:
    fixture_rows = fetch_all(SQL_SELECT_FIXTURE_BY_ID, (fixture_id,))

    if not fixture_rows:
        raise ValueError(f"Fixture not found in DB: fixture_id={fixture_id}")

    sm = SportmonksClient()
    fixture_payload = sm.get_fixture_with_statistics(fixture_id)

    rows = normalize_fixture_statistics(fixture_payload, fixture_id)

    replace_fixture_detail_rows(fixture_id, rows)

    print(
        f"[team-stats] fixture {fixture_id}: "
        f"normalized_rows={len(rows['team_stats'])}"
    )


def refresh_fixture_team_stats_for_season(
    season_id: int,
    only_status: Optional[str] = None,
) -> None:
    if only_status is None:
        fixture_rows = fetch_all(
            SQL_SELECT_FIXTURE_IDS_BY_SEASON,
            (season_id,),
        )
    else:
        state_ids = state_ids_for_screen_status(only_status)
        placeholders = ",".join("%s" for _ in state_ids)
        fixture_rows = fetch_all(
            SQL_SELECT_FIXTURE_IDS_BY_SEASON_AND_STATES.format(
                placeholders=placeholders,
            ),
            (season_id, *state_ids),
        )

    fixture_ids = [int(row[0]) for row in fixture_rows]

    total = 0

    for fixture_id in fixture_ids:
        refresh_fixture_team_stats(fixture_id)
        total += 1

    print(
        f"[team-stats] season {season_id}: "
        f"fixtures_processed={total} "
        f"status_filter={only_status or 'ALL'}"
    )


def refresh_fixture_team_stats_for_current_seasons(
    only_status: Optional[str] = "past",
) -> None:
    season_rows = fetch_all(SQL_SELECT_CURRENT_BIG5_SEASON_IDS)
    season_ids = [int(row[0]) for row in season_rows]

    if not season_ids:
        raise RuntimeError("No current Big5 season IDs found.")

    total_seasons = 0

    for season_id in season_ids:
        refresh_fixture_team_stats_for_season(
            season_id,
            only_status=only_status,
        )
        total_seasons += 1

    print(
        f"[team-stats] current Big5 seasons refresh done: "
        f"seasons={total_seasons} status_filter={only_status or 'ALL'}"
    )
