"""대진표 저장 테이블을 확인해요. --apply일 때 백업 후 생성해요."""
import argparse
from pathlib import Path

from one_touch_loader.core.db import get_conn


def verify_schema(*, before):
    conn = get_conn()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""SELECT column_name,column_type FROM information_schema.columns
                WHERE table_schema=DATABASE() AND table_name='tournament_brackets' ORDER BY ordinal_position""")
            columns = cursor.fetchall()
            if not columns and before:
                return []
            if columns != [('season_id', 'bigint unsigned'), ('input_sha256', 'char(64)'),
                           ('payload', 'json'), ('fetched_at', 'datetime(6)')]:
                raise ValueError('Unexpected tournament_brackets columns')
            cursor.execute("SHOW INDEX FROM tournament_brackets WHERE Key_name='PRIMARY'")
            if [r[4] for r in cursor.fetchall()] != ['season_id']:
                raise ValueError('Unexpected tournament_brackets primary key')
            cursor.execute("""SELECT column_name,referenced_table_name,referenced_column_name
                FROM information_schema.key_column_usage WHERE table_schema=DATABASE()
                AND table_name='tournament_brackets' AND referenced_table_name IS NOT NULL""")
            if cursor.fetchall() != [('season_id', 'seasons', 'season_id')]:
                raise ValueError('Unexpected tournament_brackets season relation')
    finally:
        conn.close()
    return ['tournament_brackets']


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(argv)
    existing = verify_schema(before=True)
    if args.apply:
        from diagnostics.run_minimal_migration import run_migration
        run_migration(name='tournament_brackets', tables=('seasons', *existing),
            sql_paths=(Path(__file__).parents[1] / 'one_touch_loader/sql/create_tournament_brackets.sql',),
            verify_schema=verify_schema)
    print(f'Tournament bracket schema checked. applied={args.apply}')


if __name__ == '__main__':
    main()
