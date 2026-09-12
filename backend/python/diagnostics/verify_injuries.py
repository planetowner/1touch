"""부상 마이그레이션 전후의 컬럼·키·관계를 읽기 전용으로 확인해요."""
from __future__ import annotations

import argparse
import json
from contextlib import closing

from one_touch_loader.core.db import get_conn


OLD_COLUMNS = [
    "sideline_id", "team_id", "player_id", "type_id", "category", "type_name",
    "player_name", "start_date", "end_date", "games_missed", "completed",
    "is_active", "last_seen_at", "created_at", "updated_at",
]
COLUMNS = {
    "injury_types": [("type_id", "bigint unsigned", "NO"), ("name", "varchar(255)", "NO")],
    "team_player_injuries": [
        ("sideline_id", "bigint unsigned", "NO"), ("team_id", "bigint unsigned", "NO"),
        ("player_id", "bigint unsigned", "NO"), ("type_id", "bigint unsigned", "NO"),
        ("start_date", "date", "YES"), ("end_date", "date", "YES"),
    ],
}
FOREIGN_KEYS = {
    ("team_id", "teams", "team_id"), ("player_id", "players", "player_id"),
    ("type_id", "injury_types", "type_id"),
}


def verify_schema(*, before: bool) -> dict:
    report = {}
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cursor:
            for table, expected in COLUMNS.items():
                cursor.execute("""
                    SELECT column_name, column_type, is_nullable
                    FROM information_schema.columns
                    WHERE table_schema=DATABASE() AND table_name=%s ORDER BY ordinal_position
                """, (table,))
                columns = cursor.fetchall()
                if before and table == "injury_types":
                    if columns:
                        raise AssertionError("injury_types already exists; inspect migration state first")
                    continue
                if before:
                    if [row[0] for row in columns] != OLD_COLUMNS:
                        raise AssertionError(f"Unexpected old injury columns: {columns}")
                elif columns != expected:
                    raise AssertionError(f"Unexpected columns: {table}, {columns}")
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                # 확인한 0행 구조에서만 이전 컬럼을 없애요. 새 데이터가 있으면 재검토해요.
                if before and count:
                    raise AssertionError(f"Expected audited empty table: {table}, rows={count}")
                cursor.execute("""
                    SELECT column_name FROM information_schema.statistics
                    WHERE table_schema=DATABASE() AND table_name=%s AND index_name='PRIMARY'
                    ORDER BY seq_in_index
                """, (table,))
                if cursor.fetchall() != [(expected[0][0],)]:
                    raise AssertionError(f"Unexpected primary key: {table}")
                report[table] = {"columns": len(columns), "rows": count}

            cursor.execute("""
                SELECT column_name, referenced_table_name, referenced_column_name
                FROM information_schema.key_column_usage
                WHERE table_schema=DATABASE() AND table_name='team_player_injuries'
                  AND referenced_table_name IS NOT NULL
            """)
            if set(cursor.fetchall()) != (set() if before else FOREIGN_KEYS):
                raise AssertionError("Unexpected injury foreign keys")
            if before:
                cursor.execute("""
                    SELECT table_name FROM information_schema.key_column_usage
                    WHERE referenced_table_schema=DATABASE() AND referenced_table_name='team_player_injuries'
                """)
                if cursor.fetchall():
                    raise AssertionError("Another table now references injuries; inspect before migrating")
                for table, column in (("teams", "team_id"), ("players", "player_id")):
                    cursor.execute("""
                        SELECT column_type FROM information_schema.columns
                        WHERE table_schema=DATABASE() AND table_name=%s AND column_name=%s
                    """, (table, column))
                    if cursor.fetchone() != ("bigint unsigned",):
                        raise AssertionError(f"Unexpected parent ID type: {table}.{column}")
            else:
                cursor.execute("""
                    SELECT delete_rule, update_rule FROM information_schema.referential_constraints
                    WHERE constraint_schema=DATABASE() AND table_name='team_player_injuries'
                """)
                if cursor.fetchall() != [("RESTRICT", "CASCADE")] * 3:
                    raise AssertionError("Unexpected injury foreign key actions")
                for column, parent, key in FOREIGN_KEYS:
                    cursor.execute(f"""
                        SELECT COUNT(*) FROM team_player_injuries i
                        LEFT JOIN {parent} p ON p.{key}=i.{column} WHERE p.{key} IS NULL
                    """)
                    if cursor.fetchone()[0]:
                        raise AssertionError(f"Orphan injury relationship: {column}")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--before", action="store_true")
    modes.add_argument("--after", action="store_true")
    args = parser.parse_args()
    verify_schema(before=args.before)
    print("Injuries schema verification passed.")
