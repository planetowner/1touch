"""--apply를 직접 실행한 경우에만 경기 시계 테이블을 만들어요."""
from __future__ import annotations

import argparse
from pathlib import Path

import mysql.connector
from dotenv import dotenv_values


COLUMNS = ["fixture_id", "period_type_id", "counts_from", "period_length", "minutes",
           "seconds", "ticking", "time_added", "sampled_at"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    backend = Path(__file__).resolve().parents[2]
    values = dotenv_values(backend / ".env")
    connection = mysql.connector.connect(
        host=values.get("DB_HOST", "localhost"), port=int(values.get("DB_PORT", "3306")),
        database=values.get("DB_NAME", "1touch"), user=values.get("DB_USER", "root"),
        password=values.get("DB_PASSWORD", ""), connection_timeout=8,
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute("""SELECT column_name FROM information_schema.columns
                WHERE table_schema=DATABASE() AND table_name='fixture_clock' ORDER BY ordinal_position""")
            columns = [row[0] for row in cursor.fetchall()]
            if columns and columns != COLUMNS:
                raise RuntimeError("fixture_clock schema differs. No changes made.")
            if not columns:
                if not args.apply:
                    print("Pending: create fixture_clock. Existing fixture data will be preserved.")
                    return
                sql = (backend / "python/one_touch_loader/sql/migrate_fixture_clock.sql").read_text(encoding="utf-8")
                cursor.execute(sql)
            cursor.execute("SELECT COUNT(*) FROM fixture_clock")
            print(f"fixture_clock schema ready: rows={cursor.fetchone()[0]}. Existing match data preserved.")
    finally:
        connection.close()


if __name__ == "__main__":
    main()
