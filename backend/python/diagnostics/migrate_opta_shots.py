"""Opta의 최초 설치용이에요. 관계 분리 후 점검은 migrate_recent_relations --verify를 써요."""

from __future__ import annotations

import argparse
from pathlib import Path

from diagnostics.run_minimal_migration import run_migration
from one_touch_loader.core.db import fetch_all
from one_touch_loader.loaders.opta_shots_store import DATASETS


COLUMNS = {
    "fixture_opta_shotmaps": ["fixture_id", "external_fixture_id", "external_competition_id", "external_season_id",
                              "source_url", "home_count", "away_count", "collected_at"],
    "fixture_opta_shots": ["external_event_id", "fixture_id", "team_id", "player_id", "minute", "extra_minute",
                           "result", "start_x", "start_y", "end_x", "end_y"],
}


def verify_schema(*, before: bool, dataset: str = "shots") -> None:
    metadata_table, events_table, value_key, _ = DATASETS[dataset]
    tables = {metadata_table: COLUMNS["fixture_opta_shotmaps"],
              events_table: [value_key if c == "result" else c for c in COLUMNS["fixture_opta_shots"]]}
    for table, expected in tables.items():
        columns = [r[0] for r in fetch_all("""SELECT column_name FROM information_schema.columns
            WHERE table_schema=DATABASE() AND table_name=%s ORDER BY ordinal_position""", (table,))]
        if columns != ([] if before else expected):
            raise RuntimeError(f"Unexpected {table} schema. No further changes: {columns}")
    parents = fetch_all("""SELECT table_name,column_type FROM information_schema.columns
        WHERE table_schema=DATABASE() AND (table_name,column_name) IN
        (('fixtures','fixture_id'),('teams','team_id'),('players','player_id'))""")
    if len(parents) != 3 or any(r[1] != "bigint unsigned" for r in parents):
        raise RuntimeError("Parent fixture/team/player ID types differ.")
    print(f"PASS: Opta {dataset} schema {'preflight' if before else 'ready'}")


def main(*, dataset: str = "shots") -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    tables = DATASETS[dataset][:2]
    exists = fetch_all("""SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()
        AND table_name IN (%s,%s)""", tables)[0][0]
    if exists == 2:
        verify_schema(before=False, dataset=dataset)
    elif exists:
        raise RuntimeError("Partial Opta schema found. Inspect the preceding migration output before continuing.")
    elif args.apply:
        run_migration(name=f"opta_{dataset}", tables=("fixture_external_ids", "team_external_ids", "player_external_ids"),
                      sql_paths=(Path(__file__).resolve().parents[1] / f"one_touch_loader/sql/migrate_opta_{dataset}.sql",),
                      verify_schema=lambda *, before: verify_schema(before=before, dataset=dataset))
    else:
        verify_schema(before=True, dataset=dataset)
        print("Pending: create two Opta tables. No database changes made. Understat data is preserved.")


if __name__ == "__main__":
    main()
