"""회원 팔로우 테이블을 준비해요. DB 변경은 사용자가 --apply로 실행해요."""
import argparse
from pathlib import Path
from one_touch_loader.api.db import fetch_one_dict, transaction

SQL_PATH = Path(__file__).resolve().parents[1] / 'one_touch_loader/sql/migrate_community_user_follows.sql'

def migrate(*, apply: bool) -> bool:
    exists = fetch_one_dict("""SELECT 1 FROM information_schema.tables
        WHERE table_schema=DATABASE() AND table_name='user_following_users'""") is not None
    if apply and not exists:
        with transaction() as conn, conn.cursor() as cur:
            cur.execute(SQL_PATH.read_text(encoding='utf-8'))
        return True
    return exists

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    print(f"Community user follows table present: {migrate(apply=parser.parse_args().apply)}")
