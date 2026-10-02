"""기본 실행은 스키마 조회예요. DB 백업 후 --apply로 적립 스키마를 적용해요."""
import argparse
from pathlib import Path

from one_touch_loader.core.db import get_conn


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute('''SELECT table_name,column_name FROM information_schema.columns
                WHERE table_schema=DATABASE() AND table_name IN ('user_point_wallets','user_point_entries')''')
            columns = set(cur.fetchall())
            steps = (('user_point_wallets', 'country_code'), ('user_point_entries', 'post_id'))
            pending = [step for step in steps if step not in columns]
            print('Pending: ' + ', '.join('.'.join(step) for step in pending))
            if not args.apply:
                return
            path = Path(__file__).resolve().parents[1] / 'one_touch_loader/sql/migrate_community_points.sql'
            statements = [s for s in path.read_text(encoding='utf-8').split(';') if s.strip()]
            # MySQL의 ALTER는 따로 커밋돼요. 앞 단계만 끝났다면 남은 ALTER부터 적용해요.
            for step, statement in zip(steps, statements, strict=True):
                if step in pending:
                    cur.execute(statement)
            print('Community point schema ready. Existing balances and entries were preserved.')
    finally:
        conn.close()


if __name__ == '__main__':
    main()
