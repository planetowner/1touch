"""Best Eleven의 기존 빈 테이블과 적용 후 최소 스키마를 읽기 전용으로 확인해요."""
from __future__ import annotations

import argparse
import json
from contextlib import closing

from one_touch_loader.core.db import get_conn


COLUMNS = {
    "team_best_eleven_formations": ["team_id", "season_id", "formation", "matches_used"],
    "team_best_eleven": ["team_id", "season_id", "formation", "slot_key", "player_id", "starts"],
}
OLD_COLUMNS = {
    "team_best_eleven_formations": ["id", "team_id", "season_id", "formation", "matches_used",
                                     "total_valid_matches", "is_default", "updated_at"],
    "team_best_eleven": ["id", "team_id", "season_id", "formation", "slot_key", "slot_index",
                         "player_id", "player_name", "player_image", "position_name",
                         "detailed_position_name", "starts", "total_minutes", "updated_at"],
}
PRIMARY_KEYS = {table: columns[:(3 if table.endswith("formations") else 4)] for table, columns in COLUMNS.items()}
FOREIGN_KEYS = {
    "team_best_eleven_formations": {
        "fk_tbef_team_season": ("team_seasons", ("team_id", "season_id")),
    },
    "team_best_eleven": {
        "fk_tbe_formation": ("team_best_eleven_formations", ("team_id", "season_id", "formation")),
        "fk_tbe_player": ("players", ("player_id",)),
    },
}


def verify_schema(*, before: bool) -> dict:
    report = {}
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor(dictionary=True) as cursor:
            for table in COLUMNS:
                cursor.execute("""
                    SELECT COLUMN_NAME, COLUMN_TYPE FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s ORDER BY ORDINAL_POSITION
                """, (table,))
                columns = cursor.fetchall()
                expected = OLD_COLUMNS[table] if before else COLUMNS[table]
                if [row["COLUMN_NAME"] for row in columns] != expected:
                    raise AssertionError(f"Unexpected columns: {table}")
                cursor.execute(f"SELECT COUNT(*) AS n FROM {table}")
                count = cursor.fetchone()["n"]
                # 기존 결과는 0행으로 확인했어요. 그 뒤 데이터가 적재됐다면 이 빈 테이블용
                # 마이그레이션을 진행하지 않고 새 결과의 보존·재계산 범위를 먼저 확인해요.
                if before and count:
                    raise AssertionError(f"Expected the audited empty table: {table}, rows={count}")
                cursor.execute("""
                    SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE
                    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s AND CONSTRAINT_NAME='PRIMARY'
                    ORDER BY ORDINAL_POSITION
                """, (table,))
                primary = [row["COLUMN_NAME"] for row in cursor.fetchall()]
                if primary != (["id"] if before else PRIMARY_KEYS[table]):
                    raise AssertionError(f"Unexpected primary key: {table}, {primary}")
                if not before:
                    for column in columns:
                        if column["COLUMN_NAME"] in {"team_id", "season_id", "player_id", "starts", "matches_used"}:
                            if "unsigned" not in column["COLUMN_TYPE"]:
                                raise AssertionError(f"Expected unsigned type: {table}, {column}")
                    for name, (parent, keys) in FOREIGN_KEYS[table].items():
                        cursor.execute("""
                            SELECT COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
                            FROM information_schema.KEY_COLUMN_USAGE
                            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s AND CONSTRAINT_NAME=%s
                            ORDER BY ORDINAL_POSITION
                        """, (table, name))
                        actual = [(row["COLUMN_NAME"], row["REFERENCED_TABLE_NAME"], row["REFERENCED_COLUMN_NAME"])
                                  for row in cursor.fetchall()]
                        if actual != [(key, parent, key) for key in keys]:
                            raise AssertionError(f"Unexpected foreign key: {table}, {name}")
                        cursor.execute("""
                            SELECT DELETE_RULE, UPDATE_RULE FROM information_schema.REFERENTIAL_CONSTRAINTS
                            WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME=%s AND CONSTRAINT_NAME=%s
                        """, (table, name))
                        if cursor.fetchone() != {"DELETE_RULE": "RESTRICT", "UPDATE_RULE": "CASCADE"}:
                            raise AssertionError(f"Unexpected foreign key actions: {table}, {name}")
                    constraint = "chk_tbef_matches_positive" if table.endswith("formations") else "chk_tbe_starts"
                    cursor.execute("""
                        SELECT ENFORCED FROM information_schema.TABLE_CONSTRAINTS
                        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s AND CONSTRAINT_NAME=%s
                          AND CONSTRAINT_TYPE='CHECK'
                    """, (table, constraint))
                    if cursor.fetchone() != {"ENFORCED": "YES"}:
                        raise AssertionError(f"Missing enforced positive count: {table}")
                report[table] = {"columns": len(columns), "rows": count, "primary_key": primary}
            if not before:
                cursor.execute("""
                    SELECT COLUMN_NAME FROM information_schema.STATISTICS
                    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='team_best_eleven'
                      AND INDEX_NAME='uq_tbe_formation_player' AND NON_UNIQUE=0 ORDER BY SEQ_IN_INDEX
                """)
                if [row["COLUMN_NAME"] for row in cursor.fetchall()] != ["team_id", "season_id", "formation", "player_id"]:
                    raise AssertionError("Missing unique player constraint per formation")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--before", action="store_true")
    mode.add_argument("--after", action="store_true")
    args = parser.parse_args()
    verify_schema(before=args.before)
    print("Best Eleven schema verification passed.")
