"""--apply를 직접 실행하면 기존 랭킹 3개 테이블을 백업하고 누적 비교 스키마로 전환해요."""
import argparse
from pathlib import Path
import re

from one_touch_loader.core.db import fetch_all


def verify_schema(*, before):
    columns = fetch_all("""SELECT column_name FROM information_schema.columns
        WHERE table_schema=DATABASE() AND table_name='player_rating_references'
          AND column_name IN ('frozen_at','updated_at')""")
    checks = fetch_all("""SELECT cc.check_clause
        FROM information_schema.check_constraints cc
        JOIN information_schema.table_constraints tc
          ON tc.constraint_schema=cc.constraint_schema AND tc.constraint_name=cc.constraint_name
        WHERE tc.table_schema=DATABASE() AND tc.table_name='player_rating_reference_samples'
          AND tc.constraint_name='chk_player_rating_reference_matches'""")
    clauses = [re.sub(r"[\s`()]+", "", row[0]).lower() for row in checks]
    if columns == [("updated_at",)] and clauses == ["rated_matches>=1"]:
        print("Cumulative player rating schema ready")
        return True
    if before and columns == [("frozen_at",)] and clauses == ["rated_matches>=10"]:
        print("Pending: reference timestamp rename and one-match reference eligibility")
        return False
    raise ValueError("Unexpected player rating schema; compare with migrate_player_rating_cumulative.sql")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if verify_schema(before=True) or not args.apply:
        return
    from diagnostics.run_minimal_migration import run_migration
    run_migration(
        name="player_rating_cumulative",
        tables=("player_rating_references", "player_rating_reference_samples", "player_rating_scores"),
        sql_paths=(Path(__file__).resolve().parents[1]
                   / "one_touch_loader/sql/migrate_player_rating_cumulative.sql",),
        verify_schema=verify_schema,
    )


if __name__ == "__main__":
    main()
