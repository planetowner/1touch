from __future__ import annotations

import json

from one_touch_loader.core.db import fetch_all
from one_touch_loader.core.fixture_states import SCREEN_STATUS_STATE_IDS


EXPECTED_FIXTURE_COLUMNS = [
    "fixture_id",
    "stage_id",
    "round_id",
    "group_id",
    "aggregate_id",
    "leg",
    "home_team_id",
    "away_team_id",
    "starting_at",
    "venue_id",
    "state_id",
    "home_score",
    "away_score",
    "home_penalty_score",
    "away_penalty_score",
]

EXPECTED_AGGREGATE_COLUMNS = [
    ("aggregate_id", "bigint unsigned", "NO"),
    ("stage_id", "int", "NO"),
    ("winner_team_id", "bigint unsigned", "YES"),
]

EXPECTED_FIXTURE_FOREIGN_KEYS = {
    "fk_fixtures_aggregate",
    "fk_fixtures_away_team",
    "fk_fixtures_group",
    "fk_fixtures_home_team",
    "fk_fixtures_round",
    "fk_fixtures_stage",
    "fk_fixtures_state",
    "fk_fixtures_venue",
}

EXPECTED_AGGREGATE_FOREIGN_KEYS = {
    "fk_aggregates_stage",
    "fk_aggregates_winner_team",
}


def _single_int(sql: str) -> int:
    rows = fetch_all(sql)
    if len(rows) != 1 or len(rows[0]) != 1:
        raise AssertionError(f"Expected one scalar row: {rows!r}")
    return int(rows[0][0])


def main() -> None:
    table_rows = fetch_all(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name IN (
            'aggregates', 'fixtures', 'knockout_ties',
            'rounds', 'venues', 'fixture_states'
          )
        ORDER BY table_name
        """
    )
    table_names = [str(row[0]) for row in table_rows]
    if table_names != [
        "aggregates",
        "fixture_states",
        "fixtures",
        "rounds",
        "venues",
    ]:
        raise AssertionError(f"Unexpected fixture tables: {table_names!r}")

    column_rows = fetch_all(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'fixtures'
        ORDER BY ordinal_position
        """
    )
    fixture_columns = [str(row[0]) for row in column_rows]
    if fixture_columns != EXPECTED_FIXTURE_COLUMNS:
        raise AssertionError(f"Unexpected fixtures columns: {fixture_columns!r}")

    aggregate_columns = fetch_all(
        """
        SELECT column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'aggregates'
        ORDER BY ordinal_position
        """
    )
    if aggregate_columns != EXPECTED_AGGREGATE_COLUMNS:
        raise AssertionError(f"Unexpected aggregates columns: {aggregate_columns!r}")

    foreign_key_rows = fetch_all(
        """
        SELECT constraint_name
        FROM information_schema.key_column_usage
        WHERE constraint_schema = DATABASE()
          AND table_name = 'fixtures'
          AND referenced_table_name IS NOT NULL
        ORDER BY constraint_name
        """
    )
    fixture_foreign_keys = {str(row[0]) for row in foreign_key_rows}
    if fixture_foreign_keys != EXPECTED_FIXTURE_FOREIGN_KEYS:
        raise AssertionError(
            f"Unexpected fixtures foreign keys: {sorted(fixture_foreign_keys)!r}"
        )

    aggregate_foreign_key_rows = fetch_all(
        """
        SELECT constraint_name
        FROM information_schema.key_column_usage
        WHERE constraint_schema = DATABASE()
          AND table_name = 'aggregates'
          AND referenced_table_name IS NOT NULL
        ORDER BY constraint_name
        """
    )
    aggregate_foreign_keys = {str(row[0]) for row in aggregate_foreign_key_rows}
    if aggregate_foreign_keys != EXPECTED_AGGREGATE_FOREIGN_KEYS:
        raise AssertionError(
            f"Unexpected aggregates foreign keys: {sorted(aggregate_foreign_keys)!r}"
        )

    invalid_fixture_count = _single_int(
        """
        SELECT COUNT(*)
        FROM fixtures
        WHERE leg NOT REGEXP '^[1-9][0-9]*/[1-9][0-9]*$'
           OR CAST(SUBSTRING_INDEX(leg, '/', 1) AS UNSIGNED)
              > CAST(SUBSTRING_INDEX(leg, '/', -1) AS UNSIGNED)
           OR home_team_id = away_team_id
        """
    )
    if invalid_fixture_count:
        raise AssertionError(f"Invalid fixture rows: {invalid_fixture_count}")

    invalid_aggregate_count = _single_int(
        """
        SELECT COUNT(*)
        FROM aggregates a
        WHERE NOT EXISTS (
          SELECT 1
          FROM fixtures f
          WHERE f.aggregate_id = a.aggregate_id
        )
           OR EXISTS (
             SELECT 1
             FROM fixtures f
             WHERE f.aggregate_id = a.aggregate_id
               AND f.stage_id <> a.stage_id
           )
           OR (
             a.winner_team_id IS NOT NULL
             AND NOT EXISTS (
               SELECT 1
               FROM fixtures f
               WHERE f.aggregate_id = a.aggregate_id
                 AND a.winner_team_id IN (f.home_team_id, f.away_team_id)
             )
           )
        """
    )
    if invalid_aggregate_count:
        raise AssertionError(f"Invalid aggregate rows: {invalid_aggregate_count}")

    fixture_count = _single_int("SELECT COUNT(*) FROM fixtures")
    result = {
        "fixture_columns": fixture_columns,
        "aggregate_columns": [row[0] for row in aggregate_columns],
        "fixture_foreign_keys": sorted(fixture_foreign_keys),
        "aggregate_foreign_keys": sorted(aggregate_foreign_keys),
        "screen_state_groups": {
            key: list(value) for key, value in SCREEN_STATUS_STATE_IDS.items()
        },
        "row_counts": {
            "fixtures": fixture_count,
            "aggregates": _single_int("SELECT COUNT(*) FROM aggregates"),
            "rounds": _single_int("SELECT COUNT(*) FROM rounds"),
            "venues": _single_int("SELECT COUNT(*) FROM venues"),
            "fixture_states": _single_int("SELECT COUNT(*) FROM fixture_states"),
        },
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print("Fixtures and aggregates database verification passed.")


if __name__ == "__main__":
    main()
