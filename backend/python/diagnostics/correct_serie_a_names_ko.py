"""사용자가 지정한 세리에 A 네 팀의 name_ko만 교정해요."""
from __future__ import annotations

import argparse
import json

from diagnostics.migrate_football_names import migrate_data as save_names, reviewed_names
from one_touch_loader.core.db import fetch_all

# 팀 ID·원래 영문·기존 한국어를 운영 DB와 대조했어요. 짧은 이름은 변경하지 않아요.
CORRECTIONS = {
    43: ("Lazio", "라티움", "SS 라치오"),
    708: ("Atalanta", "베르가모 칼초", "아탈란타 BC"),
    2930: ("Inter", "롬바르디아 FC", "인터 밀란"),
    113: ("AC Milan", "밀라노 FC", "AC 밀란"),
}


def verify_schema(*, before):
    actual = fetch_all("SELECT column_type, is_nullable FROM information_schema.columns "
                       "WHERE table_schema=DATABASE() AND table_name='teams' AND column_name='name_ko'")
    if actual != [("varchar(160)", "YES")]:
        raise ValueError("Expected existing nullable teams.name_ko VARCHAR(160)")
    return True


def preview():
    verify_schema(before=True)
    rows = fetch_all("SELECT team_id, name, name_ko FROM teams WHERE team_id IN (43,708,2930,113)")
    if {row[0] for row in rows} != set(CORRECTIONS):
        raise ValueError("Missing reviewed team IDs")
    targets = reviewed_names()["teams"]
    changes = []
    for identifier, original, current in rows:
        expected_original, previous, corrected = CORRECTIONS[identifier]
        if original != expected_original or current not in (previous, corrected) or targets[identifier] != corrected:
            raise ValueError(f"Reviewed name or team identity changed: {identifier}")
        changes.append({"team_id": identifier, "before": current, "after": corrected})
    return {"reviewed": 4, "updates": sum(row["before"] != row["after"] for row in changes), "changes": changes}


def migrate_data(conn):
    save_names(conn, names={"teams": {key: row[2] for key, row in CORRECTIONS.items()}},
               columns={"teams": ("team_id", "name_ko")},
               expected_before={"teams": {key: row[1] for key, row in CORRECTIONS.items()}})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    summary = preview()
    print(json.dumps(summary, ensure_ascii=False), flush=True)
    if not args.apply or not summary["updates"]:
        return
    from diagnostics.run_minimal_migration import run_migration
    run_migration(name="serie_a_names_ko", tables=("teams",), sql_paths=(),
                  verify_schema=verify_schema, migrate_data=migrate_data)
    after = preview()
    if after["updates"]:
        raise ValueError("Saved Korean names differ from user corrections")
    print(json.dumps({"verified": after}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
