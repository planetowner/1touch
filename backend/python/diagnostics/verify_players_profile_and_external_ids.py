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


EXPECTED_PLAYER_COLUMNS = [
    ("player_id", "bigint unsigned", "NO"),
    ("display_name", "varchar(255)", "NO"),
    ("full_name", "varchar(255)", "NO"),
    ("position_id", "int unsigned", "YES"),
    ("nationality_id", "bigint unsigned", "YES"),
    ("date_of_birth", "date", "YES"),
    ("height_cm", "smallint unsigned", "YES"),
    ("weight_kg", "smallint unsigned", "YES"),
    ("image_path", "varchar(512)", "YES"),
]

EXPECTED_EXTERNAL_ID_COLUMNS = [
    ("player_id", "bigint unsigned", "NO"),
    ("provider", "varchar(50)", "NO"),
    ("external_player_id", "varchar(100)", "NO"),
]


def verify_python_sources() -> int:
    paths = sorted(PACKAGE_ROOT.rglob("*.py"))
    for path in paths:
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
    return len(paths)


def verify_loader_contracts() -> dict:
    from one_touch_loader.loaders.players_loader import _build_player_row
    from one_touch_loader.loaders.team_squad_members_loader import (
        _normalize_squad_item,
    )

    player_row, member_row = _normalize_squad_item(
        {
            "team_id": 83,
            "player_id": 160258,
            "position_id": 27,
            "detailed_position_id": 152,
            "jersey_number": 11,
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
    expected_player_row = (
        160258,
        "Raphinha",
        "Raphael Dias Belloli",
        152,
        5,
        "1996-12-14",
        176,
        72,
        "https://cdn.sportmonks.com/player.png",
    )
    if player_row != expected_player_row:
        raise AssertionError(f"Unexpected player row: {player_row!r}")
    if member_row != (83, 27965, 160258, 27, 11):
        raise AssertionError(f"Unexpected squad row: {member_row!r}")

    direct_row, direct_resolution = _build_player_row(
        {
            "player_id": 160258,
            "display_name": "Raphinha",
            "full_name": "Raphael Dias Belloli",
            "position_id": 152,
            "nationality_id": 5,
            "date_of_birth": "1996-12-14",
            "height_cm": 176,
            "weight_kg": 72,
            "image_path": "https://cdn.sportmonks.com/player.png",
        },
        [],
        {24, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 163},
        "player_endpoint",
    )
    if direct_row != expected_player_row:
        raise AssertionError(f"Unexpected direct player row: {direct_row!r}")
    if direct_resolution["position_source"] != "player_endpoint":
        raise AssertionError(
            f"Unexpected direct position source: {direct_resolution!r}"
        )

    staff_row, staff_resolution = _build_player_row(
        {
            "player_id": 3817,
            "display_name": "Nurgazy Khayrulin",
            "full_name": "Shkodran Mustafi",
            "position_id": 227,
            "nationality_id": 11,
            "date_of_birth": "1992-04-17",
            "height_cm": 184,
            "weight_kg": 82,
            "image_path": "https://cdn.sportmonks.com/player.png",
        },
        [],
        {24, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 163},
        "player_endpoint",
    )
    if staff_row[1] != "Shkodran Mustafi" or staff_row[3] is not None:
        raise AssertionError(f"Unexpected staff-contaminated row: {staff_row!r}")
    if not staff_resolution["corrected_display_name"]:
        raise AssertionError(
            f"Staff display name was not corrected: {staff_resolution!r}"
        )

    wage_loader_path = (
        PACKAGE_ROOT / "loaders" / "player_wage_loader.py"
    )
    wage_source = wage_loader_path.read_text(encoding="utf-8")
    forbidden_name_matching = [
        "_normalized_name",
        "_squad_player_names",
        "p.firstname",
        "p.lastname",
        "p.name",
    ]
    remaining = [value for value in forbidden_name_matching if value in wage_source]
    if remaining:
        raise AssertionError(
            f"Wage loader still contains name matching: {remaining!r}"
        )
    if "player_external_ids" not in wage_source or "'capology'" not in wage_source:
        raise AssertionError(
            "Wage loader does not use explicit Capology player IDs"
        )

    return {
        "sportmonks_name_field": "name -> full_name",
        "player_profile_source": "/v3/football/players/{player_id}",
        "squad_profile_fallback": "missing top-level data only",
        "position_priority": [
            "player endpoint detailed_position_id",
            "squad embedded detailed_position_id",
            "NULL",
        ],
        "staff_display_name_rule": "221/226/227 -> full_name",
        "wage_mapping": "player_external_ids(provider=capology)",
        "name_matching_removed": True,
    }


def verify_database() -> dict:
    from one_touch_loader.core.db import fetch_all

    player_columns = fetch_all(
        """
        SELECT column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'players'
        ORDER BY ordinal_position
        """
    )
    if player_columns != EXPECTED_PLAYER_COLUMNS:
        raise AssertionError(f"Unexpected players columns: {player_columns!r}")

    external_id_columns = fetch_all(
        """
        SELECT column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'player_external_ids'
        ORDER BY ordinal_position
        """
    )
    if external_id_columns != EXPECTED_EXTERNAL_ID_COLUMNS:
        raise AssertionError(
            f"Unexpected player_external_ids columns: {external_id_columns!r}"
        )

    foreign_keys = fetch_all(
        """
        SELECT
          constraint_name,
          table_name,
          column_name,
          referenced_table_name,
          referenced_column_name
        FROM information_schema.key_column_usage
        WHERE constraint_schema = DATABASE()
          AND constraint_name IN (
            'fk_players_position',
            'fk_player_external_ids_player'
          )
        ORDER BY table_name, constraint_name
        """
    )
    expected_foreign_keys = [
        (
            "fk_player_external_ids_player",
            "player_external_ids",
            "player_id",
            "players",
            "player_id",
        ),
        (
            "fk_players_position",
            "players",
            "position_id",
            "positions",
            "position_id",
        ),
    ]
    if foreign_keys != expected_foreign_keys:
        raise AssertionError(f"Unexpected player foreign keys: {foreign_keys!r}")

    player_count = int(fetch_all("SELECT COUNT(*) FROM players")[0][0])
    invalid_sportmonks_ids = fetch_all(
        """
        SELECT player_id, external_player_id
        FROM player_external_ids
        WHERE provider = 'sportmonks'
          AND external_player_id <> CAST(player_id AS CHAR)
        ORDER BY player_id
        """
    )
    if invalid_sportmonks_ids:
        raise AssertionError(
            f"Invalid Sportmonks player mappings: {invalid_sportmonks_ids!r}"
        )

    provider_counts = {
        str(provider): int(count)
        for provider, count in fetch_all(
            """
            SELECT provider, COUNT(*)
            FROM player_external_ids
            GROUP BY provider
            ORDER BY provider
            """
        )
    }
    if provider_counts.get("sportmonks") != player_count:
        raise AssertionError(
            "Every current player must have one exact Sportmonks mapping: "
            f"players={player_count}, mappings={provider_counts!r}"
        )

    profile_counts = fetch_all(
        """
        SELECT
          COUNT(*),
          SUM(players.display_name IS NULL OR TRIM(players.display_name) = ''),
          SUM(players.full_name IS NULL OR TRIM(players.full_name) = ''),
          SUM(players.position_id IS NULL),
          SUM(players.nationality_id IS NULL),
          SUM(players.date_of_birth IS NULL),
          SUM(players.height_cm IS NULL),
          SUM(players.weight_kg IS NULL),
          SUM(players.image_path IS NULL OR TRIM(players.image_path) = '')
        FROM players
        """
    )[0]
    required_missing = [int(value or 0) for value in profile_counts[1:3]]
    if any(required_missing):
        raise AssertionError(
            f"Required player fields are missing: {required_missing!r}"
        )

    invalid_positions = fetch_all(
        """
        SELECT players.player_id, players.position_id
        FROM players
        LEFT JOIN positions
          ON positions.position_id = players.position_id
        WHERE players.position_id IS NOT NULL
          AND positions.position_id IS NULL
        ORDER BY players.player_id
        """
    )
    if invalid_positions:
        raise AssertionError(f"Invalid player positions: {invalid_positions!r}")

    wage_rows = int(fetch_all("SELECT COUNT(*) FROM player_wages")[0][0])

    return {
        "player_count": player_count,
        "provider_counts": provider_counts,
        "optional_null_counts": {
            "position_id": int(profile_counts[3] or 0),
            "nationality_id": int(profile_counts[4] or 0),
            "date_of_birth": int(profile_counts[5] or 0),
            "height_cm": int(profile_counts[6] or 0),
            "weight_kg": int(profile_counts[7] or 0),
            "image_path": int(profile_counts[8] or 0),
        },
        "legacy_wage_rows_not_used_as_mappings": wage_rows,
    }


def main() -> None:
    result = {
        "compiled_python_files": verify_python_sources(),
        "loaders": verify_loader_contracts(),
        "database": verify_database(),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
    print("Players profile and external-ID verification passed.")


if __name__ == "__main__":
    main()
