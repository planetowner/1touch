"""베팅 테이블의 신규 생성을 확인해요. 운영 변경은 사용자가 --apply로 실행해요."""
import argparse
from pathlib import Path

from one_touch_loader.core.db import get_conn

TABLES = ('user_point_wallets', 'fixture_bets', 'user_point_entries')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("""SELECT table_name FROM information_schema.tables WHERE table_schema=DATABASE()
                AND table_name IN ('user_point_wallets','fixture_bets','user_point_entries')""")
            existing = {row[0] for row in cur.fetchall()}
            if not args.apply:
                print('Present: ' + ', '.join(sorted(existing)))
                print('Pending: ' + ', '.join(t for t in TABLES if t not in existing))
                return
            path = Path(__file__).resolve().parents[1] / 'one_touch_loader/sql/create_betting_tables.sql'
            for statement in path.read_text(encoding='utf-8').split(';'):
                if statement.strip():
                    cur.execute(statement)
            print('Betting tables ready. Existing user and fixture rows were not changed.')
    finally:
        conn.close()


if __name__ == '__main__':
    main()
