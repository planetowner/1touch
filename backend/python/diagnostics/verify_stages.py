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


EXPECTED_STAGE_COLUMNS = [
    ("stage_id", "int", "NO"),
    ("season_id", "bigint unsigned", "NO"),
    ("stage_type_id", "int", "NO"),
    ("name", "varchar(128)", "NO"),
]

EXPECTED_STAGE_TYPES = [
    (223, "group-stage", "GROUP_STAGE"),
    (224, "knock-out", "KNOCK_OUT"),
    (225, "qualifying", "QUALIFYING"),
]

EXPECTED_STAGE_FOREIGN_KEYS = [
    (
        "fk_stages_season",
        "season_id",
        "seasons",
        "season_id",
    ),
    (
        "fk_stages_stage_type",
        "stage_type_id",
        "stage_types",
        "stage_type_id",
    ),
]


def verify_python_sources() -> int:
    paths = sorted(PACKAGE_ROOT.rglob("*.py"))
    for path in paths:
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
    return len(paths)


def verify_database() -> dict:
    from one_touch_loader.core.db import fetch_all

    stage_columns = fetch_all(
        """
        SELECT column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'stages'
        ORDER BY ordinal_position
        """
    )
    if stage_columns != EXPECTED_STAGE_COLUMNS:
        raise AssertionError(f"Unexpected stages columns: {stage_columns!r}")

    stage_type_columns = fetch_all(
        """
        SELECT column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'stage_types'
        ORDER BY ordinal_position
        """
    )
    expected_stage_type_columns = [
        ("stage_type_id", "int", "NO"),
        ("code", "varchar(50)", "NO"),
        ("name", "varchar(50)", "NO"),
    ]
    if stage_type_columns != expected_stage_type_columns:
        raise AssertionError(
            f"Unexpected stage_types columns: {stage_type_columns!r}"
        )

    stage_types = fetch_all(
        "SELECT stage_type_id, code, name FROM stage_types ORDER BY stage_type_id"
    )
    if stage_types != EXPECTED_STAGE_TYPES:
        raise AssertionError(f"Unexpected stage types: {stage_types!r}")

    foreign_keys = fetch_all(
        """
        SELECT
          constraint_name,
          column_name,
          referenced_table_name,
          referenced_column_name
        FROM information_schema.key_column_usage
        WHERE constraint_schema = DATABASE()
          AND table_name = 'stages'
          AND referenced_table_name IS NOT NULL
        ORDER BY constraint_name
        """
    )
    if foreign_keys != EXPECTED_STAGE_FOREIGN_KEYS:
        raise AssertionError(f"Unexpected stages foreign keys: {foreign_keys!r}")

    invalid_stage_count = int(
        fetch_all(
            """
            SELECT COUNT(*)
            FROM stages st
            LEFT JOIN seasons s ON s.season_id = st.season_id
            LEFT JOIN stage_types t ON t.stage_type_id = st.stage_type_id
            WHERE s.season_id IS NULL
               OR t.stage_type_id IS NULL
            """
        )[0][0]
    )
    if invalid_stage_count:
        raise AssertionError(f"Invalid stage rows: {invalid_stage_count}")

    return {
        "stage_columns": [row[0] for row in stage_columns],
        "stage_types": [
            {
                "stage_type_id": row[0],
                "code": row[1],
                "name": row[2],
            }
            for row in stage_types
        ],
        "foreign_keys": [row[0] for row in foreign_keys],
        "stage_count": int(fetch_all("SELECT COUNT(*) FROM stages")[0][0]),
    }


def main() -> None:
    result = {
        "compiled_python_files": verify_python_sources(),
        "database": verify_database(),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print("Stages database and backend verification passed.")


if __name__ == "__main__":
    main()
