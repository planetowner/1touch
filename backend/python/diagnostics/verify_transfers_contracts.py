"""이적·계약 교체 전후의 빈 원본, 최소 컬럼, PK와 FK를 읽기 전용으로 확인해요."""
from __future__ import annotations

import argparse
import json
from contextlib import closing

from one_touch_loader.core.db import get_conn

OLD = {
    "team_transfers": "transfer_id player_id player_name player_image from_team_id from_team_name to_team_id to_team_name type_id type_name amount transfer_date window_id".split(),
    "transfer_windows": "id season_year window_name start_date end_date effective_start_date effective_end_date latest_detection_source is_active is_latest created_at updated_at".split(),
}
COLUMNS = {
    "transfers": "transfer_id player_id from_team_id to_team_id type_id amount transfer_date".split(),
    "transfer_types": ["type_id", "name"],
    "transfer_windows": ["season_id", "window_name", "start_date", "end_date"],
    "player_contracts": ["team_id", "player_id", "start_date", "end_date", "transfer_id"],
}
PRIMARY = {
    "transfers": ["transfer_id"], "transfer_types": ["type_id"],
    "transfer_windows": ["season_id", "window_name"], "player_contracts": ["team_id", "player_id"],
}
FOREIGN_KEYS = {
    ("transfers", "player_id", "players", "player_id"),
    ("transfers", "from_team_id", "teams", "team_id"),
    ("transfers", "to_team_id", "teams", "team_id"),
    ("transfers", "type_id", "transfer_types", "type_id"),
    ("transfer_windows", "season_id", "seasons", "season_id"),
    ("player_contracts", "team_id", "teams", "team_id"),
    ("player_contracts", "player_id", "players", "player_id"),
    ("player_contracts", "transfer_id", "transfers", "transfer_id"),
}


def verify_schema(*, before: bool) -> dict:
    report = {"before": before, "tables": {}}
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cursor:
            for table in OLD.keys() | COLUMNS.keys():
                cursor.execute("""SELECT column_name FROM information_schema.columns
                    WHERE table_schema=DATABASE() AND table_name=%s ORDER BY ordinal_position""", (table,))
                actual = [row[0] for row in cursor.fetchall()]
                expected = (OLD if before else COLUMNS).get(table, [])
                if actual != expected:
                    raise AssertionError(f"Unexpected columns: {table}: {actual}")
                if not expected:
                    continue
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                # 확인한 0행 원본만 교체해요. 새 이적 데이터가 생겼다면 먼저 보존 방법을 검토해요.
                if before and count:
                    raise AssertionError(f"Expected audited empty table: {table}, rows={count}")
                report["tables"][table] = count
                if not before:
                    cursor.execute("""SELECT column_name FROM information_schema.statistics
                        WHERE table_schema=DATABASE() AND table_name=%s AND index_name='PRIMARY' ORDER BY seq_in_index""", (table,))
                    if [row[0] for row in cursor.fetchall()] != PRIMARY[table]:
                        raise AssertionError(f"Unexpected primary key: {table}")
            cursor.execute("""SELECT table_name, column_name, referenced_table_name, referenced_column_name
                FROM information_schema.key_column_usage WHERE table_schema=DATABASE()
                AND (table_name IN ('team_transfers','transfers','transfer_types','transfer_windows','player_contracts')
                     OR referenced_table_name IN ('team_transfers','transfers','transfer_types','transfer_windows','player_contracts'))
                AND referenced_table_name IS NOT NULL""")
            if set(cursor.fetchall()) != (set() if before else FOREIGN_KEYS):
                raise AssertionError("Unexpected transfer/contract foreign keys")
            for table, column in (("teams", "team_id"), ("players", "player_id"), ("seasons", "season_id")):
                cursor.execute("""SELECT column_type FROM information_schema.columns
                    WHERE table_schema=DATABASE() AND table_name=%s AND column_name=%s""", (table, column))
                if cursor.fetchone() != ("bigint unsigned",):
                    raise AssertionError(f"Unexpected parent ID type: {table}.{column}")
            if not before:
                for table, column, parent, key in FOREIGN_KEYS:
                    cursor.execute(f"SELECT COUNT(*) FROM {table} c LEFT JOIN {parent} p ON p.{key}=c.{column} WHERE c.{column} IS NOT NULL AND p.{key} IS NULL")
                    if cursor.fetchone()[0]:
                        raise AssertionError(f"Orphan relationship: {table}.{column}")
                cursor.execute("""SELECT COUNT(*) FROM player_contracts c JOIN transfers tr ON tr.transfer_id=c.transfer_id
                    WHERE c.player_id<>tr.player_id OR c.team_id<>tr.to_team_id OR tr.to_team_id IS NULL""")
                if cursor.fetchone()[0]:
                    raise AssertionError("Contract transfer belongs to another player/team")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--before", action="store_true")
    modes.add_argument("--after", action="store_true")
    args = parser.parse_args()
    verify_schema(before=args.before)
    print("Transfers/contracts schema verification passed.")
