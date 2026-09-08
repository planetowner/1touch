from __future__ import annotations

import json
import sys
from datetime import date
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
    ("player_id", "bigint unsigned", "NO"),
    ("position_group_id", "int unsigned", "YES"),
    ("jersey_number", "smallint unsigned", "YES"),
    (
        "squad_role",
        "enum('crucial','important','rotation','sporadic','prospect')",
        "YES",
    ),
    (
        "leadership_role",
        "enum('captain','vice_captain')",
        "YES",
    ),
]


def verify_python_sources() -> int:
    paths = sorted(PACKAGE_ROOT.rglob("*.py"))
    for path in paths:
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
    return len(paths)


def verify_loader_contract() -> dict:
    from one_touch_loader.loaders.team_squad_members_loader import (
        SQL_UPSERT_SQUAD_MEMBER,
        _filter_current_squad_items,
        _filter_historical_squad_items,
        _normalize_squad_item,
    )

    player_row, member_row = _normalize_squad_item(
        {
            "team_id": 83,
            "player_id": 160258,
            "position_id": 27,
            "detailed_position_id": 152,
            "jersey_number": 11,
            "captain": True,
            "player": {
                "id": 160258,
                "display_name": "Raphinha",
                "name": "Raphael Dias Belloli",
                "nationality_id": 5,
                "date_of_birth": "1996-12-14",
                "height": 176,
                "weight": 72,
                "image_path": "https://cdn.sportmonks.com/player.png",
            },
        },
        team_id=83,
        season_id=27965,
        index=0,
    )

    if player_row[0] != 160258 or player_row[3] != 152:
        raise AssertionError(f"Unexpected normalized player row: {player_row!r}")
    if member_row != (83, 27965, 160258, 27, 11):
        raise AssertionError(f"Unexpected normalized squad row: {member_row!r}")

    null_position_player_row, null_position_member_row = _normalize_squad_item(
        {
            "team_id": 83,
            "player_id": 237,
            "position_id": 25,
            "detailed_position_id": None,
            "jersey_number": 5,
            "player": {
                "id": 237,
                "display_name": "Pablo Zabaleta",
                "name": "Pablo Javier Zabaleta Girod",
                "detailed_position_id": None,
            },
        },
        team_id=83,
        season_id=27965,
        index=1,
    )
    if null_position_player_row[3] is not None:
        raise AssertionError(
            f"Missing detailed position was not kept NULL: {null_position_player_row!r}"
        )
    if null_position_member_row != (83, 27965, 237, 25, 5):
        raise AssertionError(
            f"Unexpected NULL-position squad row: {null_position_member_row!r}"
        )

    _, embedded_group_member_row = _normalize_squad_item(
        {
            "team_id": 776,
            "player_id": 62866,
            "position_id": 221,
            "detailed_position_id": None,
            "jersey_number": 1,
            "player": {
                "id": 62866,
                "display_name": "Ludovic Butelle",
                "name": "Ludovic Butelle",
                "position_id": 24,
                "detailed_position_id": None,
            },
        },
        team_id=776,
        season_id=6405,
        index=2,
    )
    if embedded_group_member_row != (776, 6405, 62866, 24, 1):
        raise AssertionError(
            "Valid embedded position group was not used: "
            f"{embedded_group_member_row!r}"
        )

    _, unavailable_group_member_row = _normalize_squad_item(
        {
            "team_id": 37,
            "player_id": 96514,
            "position_id": 221,
            "detailed_position_id": 226,
            "jersey_number": 92,
            "player": {
                "id": 96514,
                "display_name": "Federico Insua",
                "name": "Stephan El Shaarawy",
                "position_id": 221,
                "detailed_position_id": 226,
            },
        },
        team_id=37,
        season_id=23746,
        index=3,
    )
    if unavailable_group_member_row != (37, 23746, 96514, None, 92):
        raise AssertionError(
            "Unverified position group was not kept NULL: "
            f"{unavailable_group_member_row!r}"
        )

    forbidden_provider_columns = ["squad_role", "leadership_role", "captain"]
    present = [
        column
        for column in forbidden_provider_columns
        if column in SQL_UPSERT_SQUAD_MEMBER
    ]
    if present:
        raise AssertionError(
            "Sportmonks squad upsert writes 1Touch-owned columns: "
            f"{present!r}"
        )

    current_squad = [{"player_id": player_id} for player_id in (1, 2, 3, 4)]
    current_transfers = [
        {
            "id": 1,
            "player_id": 1,
            "from_team_id": 83,
            "to_team_id": 1001,
            "date": "2026-08-01",
            "completed": True,
        },
        {
            "id": 2,
            "player_id": 3,
            "from_team_id": 83,
            "to_team_id": 1002,
            "date": "2026-09-01",
            "completed": True,
        },
        {
            "id": 3,
            "player_id": 4,
            "from_team_id": 83,
            "to_team_id": 1003,
            "date": "2026-07-10",
            "completed": True,
        },
        {
            "id": 4,
            "player_id": 4,
            "from_team_id": 1003,
            "to_team_id": 83,
            "date": "2026-07-20",
            "completed": True,
        },
        {
            "id": 5,
            "player_id": 99,
            "from_team_id": 1004,
            "to_team_id": 83,
            "date": "2026-08-01",
            "completed": True,
        },
        {
            "id": 6,
            "player_id": 2,
            "from_team_id": 83,
            "to_team_id": 1005,
            "date": None,
            "completed": True,
        },
    ]
    current_filtered, current_removed = _filter_current_squad_items(
        current_squad,
        current_transfers,
        team_id=83,
        season_start=date(2026, 7, 1),
        today=date(2026, 8, 10),
    )
    current_ids = {item["player_id"] for item in current_filtered}
    if current_ids != {2, 3, 4} or current_removed != {1}:
        raise AssertionError(
            "Unexpected current squad reconciliation: "
            f"ids={current_ids!r}, removed={current_removed!r}"
        )

    historical_squad = [
        {"player_id": player_id} for player_id in (10, 11, 12, 13, 14, 15, 16)
    ]
    historical_transfers = [
        {
            "id": 11,
            "player_id": 11,
            "from_team_id": 83,
            "to_team_id": 1100,
            "date": "2025-01-10",
            "completed": True,
        },
        {
            "id": 12,
            "player_id": 12,
            "from_team_id": 83,
            "to_team_id": 1200,
            "date": "2025-01-10",
            "completed": True,
        },
        {
            "id": 13,
            "player_id": 13,
            "from_team_id": 1300,
            "to_team_id": 83,
            "date": "2025-06-10",
            "completed": True,
        },
        {
            "id": 14,
            "player_id": 14,
            "from_team_id": 1400,
            "to_team_id": 83,
            "date": "2025-06-10",
            "completed": True,
        },
        {
            "id": 15,
            "player_id": 15,
            "from_team_id": 83,
            "to_team_id": 1500,
            "date": "2025-06-01",
            "completed": True,
        },
        {
            "id": 16,
            "player_id": 16,
            "from_team_id": 83,
            "to_team_id": 1600,
            "date": "2025-01-10",
            "completed": True,
        },
        {
            "id": 17,
            "player_id": 16,
            "from_team_id": 1600,
            "to_team_id": 83,
            "date": "2025-05-01",
            "completed": True,
        },
        {
            "id": 18,
            "player_id": 99,
            "from_team_id": 9900,
            "to_team_id": 83,
            "date": "2025-01-01",
            "completed": True,
        },
    ]
    historical_filtered, historical_removed = _filter_historical_squad_items(
        historical_squad,
        historical_transfers,
        team_id=83,
        season_start=date(2024, 7, 1),
        cutoff=date(2025, 5, 25),
        lineup_dates_by_player={
            12: {date(2025, 2, 1)},
            14: {date(2025, 3, 1)},
        },
    )
    historical_ids = {item["player_id"] for item in historical_filtered}
    if historical_ids != {10, 12, 14, 15}:
        raise AssertionError(
            "Unexpected historical squad reconstruction: "
            f"ids={historical_ids!r}, removed={historical_removed!r}"
        )
    if historical_removed != {
        11: "no_first_team_lineup_after_last_out",
        13: "first_recorded_in_after_cutoff",
        16: "no_first_team_lineup_after_last_out",
    }:
        raise AssertionError(
            f"Unexpected historical removal reasons: {historical_removed!r}"
        )

    return {
        "sportmonks_fields": ["position_id", "jersey_number"],
        "ignored_sportmonks_captain": True,
        "one_touch_calculated_field": "squad_role",
        "one_touch_manual_field": "leadership_role",
        "current_rule": "provider squad minus effective latest OUT",
        "historical_rule": "provider season squad plus post-OUT lineup evidence",
        "missing_transfer_date": "ignore only the undated transfer row",
        "transfer_only_additions": False,
    }


