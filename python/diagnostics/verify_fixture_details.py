"""경기 상세 마이그레이션과 지정한 경기의 저장·조회 결과를 읽기 전용으로 확인해요."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from one_touch_loader.api.repos.fixtures_repo import get_fixture_detail
from one_touch_loader.core.db import fetch_all


SQL_PATH = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_fixture_details_minimal.sql"
COLLECTION_TABLES = {
    "events": "fixture_events",
    "statistics": "fixture_team_stats",
    "lineups": "fixture_lineups",
    "formations": "fixture_formations",
    "coaches": "fixture_coaches",
    "pressure": "fixture_pressures",
}


def verify_schema() -> dict:
    ddl = SQL_PATH.read_text(encoding="utf-8")
    tables = re.findall(r"CREATE TABLE (\w+) \((.*?)\) ENGINE", ddl, re.S)
    result = {}
    for table, definition in tables:
        expected_columns = []
        for name, kind, nullable in re.findall(
            r"^  (\w+) ((?:BIGINT|INT|SMALLINT)(?: UNSIGNED)?|BOOLEAN|VARCHAR\(\d+\)|DECIMAL\(\d+,\d+\)) (NOT NULL|NULL)",
            definition,
            re.M,
        ):
            mysql_type = "tinyint(1)" if kind == "BOOLEAN" else kind.lower()
            expected_columns.append((name, mysql_type, "NO" if nullable == "NOT NULL" else "YES"))
        actual_columns = fetch_all(
            """
            SELECT column_name, column_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = %s
            ORDER BY ordinal_position
            """,
            (table,),
        )
        if actual_columns != expected_columns:
            raise AssertionError(f"{table}: migration columns differ: {actual_columns!r}")

        expected_pk = re.search(r"PRIMARY KEY \(([^)]+)\)", definition).group(1).split(", ")
        actual_pk = fetch_all(
            """
            SELECT column_name FROM information_schema.statistics
            WHERE table_schema = DATABASE() AND table_name = %s AND index_name = 'PRIMARY'
            ORDER BY seq_in_index
            """,
            (table,),
        )
        if [row[0] for row in actual_pk] != expected_pk:
            raise AssertionError(f"{table}: unexpected primary key: {actual_pk!r}")

        expected_fks = re.findall(
            r"FOREIGN KEY \((\w+)\) REFERENCES (\w+) \((\w+)\)", definition,
        )
        actual_fks = fetch_all(
            """
            SELECT column_name, referenced_table_name, referenced_column_name
            FROM information_schema.key_column_usage
            WHERE constraint_schema = DATABASE() AND table_name = %s
              AND referenced_table_name IS NOT NULL
            """,
            (table,),
        )
        if set(actual_fks) != set(expected_fks):
            raise AssertionError(f"{table}: unexpected foreign keys: {actual_fks!r}")
        for column, parent, parent_column in expected_fks:
            orphan_count = fetch_all(
                f"SELECT COUNT(*) FROM {table} child LEFT JOIN {parent} parent "
                f"ON parent.{parent_column} = child.{column} "
                f"WHERE child.{column} IS NOT NULL AND parent.{parent_column} IS NULL"
            )[0][0]
            if orphan_count:
                raise AssertionError(f"{table}.{column}: orphan rows={orphan_count}")
        result[table] = fetch_all(f"SELECT COUNT(*) FROM {table}")[0][0]

    old_table = fetch_all(
        """
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = 'fixture_team_stats_raw'
        """
    )
    if old_table:
        raise AssertionError("fixture_team_stats_raw still exists")
    return result


def verify_fixture(fixture_id: int) -> dict:
    fixture = get_fixture_detail(fixture_id)
    if fixture is None:
        raise AssertionError(f"Fixture not found: {fixture_id}")
    counts = {}
    for collection, table in COLLECTION_TABLES.items():
        stored_count = fetch_all(
            f"SELECT COUNT(*) FROM {table} WHERE fixture_id = %s", (fixture_id,),
        )[0][0]
        if len(fixture[collection]) != stored_count:
            raise AssertionError(f"{fixture_id}: {collection} rows lost in API joins")
        counts[collection] = stored_count
    return {"state_id": fixture["state_id"], "counts": counts}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture-id", nargs="+", type=int, default=[])
    args = parser.parse_args()
    result = {"tables": verify_schema()}
    result["fixtures"] = {fixture_id: verify_fixture(fixture_id) for fixture_id in args.fixture_id}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print("Fixture details database verification passed.")


if __name__ == "__main__":
    main()
