from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from ..core.db import get_conn, transaction  # re-export for repo modules


def fetch_all_dict(sql: str, params: Tuple | None = None) -> List[Dict[str, Any]]:
    conn = get_conn()
    try:
        with conn.cursor(dictionary=True) as cur:
            cur.execute(sql, params or ())
            return cur.fetchall()
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
