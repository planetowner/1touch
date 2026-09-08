from __future__ import annotations

import importlib
import json
import sys
from pathlib import Path

from dotenv import load_dotenv


BACKEND_ROOT = Path(__file__).resolve().parents[2]
PYTHON_ROOT = BACKEND_ROOT / "python"
PACKAGE_ROOT = PYTHON_ROOT / "one_touch_loader"

sys.path.insert(0, str(PYTHON_ROOT))
load_dotenv(BACKEND_ROOT / ".env")


def verify_python_sources() -> int:
    paths = sorted(PACKAGE_ROOT.rglob("*.py"))
    for path in paths:
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
    return len(paths)


def verify_imports() -> list[str]:
    modules = [
        "one_touch_loader.api.main",
        "one_touch_loader.loaders.teams_loader",
        "one_touch_loader.loaders.best_eleven_loader",
        "one_touch_loader.loaders.player_team_honours_loader",
        "one_touch_loader.loaders.standings_loader",
        "one_touch_loader.loaders.team_stats_loader",
        "one_touch_loader.loaders.transfers_loader",
        "one_touch_loader.loaders.xg_standings_loader",
    ]
    for module_name in modules:
        importlib.import_module(module_name)
    return modules


def verify_database() -> dict:
    from one_touch_loader.core.db import fetch_all

    table_rows = fetch_all(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name IN ('leagues', 'competitions')
        ORDER BY table_name
        """
    )
    table_names = [row[0] for row in table_rows]
    if table_names != ["competitions"]:
        raise AssertionError(f"Unexpected competition tables: {table_names!r}")

    stale_columns = fetch_all(
        """
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND column_name IN ('league_id', 'league_name', 'league_image_path')
        ORDER BY table_name, ordinal_position
        """
    )
    if stale_columns:
        raise AssertionError(f"Legacy internal columns remain: {stale_columns!r}")

    competition_rows = fetch_all(
        """
        SELECT competition_id, name, competition_type
        FROM competitions
        ORDER BY competition_id
        """
    )
    if len(competition_rows) != 12:
        raise AssertionError(
            f"Expected 12 competitions, found {len(competition_rows)}"
        )
    if any(row[2] not in {"league", "europe", "domestic_cup"} for row in competition_rows):
        raise AssertionError(f"Invalid competition type: {competition_rows!r}")

    # 교체 대상인 경기 통계의 FK는 경기 상세 검증에서 확인해요.
    expected_foreign_keys = {
        "fk_seasons_competition",
        "fk_understat_league_map_competition",
        "fk_xg_standings_competition",
        "fk_xg_stand_calib_competition",
    }
    foreign_key_rows = fetch_all(
        """
        SELECT constraint_name
        FROM information_schema.key_column_usage
        WHERE constraint_schema = DATABASE()
          AND referenced_table_name = 'competitions'
          AND table_name <> 'fixture_team_stats_raw'
        ORDER BY constraint_name
        """
    )
    foreign_keys = {row[0] for row in foreign_key_rows}
    if foreign_keys != expected_foreign_keys:
        raise AssertionError(
            f"Unexpected competitions foreign keys: {sorted(foreign_keys)!r}"
        )

    view_columns = fetch_all(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'v_team_attribute_display_scores'
        ORDER BY ordinal_position
        """
    )
    view_column_names = [row[0] for row in view_columns]
    if "competition_id" not in view_column_names or "league_id" in view_column_names:
        raise AssertionError(f"Unexpected view columns: {view_column_names!r}")

    season_column_rows = fetch_all(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'seasons'
        ORDER BY ordinal_position
        """
    )
    season_columns = [row[0] for row in season_column_rows]
    expected_season_columns = [
        "season_id",
        "competition_id",
        "name",
        "is_current",
    ]
    if season_columns != expected_season_columns:
        raise AssertionError(f"Unexpected seasons columns: {season_columns!r}")

    invalid_season_names = fetch_all(
        """
        SELECT season_id, name
        FROM seasons
        WHERE name NOT REGEXP '^[0-9]{4}/[0-9]{4}$'
           OR CAST(RIGHT(name, 4) AS UNSIGNED)
              <> CAST(LEFT(name, 4) AS UNSIGNED) + 1
        ORDER BY season_id
        """
    )
    if invalid_season_names:
        raise AssertionError(f"Invalid season names: {invalid_season_names!r}")

    return {
        "competition_count": len(competition_rows),
        "competition_foreign_keys": sorted(foreign_keys),
        "view_columns": view_column_names,
        "season_columns": season_columns,
    }


def verify_api() -> dict:
    from one_touch_loader.api.main import app
    from one_touch_loader.api.repos.fixtures_repo import get_fixture
    from one_touch_loader.core.db import fetch_all

    paths = app.openapi()["paths"]
    competition_path = "/v1/competitions/{competition_id}/standings"
    legacy_path = "/v1/leagues/{league_id}/standings"
    if competition_path not in paths:
        raise AssertionError(f"Missing API path: {competition_path}")
    if legacy_path in paths:
        raise AssertionError(f"Legacy API path remains: {legacy_path}")

    schemas = app.openapi()["components"]["schemas"]
    for schema_name in ("CurrentFormSeriesOut", "CurrentFormOptionOut"):
        properties = schemas[schema_name]["properties"]
        stale_properties = {
            "season_starting_at",
            "season_ending_at",
        }.intersection(properties)
        if stale_properties:
            raise AssertionError(
                f"{schema_name} still exposes season dates: "
                f"{sorted(stale_properties)!r}"
            )

    fixture_rows = fetch_all(
        "SELECT fixture_id FROM fixtures ORDER BY fixture_id LIMIT 1"
    )
    if not fixture_rows:
        raise AssertionError("No fixture is available for the repository smoke test")

    fixture = get_fixture(int(fixture_rows[0][0]))
    if fixture is None:
        raise AssertionError("Fixture repository returned no row")
    if "competition_id" not in fixture or "competition_type" not in fixture:
        raise AssertionError(f"Fixture response uses the wrong contract: {fixture!r}")
    if "league_id" in fixture:
        raise AssertionError(f"Fixture response still exposes league_id: {fixture!r}")

    return {
        "standings_path": competition_path,
        "fixture_id": int(fixture["fixture_id"]),
        "fixture_competition_id": int(fixture["competition_id"]),
        "fixture_competition_type": fixture["competition_type"],
    }


def main() -> None:
    result = {
        "compiled_python_files": verify_python_sources(),
        "imported_modules": verify_imports(),
        "database": verify_database(),
        "api": verify_api(),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
    print("Competitions and seasons backend verification passed.")


if __name__ == "__main__":
    main()
