"""선수 경기 통계 변경 전후의 테이블·외래키를 읽기 전용으로 확인해요."""
from __future__ import annotations

import argparse
from contextlib import closing
import json

from one_touch_loader.core.db import get_conn


LINEUP_COLUMNS = ["fixture_id", "team_id", "player_id", "lineup_type_id", "formation_field",
                  "jersey_number", "minutes_played", "rating"]
STAT_COLUMNS = ["fixture_id", "team_id", "player_id", "stat_type_id", "stat_value"]


def verify_schema(*, before: bool, print_report: bool = True) -> dict:
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            cur.execute("""SELECT table_name,column_name,column_type,is_nullable
                FROM information_schema.columns WHERE table_schema=DATABASE()
                AND table_name IN ('fixture_lineups','fixture_player_stats')
                ORDER BY table_name,ordinal_position""")
            columns = cur.fetchall()
            lineups = [name for table, name, _, _ in columns if table == "fixture_lineups"]
            stats = [name for table, name, _, _ in columns if table == "fixture_player_stats"]
            expected_lineups = LINEUP_COLUMNS + ([] if before else ["match_position_id"])
            if lineups != expected_lineups or stats != ([] if before else STAT_COLUMNS):
                raise AssertionError(f"Unexpected schema: lineups={lineups}, stats={stats}")
            for table, name, column_type, nullable in columns:
                if name in {"fixture_id", "team_id", "player_id"}:
                    if (column_type, nullable) != ("bigint unsigned", "NO"):
                        raise AssertionError(f"Unexpected ID type: {table}.{name}")
                if name == "match_position_id" and (column_type, nullable) != ("int", "YES"):
                    raise AssertionError("Unexpected match_position_id type")
            if not before:
                expected_stats = list(zip(STAT_COLUMNS,
                    ["bigint unsigned", "bigint unsigned", "bigint unsigned", "int", "decimal(12,4)"],
                    ["NO"] * 5))
                if [(name, kind, nullable) for table, name, kind, nullable in columns
                        if table == "fixture_player_stats"] != expected_stats:
                    raise AssertionError("Unexpected player statistics column types")
                cur.execute("""SELECT column_name FROM information_schema.key_column_usage
                    WHERE table_schema=DATABASE() AND table_name='fixture_player_stats'
                    AND constraint_name='PRIMARY' ORDER BY ordinal_position""")
                if [row[0] for row in cur.fetchall()] != STAT_COLUMNS[:4]:
                    raise AssertionError("Unexpected player statistics primary key")
                cur.execute("""SELECT column_name,referenced_table_name,referenced_column_name
                    FROM information_schema.key_column_usage WHERE table_schema=DATABASE()
                    AND table_name='fixture_player_stats' AND referenced_table_name IS NOT NULL
                    ORDER BY ordinal_position""")
                if cur.fetchall() != [(name, "fixture_lineups", name) for name in STAT_COLUMNS[:3]]:
                    raise AssertionError("Unexpected player statistics lineup relationship")
                cur.execute("""SELECT delete_rule,update_rule FROM information_schema.referential_constraints
                    WHERE constraint_schema=DATABASE() AND table_name='fixture_player_stats'""")
                if cur.fetchall() != [("CASCADE", "CASCADE")]:
                    raise AssertionError("Player statistics must follow lineup replacement")
            cur.execute("SELECT COUNT(*) FROM fixture_lineups")
            lineup_count = cur.fetchone()[0]
            stat_count = 0
            if not before:
                cur.execute("SELECT COUNT(*) FROM fixture_player_stats")
                stat_count = cur.fetchone()[0]
        conn.rollback()
    report = {"before": before, "lineups": lineup_count, "player_stats": stat_count}
    if print_report:
        print(json.dumps(report))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--before", action="store_true")
    mode.add_argument("--after", action="store_true")
    verify_schema(before=parser.parse_args().before)
    print("Player match statistics schema verification passed.")
