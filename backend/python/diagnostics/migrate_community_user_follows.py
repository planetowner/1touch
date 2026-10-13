"""회원 팔로우 테이블과 시간순 정렬을 준비해요. DB 변경은 사용자가 --apply로 실행해요."""
import argparse
from pathlib import Path
from one_touch_loader.api.db import fetch_one_dict, transaction

SQL_PATH = Path(__file__).resolve().parents[1] / 'one_touch_loader/sql/migrate_community_user_follows.sql'
ORDER_SQL_PATH = SQL_PATH.with_name('migrate_community_user_follow_order.sql')


def migrate(*, apply: bool) -> bool:
    # 신규 환경과 기존 환경이 같은 순서로 준비돼요. 컬럼과 두 인덱스는 하나의 ALTER로 추가해요.
    steps = (
        ("""SELECT 1 FROM information_schema.tables
            WHERE table_schema=DATABASE() AND table_name='user_following_users'""", SQL_PATH),
        ("""SELECT 1 FROM information_schema.columns WHERE table_schema=DATABASE()
            AND table_name='user_following_users' AND column_name='created_at'""", ORDER_SQL_PATH),
    )
    for query, path in steps:
        if fetch_one_dict(query) is not None:
            continue
        if not apply:
            return False
        with transaction() as conn, conn.cursor() as cur:
            cur.execute(path.read_text(encoding='utf-8'))
    return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    print(f"Community user follows schema ready: {migrate(apply=parser.parse_args().apply)}")
