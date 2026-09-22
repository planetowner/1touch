"""일별 선수 순위 테이블을 확인하고, --apply일 때만 백업 후 생성해요."""
import argparse
from pathlib import Path

from one_touch_loader.core.db import get_conn


SCHEMA = {
    'player_ranking_snapshots': {
        'columns': [('snapshot_id', 'bigint unsigned'), ('season_name', 'varchar(120)'),
                    ('snapshot_date', 'date'), ('observed_at', 'datetime(6)'), ('input_sha256', 'char(64)')],
        'primary': ['snapshot_id'],
        'relations': [],
    },
    'player_ranking_snapshot_rows': {
        'columns': [('snapshot_id', 'bigint unsigned'), ('season_id', 'bigint unsigned'),
                    ('competition_id', 'bigint unsigned'), ('player_id', 'bigint unsigned'),
                    ('rating_sum', 'decimal(10,2)'), ('rated_matches', 'smallint unsigned'), ('position', 'varchar(2)')],
        'primary': ['snapshot_id', 'season_id', 'player_id'],
        'relations': [('competition_id', 'competitions', 'competition_id'), ('player_id', 'players', 'player_id'),
                      ('season_id', 'seasons', 'season_id'), ('snapshot_id', 'player_ranking_snapshots', 'snapshot_id')],
    },
}


def verify_schema(*, before):
    existing = []
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            for table, expected in SCHEMA.items():
                cur.execute('''SELECT column_name,column_type FROM information_schema.columns
                    WHERE table_schema=DATABASE() AND table_name=%s ORDER BY ordinal_position''', (table,))
                columns = cur.fetchall()
                if not columns and before:
                    continue
                if columns != expected['columns']:
                    raise ValueError(f'Unexpected {table} columns')
                cur.execute(f"SHOW INDEX FROM {table} WHERE Key_name='PRIMARY'")
                if [r[4] for r in cur.fetchall()] != expected['primary']:
                    raise ValueError(f'Unexpected {table} primary key')
                cur.execute('''SELECT column_name,referenced_table_name,referenced_column_name
                    FROM information_schema.key_column_usage WHERE table_schema=DATABASE()
                    AND table_name=%s AND referenced_table_name IS NOT NULL ORDER BY column_name''', (table,))
                if cur.fetchall() != expected['relations']:
                    raise ValueError(f'Unexpected {table} relations')
                if table == 'player_ranking_snapshots':
                    cur.execute(f"SHOW INDEX FROM {table} WHERE Key_name='uq_player_ranking_day'")
                    if [(r[1], r[4]) for r in cur.fetchall()] != [(0, 'season_name'), (0, 'snapshot_date')]:
                        raise ValueError('Daily ranking uniqueness is required')
                existing.append(table)
    finally:
        conn.close()
    return existing


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(argv)
    existing = verify_schema(before=True)
    if args.apply:
        from diagnostics.run_minimal_migration import run_migration
        run_migration(name='player_ranking_history', tables=('seasons', *existing),
            sql_paths=(Path(__file__).parents[1] / 'one_touch_loader/sql/create_player_ranking_history.sql',),
            verify_schema=verify_schema)
    print(f'Player ranking history schema checked. applied={args.apply}')


if __name__ == '__main__':
    main()
