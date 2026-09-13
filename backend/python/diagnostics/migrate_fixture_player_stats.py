"""명시적으로 --apply를 실행하면 기존 라인업 백업 후 선수 통계 구조를 추가해요."""
from __future__ import annotations

import argparse
from contextlib import closing
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_fixture_player_stats import verify_schema
from one_touch_loader.core.db import get_conn


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    with closing(get_conn()) as conn:
        with conn.cursor() as cur:
            cur.execute("""SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema=DATABASE() AND table_name='fixture_player_stats'""")
            exists = bool(cur.fetchone()[0])
    if exists:
        verify_schema(before=False)
        print("Player match statistics schema already ready.")
    elif args.apply:
        run_migration(
            name="fixture_player_stats", tables=("fixture_lineups",),
            sql_paths=(Path(__file__).resolve().parents[1]
                       / "one_touch_loader/sql/migrate_fixture_player_stats.sql",),
            verify_schema=verify_schema,
        )
    else:
        verify_schema(before=True)
        print("Pending: add match_position_id and fixture_player_stats. No database changes made.")


if __name__ == "__main__":
    main()
