from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from ..core.db import get_conn


def fetch_all_dict(sql: str, params: Tuple | None = None) -> List[Dict[str, Any]]:
    conn = get_conn()
    try:
        with conn.cursor(dictionary=True) as cur:
            cur.execute(sql, params or ())
            rows = cur.fetchall()
            return list(rows or [])
    finally:
        conn.close()


def fetch_one_dict(sql: str, params: Tuple | None = None) -> Optional[Dict[str, Any]]:
    rows = fetch_all_dict(sql, params)
    return rows[0] if rows else None


def execute(sql: str, params: Tuple | None = None) -> int:
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
        conn.commit()
        return cur.rowcount
    finally:
        conn.close()


def executemany(sql: str, rows: List[Tuple]) -> int:
    if not rows:
        return 0
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.executemany(sql, rows)
        conn.commit()
        return len(rows)
    finally:
        conn.close()
