"""기존 콘텐츠를 한국어 공간에 배정해요. DB 변경은 사용자가 --apply로 한 번 실행해요."""
import argparse
from pathlib import Path


SQL_PATH = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_community_language.sql"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    sql = SQL_PATH.read_text(encoding="utf-8")
    if not args.apply:
        print(sql)
        return

    from one_touch_loader.api.db import transaction

    # MySQL DDL은 전체 롤백되지 않아요. 적용 중에는 이전 앱·서버의 쓰기를 멈춰야 해요.
    with transaction() as conn, conn.cursor() as cur:
        for statement in sql.split(";"):
            if statement.strip():
                cur.execute(statement)
    print("Community language migration completed; existing content belongs to ko.")


if __name__ == "__main__":
    main()
