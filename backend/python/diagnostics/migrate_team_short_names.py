"""팀 이름 변경을 미리 확인하고, --apply를 직접 실행하면 백업 후 적용해요."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from one_touch_loader.core.db import fetch_all


SEED_PATH = Path(__file__).with_name("team_short_names.json")
SQL_PATH = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_team_short_names.sql"


def short_names() -> dict[int, str]:
    rows = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    return {row["team_id"]: row["short_name"] for row in rows}


def verify_schema(*, before: bool) -> bool:
    columns = fetch_all("""SELECT column_type, is_nullable FROM information_schema.columns
        WHERE table_schema=DATABASE() AND table_name='teams' AND column_name='short_name'""")
    if not columns and before:
        return False
    if columns != [("varchar(64)", "YES")]:
        raise ValueError("Expected nullable teams.short_name VARCHAR(64)")
    if not before:
        saved = dict(fetch_all("SELECT team_id, short_name FROM teams WHERE short_name IS NOT NULL"))
        if any(saved.get(team_id) != name for team_id, name in short_names().items()):
            raise ValueError("Saved short names do not match the reviewed list")
    return True


def migrate_data(conn):
    # 공급자 이름이나 리그가 바뀌어도 검증한 팀 ID에만 적용해요.
    with conn.cursor() as cursor:
        cursor.executemany("UPDATE teams SET short_name=%s WHERE team_id=%s",
                           [(name, team_id) for team_id, name in short_names().items()])
    conn.commit()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    names = short_names()
    teams = dict(fetch_all("SELECT team_id, name FROM teams"))
    missing = names.keys() - teams.keys()
    if missing:
        raise ValueError(f"Missing reviewed team IDs: {sorted(missing)}")
    ready = verify_schema(before=True)
    for team_id, name in names.items():
        print(f"{team_id}: {teams[team_id]} -> {name}")
    print(f"Reviewed teams: {len(names)}; other teams keep their original names.")
    if not args.apply:
        print("Preview only. Run with --apply to back up teams and save the names.")
        return
    from diagnostics.run_minimal_migration import run_migration
    run_migration(name="team_short_names", tables=("teams",),
                  sql_paths=() if ready else (SQL_PATH,),
                  verify_schema=verify_schema, migrate_data=migrate_data)


if __name__ == "__main__":
    main()
