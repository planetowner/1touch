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


EXPECTED_COUNTRY_COLUMNS = [
    ("country_id", "bigint unsigned", "NO"),
    ("name", "varchar(120)", "NO"),
    ("image_path", "varchar(512)", "YES"),
]


def verify_python_sources() -> int:
    paths = sorted(PACKAGE_ROOT.rglob("*.py"))
    for path in paths:
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
    return len(paths)


def verify_loader_contract() -> dict:
    from one_touch_loader.loaders.countries_loader import _normalize_country

    row = _normalize_country(
        {
            "id": 32,
            "name": "Spain",
            "image_path": (
                "https://cdn.sportmonks.com/images/countries/png/short/es.png"
            ),
            "official_name": "Kingdom of Spain",
            "iso2": "ES",
            "iso3": "ESP",
        },
        0,
    )
    if row != (
        32,
        "Spain",
        "https://cdn.sportmonks.com/images/countries/png/short/es.png",
    ):
        raise AssertionError(f"Unexpected normalized country row: {row!r}")

    no_image_row = _normalize_country(
        {"id": 999999, "name": "No Image", "image_path": None},
        1,
    )
    if no_image_row != (999999, "No Image", None):
        raise AssertionError(f"Unexpected nullable image row: {no_image_row!r}")

    return {
        "sportmonks_resource": "/v3/core/countries",
        "stored_fields": ["id -> country_id", "name", "image_path"],
        "ignored_fields": ["official_name", "fifa_name", "iso2", "iso3"],
    }


def verify_database() -> dict:
    from one_touch_loader.core.db import fetch_all

    columns = fetch_all(
        """
        SELECT column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'countries'
        ORDER BY ordinal_position
        """
    )
    if columns != EXPECTED_COUNTRY_COLUMNS:
        raise AssertionError(f"Unexpected countries columns: {columns!r}")

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
          AND constraint_name = 'fk_players_nationality'
        """
    )
    expected_foreign_keys = [
        (
            "fk_players_nationality",
            "players",
            "nationality_id",
            "countries",
            "country_id",
        )
    ]
    if foreign_keys != expected_foreign_keys:
        raise AssertionError(f"Unexpected nationality foreign key: {foreign_keys!r}")

    country_count = int(fetch_all("SELECT COUNT(*) FROM countries")[0][0])
    if country_count == 0:
        raise AssertionError("countries is empty")

    invalid_country_rows = int(
        fetch_all(
            """
            SELECT COUNT(*)
            FROM countries
            WHERE name IS NULL OR TRIM(name) = ''
            """
        )[0][0]
    )
    if invalid_country_rows:
        raise AssertionError(
            f"countries contains invalid required rows: {invalid_country_rows}"
        )

    orphan_nationalities = int(
        fetch_all(
            """
            SELECT COUNT(*)
            FROM players
            LEFT JOIN countries
              ON countries.country_id = players.nationality_id
            WHERE players.nationality_id IS NOT NULL
              AND countries.country_id IS NULL
            """
        )[0][0]
    )
    if orphan_nationalities:
        raise AssertionError(
            f"players contains orphan nationality IDs: {orphan_nationalities}"
        )

    player_nationalities = int(
        fetch_all(
            "SELECT COUNT(*) FROM players WHERE nationality_id IS NOT NULL"
        )[0][0]
    )
    missing_country_images = int(
        fetch_all("SELECT COUNT(*) FROM countries WHERE image_path IS NULL")[0][0]
    )

    return {
        "country_count": country_count,
        "countries_without_image": missing_country_images,
        "players_with_nationality": player_nationalities,
        "orphan_player_nationalities": orphan_nationalities,
        "foreign_key": "players.nationality_id -> countries.country_id",
    }


def main() -> None:
    result = {
        "compiled_python_files": verify_python_sources(),
        "loader": verify_loader_contract(),
        "database": verify_database(),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
    print("Countries database and backend verification passed.")


if __name__ == "__main__":
    main()
