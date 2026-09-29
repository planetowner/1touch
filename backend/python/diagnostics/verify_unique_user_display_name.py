"""닉네임 고유 제약을 적용하기 전후의 스키마와 중복을 읽기 전용으로 확인해요."""
from contextlib import closing

from one_touch_loader.core.db import get_conn


def verify_schema(*, before: bool) -> None:
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            cur.execute("""SELECT column_type,collation_name FROM information_schema.columns
                WHERE table_schema=DATABASE() AND table_name='users' AND column_name='display_name'""")
            column = cur.fetchone()
            if column is None or column[0] != "varchar(100)":
                raise AssertionError("Expected users.display_name VARCHAR(100)")
            cur.execute("""SELECT non_unique,column_name FROM information_schema.statistics
                WHERE table_schema=DATABASE() AND table_name='users'
                AND index_name='unique_user_display_name' ORDER BY seq_in_index""")
            index = cur.fetchall()
            if before:
                if index:
                    raise AssertionError("Nickname uniqueness migration already applied")
                # 목표 collation에서 대소문자만 다른 이름도 중복으로 확인해요.
                cur.execute("""SELECT COUNT(*) FROM (
                    SELECT display_name COLLATE utf8mb4_0900_as_ci AS nickname
                    FROM users WHERE display_name IS NOT NULL
                    GROUP BY nickname HAVING COUNT(*) > 1
                ) duplicates""")
                if cur.fetchone()[0]:
                    raise AssertionError("Existing nicknames conflict under the target collation")
            elif column[1] != "utf8mb4_0900_as_ci" or index != [(0, "display_name")]:
                raise AssertionError("Nickname uniqueness migration is incomplete")
        conn.rollback()
