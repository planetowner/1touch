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


EXPECTED_POSITIONS = [
    (24, "GK", 24, "GK"),
    (148, "CB", 25, "DF"),
    (149, "DM", 26, "MF"),
    (150, "AM", 26, "MF"),
    (151, "ST", 27, "FW"),
    (152, "LW", 27, "FW"),
    (153, "CM", 26, "MF"),
    (154, "RB", 25, "DF"),
    (155, "LB", 25, "DF"),
    (156, "RW", 27, "FW"),
    (157, "LM", 26, "MF"),
    (158, "RM", 26, "MF"),
    (163, "SS", 27, "FW"),
]


def verify_python_sources() -> int:
    paths = sorted(PACKAGE_ROOT.rglob("*.py"))
    for path in paths:
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
    return len(paths)


def verify_loader_contract() -> dict:
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
                "name": "Raphael Dias Belloli",
                "display_name": "Raphinha",
                "image_path": "https://cdn.sportmonks.com/player.png",
                "nationality_id": 5,
                "date_of_birth": "1996-12-14",
                "height": 176,
                "weight": 72,
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

    return {
        "sportmonks_detailed_position_id": 152,
        "database_position_id": player_row[3],
    }


def verify_database() -> dict:
    from one_touch_loader.core.db import fetch_all

    position_column_rows = fetch_all(
        """
        SELECT column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'positions'
        ORDER BY ordinal_position
        """
    )
    expected_columns = [
        ("position_id", "int unsigned", "NO"),
        ("position_code", "varchar(10)", "NO"),
        ("position_group_id", "int unsigned", "NO"),
        ("position_group_code", "varchar(10)", "NO"),
    ]
    if position_column_rows != expected_columns:
        raise AssertionError(
            f"Unexpected positions columns: {position_column_rows!r}"
        )

    position_rows = fetch_all(
        """
        SELECT
          position_id,
          position_code,
          position_group_id,
          position_group_code
        FROM positions
        ORDER BY position_id
        """
    )
    if position_rows != EXPECTED_POSITIONS:
        raise AssertionError(f"Unexpected positions rows: {position_rows!r}")

    player_position_columns = fetch_all(
        """
        SELECT column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'players'
          AND column_name IN ('position_id', 'detailed_position_id')
        ORDER BY ordinal_position
        """
    )
    if player_position_columns != [("position_id", "int unsigned", "YES")]:
        raise AssertionError(
            f"Unexpected players position columns: {player_position_columns!r}"
        )

    foreign_key_rows = fetch_all(
        """
        SELECT
          constraint_name,
          column_name,
          referenced_table_name,
          referenced_column_name
        FROM information_schema.key_column_usage
        WHERE constraint_schema = DATABASE()
          AND table_name = 'players'
          AND constraint_name = 'fk_players_position'
        ORDER BY constraint_name
        """
    )
    expected_foreign_key = [
        ("fk_players_position", "position_id", "positions", "position_id")
    ]
    if foreign_key_rows != expected_foreign_key:
        raise AssertionError(
            f"Unexpected players foreign keys: {foreign_key_rows!r}"
        )

    player_counts = fetch_all(
        """
        SELECT
          COUNT(*) AS players,
          SUM(CASE WHEN position_id IS NULL THEN 1 ELSE 0 END)
            AS players_without_position
        FROM players
        """
    )[0]
    player_count = int(player_counts[0])
    players_without_position = int(player_counts[1] or 0)

    return {
        "position_count": len(position_rows),
        "player_position_foreign_key": expected_foreign_key[0][0],
        "player_count": player_count,
        "players_without_position": players_without_position,
    }


def main() -> None:
    result = {
        "compiled_python_files": verify_python_sources(),
        "loader": verify_loader_contract(),
        "database": verify_database(),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
    print("Positions database and backend verification passed.")


if __name__ == "__main__":
    main()
