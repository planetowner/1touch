"""검증된 한국어 이름을 미리 확인하고 --apply로 백업 후 DB에 저장해요."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from one_touch_loader.core.db import fetch_all
from one_touch_loader.core.football_names import NAME_COLUMNS

SEED_PATH = Path(__file__).with_name("football_names.ko.json")
SQL_PATH = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_football_names.sql"


def reviewed_names():
    data = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    return {table: {int(key): value for key, value in data[table].items()} for table in NAME_COLUMNS}


def verify_schema(*, before):
    present = []
    for table, (_, column) in NAME_COLUMNS.items():
        actual = fetch_all("SELECT column_type, is_nullable FROM information_schema.columns "
                           "WHERE table_schema=DATABASE() AND table_name=%s AND column_name=%s", (table, column))
        if not actual and before:
            present.append(False)
            continue
        expected = "varchar(160)" if table == "teams" else "varchar(255)"
        if actual != [(expected, "YES")]:
            raise ValueError(f"Unexpected schema: {table}.{column}")
        present.append(True)
    if any(present) and not all(present):
        raise ValueError("Incomplete Korean-name schema; inspect before continuing")
    return all(present)


def preview():
    ready = verify_schema(before=True)
    result = {}
    for table, names in reviewed_names().items():
        identifier, column = NAME_COLUMNS[table]
        original = "name" if table == "teams" else "display_name"
        rows = fetch_all(f"SELECT {identifier}, {original}, " + (column if ready else "NULL") + f" FROM {table}")
        existing = {row[0]: row for row in rows}
        missing = names.keys() - existing.keys()
        if missing:
            raise ValueError(f"Missing {table} IDs: {sorted(missing)}")
        limit = 160 if table == "teams" else 255
        if any(not isinstance(name, str) or not name.strip() or len(name) > limit for name in names.values()):
            raise ValueError(f"Invalid reviewed {table} name")
        conflicts = [key for key, name in names.items() if existing[key][2] not in (None, name)]
        if conflicts:
            raise ValueError(f"Existing Korean names differ; review {table} IDs: {conflicts}")
        result[table] = {"reviewed": len(names), "updates": sum(existing[key][2] != name for key, name in names.items())}
    return ready, result


def migrate_data(conn, *, names=None, columns=NAME_COLUMNS, expected_before=None):
    names = reviewed_names() if names is None else names
    save_name_columns(
        conn,
        names={table: {columns[table][1]: values} for table, values in names.items()},
        identifiers={table: columns[table][0] for table in names},
        expected_before={table: {columns[table][1]: (expected_before or {}).get(table, {})} for table in names},
    )


def save_name_columns(conn, *, names, identifiers, expected_before=None):
    # 여러 언어도 같은 트랜잭션에서 저장해 한 언어만 반영된 채 끝나지 않게 해요.
    conn.start_transaction()
    try:
        with conn.cursor() as cursor:
            for table, localized_columns in names.items():
                identifier = identifiers[table]
                # 같은 연결의 잠금 안에서 기존 값과 저장 결과를 비교해요.
                cursor.execute(f"SELECT * FROM {table} ORDER BY {identifier} FOR UPDATE")
                row_columns = [item[0] for item in cursor.description]
                before = cursor.fetchall()
                id_index = row_columns.index(identifier)
                for column, values in localized_columns.items():
                    name_index = row_columns.index(column)
                    saved = {row[id_index]: row[name_index] for row in before}
                    # 기존 이름 교정은 사용자가 지정하고 DB에서 확인한 이전 값만 허용해요.
                    previous = (expected_before or {}).get(table, {}).get(column, {})
                    if values.keys() - saved.keys() or any(saved[key] not in (previous.get(key), name) for key, name in values.items()):
                        raise ValueError(f"Reviewed {table} rows changed after preview")
                    changed = [(key, value) for key, value in values.items() if saved[key] != value]
                    for offset in range(0, len(changed), 500):
                        batch = changed[offset:offset + 500]
                        cases = " ".join("WHEN %s THEN %s" for _ in batch)
                        ids = ",".join("%s" for _ in batch)
                        cursor.execute(f"UPDATE {table} SET {column}=CASE {identifier} {cases} ELSE {column} END "
                                       f"WHERE {identifier} IN ({ids})",
                                       tuple(value for row in batch for value in row) + tuple(row[0] for row in batch))
                cursor.execute(f"SELECT * FROM {table} ORDER BY {identifier}")
                after = cursor.fetchall()
                expected = [tuple(localized_columns.get(column, {}).get(row[id_index], value)
                                  for column, value in zip(row_columns, row)) for row in before]
                if after != expected:
                    raise ValueError(f"Unexpected {table} changes; rolling back")
        conn.commit()
    except Exception:
        conn.rollback()
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    ready, summary = preview()
    print(json.dumps({"schema_ready": ready, "tables": summary}, ensure_ascii=False), flush=True)
    if not args.apply or not any(item["updates"] for item in summary.values()):
        return
    from diagnostics.run_minimal_migration import run_migration
    run_migration(name="football_names", tables=tuple(NAME_COLUMNS), sql_paths=() if ready else (SQL_PATH,),
                  verify_schema=verify_schema, migrate_data=migrate_data)
    _, after = preview()
    if any(item["updates"] for item in after.values()):
        raise ValueError("Saved Korean names differ from reviewed names")
    print(json.dumps({"verified": after}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
