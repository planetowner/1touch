import os
from contextlib import contextmanager

from mysql.connector import pooling
from dotenv import load_dotenv

load_dotenv()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "1touch"),
    "charset": "utf8mb4",
    "collation": "utf8mb4_0900_ai_ci",
}

_pool = pooling.MySQLConnectionPool(pool_name="1touch_pool", pool_size=5, **DB_CONFIG)

def get_conn():
    return _pool.get_connection()


@contextmanager
def transaction():
    """DB 연결을 열고, 성공하면 커밋하고 예외가 나면 롤백해요.

    여러 문장이 함께 성공하거나 실패해야 할 때 써요. 예를 들면 DELETE + INSERT로
    캐시를 바꾸거나 여러 테이블의 순위를 다시 만들 때예요. 호출하는 쪽에서 반환된
    연결의 커서로 cur.execute 또는 cur.executemany를 실행해야 해요.
    """
    conn = get_conn()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def upsert_many(sql: str, rows: list[tuple]):
    if not rows:
        return
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.executemany(sql, rows)
        conn.commit()
    finally:
        conn.close()

def fetch_all(sql: str, params: tuple | None = None) -> list[tuple]:
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
            return cur.fetchall()
    finally:
        conn.close()

def execute(sql: str, params: tuple | None = None) -> int:
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
        conn.commit()
        return cur.rowcount
    finally:
        conn.close()
