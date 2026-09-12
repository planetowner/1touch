from __future__ import annotations

import json
import sys
from pathlib import Path

from dotenv import load_dotenv


BACKEND_ROOT = Path(__file__).resolve().parents[2]
PYTHON_ROOT = BACKEND_ROOT / "python"
PACKAGE_ROOT = PYTHON_ROOT / "one_touch_loader"

sys.path.insert(0, str(PYTHON_ROOT))
load_dotenv(BACKEND_ROOT / ".env")


EXPECTED_COLUMNS = [
    ("team_id", "bigint unsigned", "NO"),
    ("season_id", "bigint unsigned", "NO"),
]


def verify_python_sources() -> int:
    paths = sorted(PACKAGE_ROOT.rglob("*.py"))
    for path in paths:
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
    return len(paths)


def verify_loader_contract() -> dict:
    from one_touch_loader.loaders.team_seasons_loader import (
        _collect_season_memberships,
    )

    class FakeSportmonksClient:
        def iter_teams_by_season(self, season_id: int):
            if season_id != 1001:
                raise AssertionError(f"Unexpected season_id={season_id}")
            yield {"id": 83}
            yield {"id": 86}
            yield {"id": 999999}

        def iter_fixtures_by_season(self, season_id: int, include: str):
            if season_id != 1001 or include != "participants":
                raise AssertionError(
                    f"Unexpected fixture request: season_id={season_id}, "
                    f"include={include!r}"
                )
            yield {
                "id": 5001,
                "participants": [{"id": 83}, {"id": 86}],
            }

    rows, counts = _collect_season_memberships(
        FakeSportmonksClient(),
        1001,
        {83, 86, 90},
        False,
    )
    if rows != [(83, 1001), (86, 1001)]:
        raise AssertionError(f"Unexpected team-season rows: {rows!r}")
    if counts != {
        "provider_team_count": 3,
        "fixture_team_count": 2,
        "stored_team_count": 2,
        "skipped_without_fixture_count": 1,
        "skipped_missing_team_count": 0,
        "is_pending": False,
    }:
        raise AssertionError(f"Unexpected collection counts: {counts!r}")

    class EmptySportmonksClient:
        def iter_teams_by_season(self, season_id: int):
            return iter(())

    pending_rows, pending_counts = _collect_season_memberships(
        EmptySportmonksClient(),
        1002,
        {83},
        True,
    )
    if pending_rows:
        raise AssertionError(f"Unexpected pending rows: {pending_rows!r}")
    if pending_counts != {
        "provider_team_count": 0,
        "fixture_team_count": None,
        "stored_team_count": 0,
        "skipped_without_fixture_count": 0,
        "skipped_missing_team_count": 0,
        "is_pending": True,
    }:
        raise AssertionError(f"Unexpected pending counts: {pending_counts!r}")

    try:
        _collect_season_memberships(
            EmptySportmonksClient(),
            1003,
            {83},
            False,
        )
    except ValueError as exc:
        if str(exc) != "Sportmonks returned no teams for season_id=1003":
            raise AssertionError(f"Unexpected historical error: {exc}") from exc
    else:
        raise AssertionError("Empty historical season did not fail")

    class UnmatchedSportmonksClient:
        def iter_teams_by_season(self, season_id: int):
            yield {"id": 999999}

        def iter_fixtures_by_season(self, season_id: int, include: str):
            if include != "participants":
                raise AssertionError(f"Unexpected include={include!r}")
            yield {
                "id": 5002,
                "participants": [{"id": 999999}, {"id": 888888}],
            }

    unmatched_rows, unmatched_counts = _collect_season_memberships(
        UnmatchedSportmonksClient(),
        1004,
        {83},
        True,
    )
    if unmatched_rows:
        raise AssertionError(f"Unexpected unmatched rows: {unmatched_rows!r}")
    if unmatched_counts != {
        "provider_team_count": 1,
        "fixture_team_count": None,
        "stored_team_count": 0,
        "skipped_without_fixture_count": 0,
        "skipped_missing_team_count": 1,
        "is_pending": True,
    }:
        raise AssertionError(f"Unexpected unmatched counts: {unmatched_counts!r}")

    try:
        _collect_season_memberships(
            UnmatchedSportmonksClient(),
            1005,
            {83},
            False,
        )
    except ValueError as exc:
        expected_error = (
            "No Sportmonks teams exist in teams for historical season_id=1005"
        )
        if str(exc) != expected_error:
            raise AssertionError(f"Unexpected unmatched error: {exc}") from exc
    else:
        raise AssertionError("Unmatched historical season did not fail")

    return {
        "all_scope": "all rows in seasons",
        "selected_scope": "all season_ids with the exact season name",
        "stored_rule": (
            "historical season teams intersect fixture participants and teams; "
            "current season teams intersect teams"
        ),
        "empty_rule": "zero stored current is pending; historical fails",
        "stored_columns": ["team_id", "season_id"],
    }


