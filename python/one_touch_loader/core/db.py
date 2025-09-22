import os
import mysql.connector
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