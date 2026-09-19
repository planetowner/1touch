"""뉴스 전용 테이블 3개만 추가해요. 기본 실행은 읽기 전용 점검이에요."""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    from one_touch_loader.core.db import fetch_all, transaction
    names = ("news_sources", "news_articles", "news_article_teams")
    if args.apply:
        path = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/create_news_tables.sql"
        with transaction() as conn, conn.cursor() as cur:
            for statement in path.read_text(encoding="utf-8").split(";"):
                if statement.strip():
                    cur.execute(statement)
    for name in names:
        columns = fetch_all("""SELECT column_name,column_type FROM information_schema.columns
            WHERE table_schema=DATABASE() AND table_name=%s ORDER BY ordinal_position""", (name,))
        print(name, columns if columns else "not installed")


if __name__ == "__main__":
    main()
