"""Probability의 최초 설치용이에요. 관계 분리 후 점검은 migrate_recent_relations --verify를 써요."""

from __future__ import annotations

import argparse
from pathlib import Path

from one_touch_loader.core.db import get_conn


COLUMNS = {
    "clubelo_ratings": [("team_id", "bigint unsigned"), ("rating_date", "date"), ("elo", "double"),
                        ("segment_id", "int"), ("source_url", "varchar(255)"), ("source_sha256", "char(64)"),
                        ("fetched_at", "datetime(6)")],
    "probability_models": [("model_id", "char(64)"), ("payload", "json"), ("created_at", "timestamp(6)")],
    "probability_runs": [("run_id", "char(64)"), ("model_id", "char(64)"), ("season_id", "bigint unsigned"),
                         ("as_of", "datetime(6)"), ("payload", "json"), ("created_at", "timestamp(6)")],
}
PRIMARY_KEYS = {"clubelo_ratings": ["team_id", "rating_date"], "probability_models": ["model_id"],
                "probability_runs": ["run_id"]}
FOREIGN_KEYS = {("clubelo_ratings", "team_id", "teams", "team_id"),
                ("probability_runs", "model_id", "probability_models", "model_id"),
                ("probability_runs", "season_id", "seasons", "season_id")}


def verify_schema(*, before):
    connection = get_conn()
    existing = []
    try:
        with connection.cursor() as cursor:
            for table, columns in COLUMNS.items():
                cursor.execute("""SELECT column_name,column_type FROM information_schema.columns
                    WHERE table_schema=DATABASE() AND table_name=%s ORDER BY ordinal_position""", (table,))
                found = cursor.fetchall()
                if before and not found:
                    continue
                if found != columns:
                    raise ValueError(f"Unexpected Probability table columns: {table}")
                cursor.execute("""SELECT column_name FROM information_schema.statistics
                    WHERE table_schema=DATABASE() AND table_name=%s AND index_name='PRIMARY' ORDER BY seq_in_index""", (table,))
                if [row[0] for row in cursor.fetchall()] != PRIMARY_KEYS[table]:
                    raise ValueError(f"Unexpected Probability primary key: {table}")
                existing.append(table)
            cursor.execute("""SELECT table_name,column_name,referenced_table_name,referenced_column_name
                FROM information_schema.key_column_usage WHERE table_schema=DATABASE()
                AND table_name IN ('clubelo_ratings','probability_models','probability_runs')
                AND referenced_table_name IS NOT NULL""")
            if set(cursor.fetchall()) != {fk for fk in FOREIGN_KEYS if fk[0] in existing}:
                raise ValueError("Unexpected Probability foreign keys")
    finally:
        connection.close()
    print(f"Probability schema checked: before={before}, existing={existing}", flush=True)
    return existing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    existing = verify_schema(before=True)
    if not args.apply:
        return
    from diagnostics.run_minimal_migration import run_migration
    run_migration(name="probability", tables=("team_external_ids", *existing),
                  sql_paths=(Path(__file__).resolve().parents[1] / "one_touch_loader/sql/create_probability_tables.sql",),
                  verify_schema=verify_schema)


if __name__ == "__main__":
    main()
