from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from ..core.db import execute, get_conn, transaction  # 저장소 모듈에서 바로 쓸 수 있게 다시 내보내요.


def fetch_one_from_cursor(cur, sql, params=()):
    # 열린 트랜잭션의 커서를 써서 같은 연결에서 조회해요.
    cur.execute(sql, params)
    return cur.fetchone()


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
