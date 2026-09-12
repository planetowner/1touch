"""Understat 변경 전후의 실제 DB 구조를 읽기 전용으로 확인해요."""
from __future__ import annotations

import argparse
import json
from contextlib import closing

from one_touch_loader.core.db import get_conn


OLD_TABLES = ("understat_league_map", "understat_season_map", "understat_team_map",
              "xg_standings", "xg_standings_calibration")
COLUMNS = {
    "fixture_external_ids": ["fixture_id", "provider", "external_fixture_id"],
    "fixture_expected_goals": ["fixture_id", "home_xg", "away_xg"],
    "fixture_player_expected_goals": ["fixture_id", "player_id", "xg"],
    "fixture_shots": ["shot_id", "fixture_id", "team_id", "player_id", "minute", "x", "y", "xg", "result"],
    "xg_standings": ["season_id", "team_id", "position", "matches_played", "xg", "xga", "xpts"],
    "xg_standings_calibration": ["season_id", "calibration_match_count", "target_draw_rate", "draw_band"],
}
PRIMARY_KEYS = {
    "fixture_external_ids": ["provider", "external_fixture_id"],
    "fixture_expected_goals": ["fixture_id"],
    "fixture_player_expected_goals": ["fixture_id", "player_id"],
    "fixture_shots": ["shot_id"], "xg_standings": ["season_id", "team_id"],
    "xg_standings_calibration": ["season_id"],
}
FOREIGN_KEYS = {
    "fixture_external_ids": {("fixture_id", "fixtures", "fixture_id")},
    "fixture_expected_goals": {("fixture_id", "fixtures", "fixture_id")},
    "fixture_player_expected_goals": {("fixture_id", "fixtures", "fixture_id"), ("player_id", "players", "player_id")},
    "fixture_shots": {("fixture_id", "fixtures", "fixture_id"), ("team_id", "teams", "team_id"),
                      ("player_id", "players", "player_id")},
    "xg_standings": {("season_id", "seasons", "season_id"), ("team_id", "teams", "team_id")},
    "xg_standings_calibration": {("season_id", "seasons", "season_id")},
}


def verify_schema(*, before: bool) -> dict:
    report = {}
    with closing(get_conn()) as connection:
        connection.start_transaction(readonly=True, consistent_snapshot=True)
        with connection.cursor() as cursor:
            if before:
                for table in OLD_TABLES:
                    cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    count = cursor.fetchone()[0]
                    expected = 5 if table == "understat_league_map" else 0
                    if count != expected:
                        raise AssertionError(f"Audited old table changed: {table}, rows={count}")
                    report[table] = count
                cursor.execute("SELECT sportmonks_league_id,understat_league_key FROM understat_league_map")
                if set(cursor.fetchall()) != {(8,"ENG-Premier League"),(82,"GER-Bundesliga"),
                        (301,"FRA-Ligue 1"),(384,"ITA-Serie A"),(564,"ESP-La Liga")}:
                    raise AssertionError("Audited league mapping changed")
                new_tables = tuple(COLUMNS)[:4]
                cursor.execute(f"""SELECT table_name FROM information_schema.tables
                    WHERE table_schema=DATABASE() AND table_name IN ({','.join('%s' for _ in new_tables)})
                """, new_tables)
                if cursor.fetchall():
                    raise AssertionError("Understat migration already started; inspect schema before retrying")
                # 삭제 대상의 다른 FK가 생겼으면 백업 전에 확인해요.
                cursor.execute(f"""SELECT table_name,referenced_table_name FROM information_schema.key_column_usage
                    WHERE referenced_table_schema=DATABASE()
                      AND referenced_table_name IN ({','.join('%s' for _ in OLD_TABLES)})
                """, OLD_TABLES)
                if cursor.fetchall():
                    raise AssertionError("Another table references old Understat tables")
            else:
                for table, expected in COLUMNS.items():
                    cursor.execute("""SELECT column_name FROM information_schema.columns
                        WHERE table_schema=DATABASE() AND table_name=%s ORDER BY ordinal_position
                    """, (table,))
                    if [r[0] for r in cursor.fetchall()] != expected:
                        raise AssertionError(f"Unexpected columns: {table}")
                    cursor.execute("""SELECT column_name FROM information_schema.statistics
                        WHERE table_schema=DATABASE() AND table_name=%s AND index_name='PRIMARY'
                        ORDER BY seq_in_index
                    """, (table,))
                    if [r[0] for r in cursor.fetchall()] != PRIMARY_KEYS[table]:
                        raise AssertionError(f"Unexpected primary key: {table}")
                    cursor.execute("""SELECT column_name,referenced_table_name,referenced_column_name
                        FROM information_schema.key_column_usage WHERE table_schema=DATABASE()
                        AND table_name=%s AND referenced_table_name IS NOT NULL
                    """, (table,))
                    if set(cursor.fetchall()) != FOREIGN_KEYS[table]:
                        raise AssertionError(f"Unexpected foreign keys: {table}")
                    cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    report[table] = cursor.fetchone()[0]
                cursor.execute("""SELECT GROUP_CONCAT(column_name ORDER BY seq_in_index)
                    FROM information_schema.statistics WHERE table_schema=DATABASE()
                    AND table_name='fixture_external_ids' AND non_unique=0 AND index_name<>'PRIMARY'
                    GROUP BY index_name""")
                if cursor.fetchall() != [("fixture_id,provider",)]:
                    raise AssertionError("Fixture provider mapping is not unique")
                cursor.execute("""SELECT table_name FROM information_schema.tables
                    WHERE table_schema=DATABASE() AND table_name IN
                    ('understat_league_map','understat_season_map','understat_team_map')""")
                if cursor.fetchall():
                    raise AssertionError("Old Understat mapping tables remain")
        connection.rollback()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