def verify_database() -> dict:
    from one_touch_loader.core.db import fetch_all

    columns = fetch_all(
        """
        SELECT column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'team_seasons'
        ORDER BY ordinal_position
        """
    )
    if columns != EXPECTED_COLUMNS:
        raise AssertionError(f"Unexpected team_seasons columns: {columns!r}")

    indexes = fetch_all(
        """
        SELECT index_name, GROUP_CONCAT(column_name ORDER BY seq_in_index)
        FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = 'team_seasons'
        GROUP BY index_name
        ORDER BY index_name
        """
    )
    expected_indexes = [
        ("idx_team_seasons_season", "season_id"),
        ("PRIMARY", "team_id,season_id"),
    ]
    if indexes != expected_indexes:
        raise AssertionError(f"Unexpected team_seasons indexes: {indexes!r}")

    foreign_keys = fetch_all(
        """
        SELECT
          constraint_name,
          column_name,
          referenced_table_name,
          referenced_column_name
        FROM information_schema.key_column_usage
        WHERE constraint_schema = DATABASE()
          AND table_name = 'team_seasons'
          AND referenced_table_name IS NOT NULL
        ORDER BY constraint_name
        """
    )
    expected_foreign_keys = [
        ("fk_team_seasons_season", "season_id", "seasons", "season_id"),
        ("fk_team_seasons_team", "team_id", "teams", "team_id"),
    ]
    if foreign_keys != expected_foreign_keys:
        raise AssertionError(
            f"Unexpected team_seasons foreign keys: {foreign_keys!r}"
        )

    orphan_count = int(
        fetch_all(
            """
            SELECT COUNT(*)
            FROM team_seasons
            LEFT JOIN teams ON teams.team_id = team_seasons.team_id
            LEFT JOIN seasons ON seasons.season_id = team_seasons.season_id
            WHERE teams.team_id IS NULL OR seasons.season_id IS NULL
            """
        )[0][0]
    )
    if orphan_count:
        raise AssertionError(
            f"team_seasons contains orphan relationships: {orphan_count}"
        )

    counts = fetch_all(
        """
        SELECT
          COUNT(*),
          COUNT(DISTINCT team_id),
          COUNT(DISTINCT season_id)
        FROM team_seasons
        """
    )[0]
    membership_count = int(counts[0])
    if membership_count == 0:
        raise AssertionError("team_seasons is empty")

    competition_counts = fetch_all(
        """
        SELECT seasons.competition_id, COUNT(*)
        FROM team_seasons
        JOIN seasons ON seasons.season_id = team_seasons.season_id
        GROUP BY seasons.competition_id
        ORDER BY seasons.competition_id
        """
    )

    empty_seasons = fetch_all(
        """
        SELECT
          seasons.season_id,
          seasons.competition_id,
          seasons.name,
          seasons.is_current
        FROM seasons
        LEFT JOIN team_seasons
          ON team_seasons.season_id = seasons.season_id
        GROUP BY
          seasons.season_id,
          seasons.competition_id,
          seasons.name,
          seasons.is_current
        HAVING COUNT(team_seasons.team_id) = 0
        ORDER BY seasons.name, seasons.competition_id, seasons.season_id
        """
    )
    historical_empty_seasons = [
        row for row in empty_seasons if not bool(row[3])
    ]
    if historical_empty_seasons:
        raise AssertionError(
            "Historical seasons have no team memberships: "
            f"{historical_empty_seasons!r}"
        )

    unsupported_season_count = int(
        fetch_all(
            """
            SELECT COUNT(*)
            FROM seasons
            WHERE CAST(LEFT(name, 4) AS UNSIGNED) < 2017
            """
        )[0][0]
    )
    if unsupported_season_count:
        raise AssertionError(
            "seasons contains rows before 2017/2018: "
            f"{unsupported_season_count}"
        )

    return {
        "membership_count": membership_count,
        "linked_teams": int(counts[1]),
        "linked_seasons": int(counts[2]),
        "orphan_relationships": orphan_count,
        "empty_current_seasons": [
            {
                "season_id": int(row[0]),
                "competition_id": int(row[1]),
                "season_name": str(row[2]),
            }
            for row in empty_seasons
        ],
        "competition_memberships": {
            str(competition_id): int(count)
            for competition_id, count in competition_counts
        },
    }


def main() -> None:
    result = {
        "compiled_python_files": verify_python_sources(),
        "loader": verify_loader_contract(),
        "database": verify_database(),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print("team_seasons database and backend verification passed.")


if __name__ == "__main__":
    main()
