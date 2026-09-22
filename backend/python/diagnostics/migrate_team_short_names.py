"""팀 이름 변경을 미리 확인하고, --apply를 직접 실행하면 백업 후 적용해요."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from one_touch_loader.core.db import fetch_all
from diagnostics.migrate_football_names import migrate_data as save_names


SEED_PATH = Path(__file__).with_name("team_short_names.json")
SQL_PATH = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_team_short_names.sql"


def short_names() -> dict[int, str]:
    rows = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    names = {row["team_id"]: row["short_name"] for row in rows}
    if len(names) != len(rows) or any(not isinstance(name, str) or not name.strip() or len(name) > 64 for name in names.values()):
        raise ValueError("Invalid or duplicate reviewed short names")
    return names


def verify_schema(*, before: bool) -> bool:
    columns = fetch_all("""SELECT column_type, is_nullable FROM information_schema.columns
        WHERE table_schema=DATABASE() AND table_name='teams' AND column_name='short_name'""")
    if not columns and before:
        return False
    if columns != [("varchar(64)", "YES")]:
        raise ValueError("Expected nullable teams.short_name VARCHAR(64)")
    return True


def migrate_data(conn):
    # 한국어 이름과 같은 저장 경로에서 기존 값 충돌·전체 행 불변성을 확인해요.
    save_names(conn, names={"teams": short_names()}, columns={"teams": ("team_id", "short_name")})


def preview():
    ready = verify_schema(before=True)
    names = short_names()
    teams = {row[0]: row for row in fetch_all("SELECT team_id, name, " + ("short_name" if ready else "NULL") + " FROM teams")}
    missing = names.keys() - teams.keys()
    if missing:
        raise ValueError(f"Missing reviewed team IDs: {sorted(missing)}")
    for row in json.loads(SEED_PATH.read_text(encoding="utf-8")):
        if "name" in row and teams[row["team_id"]][1] != row["name"]:
            raise ValueError(f"Reviewed team identity changed: {row['team_id']}")
    conflicts = [key for key, name in names.items() if teams[key][2] not in (None, name)]
    if conflicts:
        raise ValueError(f"Existing English short names differ: {conflicts}")
    return ready, {"reviewed": len(names), "updates": sum(teams[key][2] != name for key, name in names.items())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    ready, summary = preview()
    print(json.dumps({"schema_ready": ready, "teams": summary}, ensure_ascii=False), flush=True)
    if not args.apply or not summary["updates"]:
        return
    from diagnostics.run_minimal_migration import run_migration
    run_migration(name="team_short_names", tables=("teams",),
                  sql_paths=() if ready else (SQL_PATH,),
                  verify_schema=verify_schema, migrate_data=migrate_data)
    _, after = preview()
    if after["updates"]:
        raise ValueError("Saved English short names differ from reviewed names")
    print(json.dumps({"verified": after}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