def verify_player_ids_schema(*, before: bool) -> dict:
    """원본 ID 별칭을 허용하는 변경 전후에도 세 컬럼·PK·선수 FK를 유지하는지 확인해요."""
    with closing(get_conn()) as connection:
        connection.start_transaction(readonly=True, consistent_snapshot=True)
        with connection.cursor() as cursor:
            cursor.execute("""SELECT column_name FROM information_schema.columns
                WHERE table_schema=DATABASE() AND table_name='player_external_ids'
                ORDER BY ordinal_position""")
            if [r[0] for r in cursor.fetchall()] != ["player_id", "provider", "external_player_id"]:
                raise AssertionError("Unexpected player_external_ids columns")
            cursor.execute("""SELECT index_name,non_unique,GROUP_CONCAT(column_name ORDER BY seq_in_index)
                FROM information_schema.statistics
                WHERE table_schema=DATABASE() AND table_name='player_external_ids'
                GROUP BY index_name,non_unique""")
            expected = {("PRIMARY", 0, "provider,external_player_id")}
            expected.add(("uq_player_external_provider", 0, "player_id,provider") if before else
                         ("idx_player_external_player_provider", 1, "player_id,provider"))
            if set(cursor.fetchall()) != expected:
                raise AssertionError("Unexpected player_external_ids indexes; inspect before retrying")
            cursor.execute("""SELECT column_name,referenced_table_name,referenced_column_name
                FROM information_schema.key_column_usage WHERE table_schema=DATABASE()
                AND table_name='player_external_ids' AND referenced_table_name IS NOT NULL""")
            if set(cursor.fetchall()) != {("player_id", "players", "player_id")}:
                raise AssertionError("Unexpected player_external_ids foreign key")
            cursor.execute("""SELECT provider,COUNT(*) FROM player_external_ids
                GROUP BY provider ORDER BY provider""")
            report = {"before": before, "provider_rows": dict(cursor.fetchall())}
        connection.rollback()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--before", action="store_true")
    group.add_argument("--after", action="store_true")
    parser.add_argument("--player-ids", action="store_true", help="선수 외부 ID의 별칭 허용 변경만 확인해요.")
    args = parser.parse_args()
    verify = verify_player_ids_schema if args.player_ids else verify_schema
    verify(before=args.before)
