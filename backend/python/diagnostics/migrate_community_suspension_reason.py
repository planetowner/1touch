"""제재 사유 컬럼을 준비해요. DB 변경은 사용자가 --apply로 실행해요."""
import argparse
from pathlib import Path

from one_touch_loader.api.db import fetch_one_dict, transaction


SQL_PATH = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_community_suspension_reason.sql"


def migrate(*, apply: bool) -> bool:
    exists = fetch_one_dict("""SELECT 1 FROM information_schema.columns
        WHERE table_schema=DATABASE() AND table_name='users' AND column_name='suspension_reason'""") is not None
    if apply and not exists:
        with transaction() as conn, conn.cursor() as cur:
            cur.execute(SQL_PATH.read_text(encoding="utf-8"))
        return True
    return exists


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    exists = migrate(apply=args.apply)
    print(f"Community suspension reason column present: {exists}")


if __name__ == "__main__":
    main()