def verify_database() -> dict:
    from one_touch_loader.core.db import fetch_all

    columns = fetch_all(
        """
        SELECT column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'team_squad_members'
        ORDER BY ordinal_position
        """
    )
    if columns != EXPECTED_COLUMNS:
        raise AssertionError(f"Unexpected team_squad_members columns: {columns!r}")

    comments = dict(
        fetch_all(
            """
            SELECT column_name, column_comment
            FROM information_schema.columns
            WHERE table_schema = DATABASE()
              AND table_name = 'team_squad_members'
              AND column_name IN ('squad_role', 'leadership_role')
            ORDER BY column_name
            """
        )
    )
    if comments != {
        "leadership_role": (
            "Manually maintained by 1Touch; not provided by Sportmonks"
        ),
        "squad_role": "Calculated by 1Touch; not provided by Sportmonks",
    }:
        raise AssertionError(f"Unexpected ownership comments: {comments!r}")

    indexes = fetch_all(
        """
        SELECT index_name, GROUP_CONCAT(column_name ORDER BY seq_in_index)
        FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = 'team_squad_members'
        GROUP BY index_name
        ORDER BY index_name
        """
    )
    expected_indexes = [
        ("idx_team_squad_player", "player_id"),
        ("idx_team_squad_season", "season_id"),
        ("PRIMARY", "team_id,season_id,player_id"),
        (
            "uq_team_squad_leadership_role",
            "team_id,season_id,leadership_role",
        ),
    ]
    if indexes != expected_indexes:
        raise AssertionError(f"Unexpected team squad indexes: {indexes!r}")

    foreign_keys = fetch_all(
        """
        SELECT
          constraint_name,
          column_name,
          referenced_table_name,
          referenced_column_name
        FROM information_schema.key_column_usage
        WHERE constraint_schema = DATABASE()
          AND table_name = 'team_squad_members'
          AND referenced_table_name IS NOT NULL
        ORDER BY constraint_name, ordinal_position
        """
    )
    expected_foreign_keys = [
        ("fk_team_squad_player", "player_id", "players", "player_id"),
        ("fk_team_squad_season", "season_id", "seasons", "season_id"),
        ("fk_team_squad_team", "team_id", "teams", "team_id"),
    ]
    if foreign_keys != expected_foreign_keys:
        raise AssertionError(f"Unexpected team squad foreign keys: {foreign_keys!r}")

    current_barcelona_rows = fetch_all(
        """
        SELECT
          team_squad_members.season_id,
          COUNT(*),
          SUM(team_squad_members.position_group_id IS NULL),
          SUM(team_squad_members.jersey_number IS NULL),
          SUM(team_squad_members.squad_role IS NOT NULL),
          SUM(team_squad_members.leadership_role IS NOT NULL)
        FROM team_squad_members
        JOIN seasons
          ON seasons.season_id = team_squad_members.season_id
        WHERE team_squad_members.team_id = 83
          AND seasons.is_current = 1
        GROUP BY team_squad_members.season_id
        """
    )
    if len(current_barcelona_rows) != 1:
        raise AssertionError(
            "Expected one current Barcelona squad snapshot: "
            f"{current_barcelona_rows!r}"
        )

    row = current_barcelona_rows[0]
    if int(row[1]) == 0:
        raise AssertionError("Current Barcelona squad snapshot is empty")

    return {
        "barcelona_current_season_id": int(row[0]),
        "barcelona_squad_members": int(row[1]),
        "missing_position_groups": int(row[2] or 0),
        "missing_jersey_numbers": int(row[3] or 0),
        "calculated_squad_roles": int(row[4] or 0),
        "manual_leadership_roles": int(row[5] or 0),
    }


def main() -> None:
    result = {
        "compiled_python_files": verify_python_sources(),
        "loader": verify_loader_contract(),
        "database": verify_database(),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
    print("Team squad members database and backend verification passed.")


if __name__ == "__main__":
    main()
