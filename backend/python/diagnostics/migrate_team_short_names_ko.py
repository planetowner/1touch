"""네이버에서 확인한 5대 리그와 지정된 UEFA 팀의 한국어 짧은 이름을 저장해요."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from one_touch_loader.core.db import fetch_all
from diagnostics.migrate_football_names import migrate_data as save_names

SEED_PATH = Path(__file__).with_name("team_short_names.ko.json")
SQL_PATH = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_team_short_names_ko.sql"
COLUMNS = {"teams": ("team_id", "short_name_ko")}


def reviewed_rows():
    rows = json.loads(SEED_PATH.read_text(encoding="utf-8"))["teams"]
    if len(rows) != 135 or len({row["team_id"] for row in rows}) != 135:
        raise ValueError("Expected 135 distinct reviewed teams")
    for row in rows:
        name = row["short_name_ko"]
        if not isinstance(name, str) or not name.strip() or len(name) > 64:
            raise ValueError(f"Invalid short name: {row['team_id']}")
    return rows


def verify_schema(*, before):
    actual = fetch_all("SELECT column_type, is_nullable FROM information_schema.columns "
                       "WHERE table_schema=DATABASE() AND table_name='teams' AND column_name='short_name_ko'")
    if not actual and before:
        return False
    if actual != [("varchar(64)", "YES")]:
        raise ValueError("Unexpected teams.short_name_ko schema")
    return True


def preview():
    ready = verify_schema(before=True)
    rows = reviewed_rows()
    # 시즌이 바뀌거나 팀 연결이 달라지면 예전 순위표를 자동으로 적용하지 않아요.
    current = fetch_all("SELECT s.competition_id, s.season_id, s.name, t.team_id, t.name "
                        "FROM team_seasons ts JOIN seasons s ON s.season_id=ts.season_id "
                        "JOIN teams t ON t.team_id=ts.team_id "
                        "WHERE s.is_current=1 AND s.competition_id IN (2,5,8,82,301,384,564)")
    expected = [(row["competition_id"], row["season_id"], row["season"], row["team_id"], row["name"])
                for row in rows]
    # UEFA 예선의 다른 팀까지 늘리지 않고, 첨부 표에서 확인한 팀만 포함해요.
    domestic = lambda values: sorted(row for row in values if row[0] not in (2, 5))
    if domestic(current) != domestic(expected) or not set(expected).issubset(set(current)):
        raise ValueError("Current league membership or team identity differs from reviewed Naver mapping")
    saved = dict(fetch_all("SELECT team_id, " + ("short_name_ko" if ready else "NULL") + " FROM teams"))
    conflicts = [row["team_id"] for row in rows if saved[row["team_id"]] not in (None, row["short_name_ko"])]
    if conflicts:
        raise ValueError(f"Existing Korean short names differ: {conflicts}")
    return ready, {"reviewed": len(rows), "updates": sum(saved[row["team_id"]] != row["short_name_ko"] for row in rows)}


def migrate_data(conn):
    save_names(conn, names={"teams": {row["team_id"]: row["short_name_ko"] for row in reviewed_rows()}},
               columns=COLUMNS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    ready, summary = preview()
    print(json.dumps({"schema_ready": ready, "teams": summary}, ensure_ascii=False), flush=True)
    if not args.apply or not summary["updates"]:
        return
    from diagnostics.run_minimal_migration import run_migration
    run_migration(name="team_short_names_ko", tables=("teams",), sql_paths=() if ready else (SQL_PATH,),
                  verify_schema=verify_schema, migrate_data=migrate_data)
    _, after = preview()
    if after["updates"]:
        raise ValueError("Saved Korean short names differ from reviewed names")
    print(json.dumps({"verified": after}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
