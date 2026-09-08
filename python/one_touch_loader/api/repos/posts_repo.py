from __future__ import annotations

from typing import Any, Dict, List, Optional

from ..db import execute, fetch_all_dict, fetch_one_dict


def list_posts(category: Optional[str], sort: str, limit: int, offset: int) -> List[Dict[str, Any]]:
    clauses = []
    params: List[Any] = []

    if category:
        clauses.append("p.category=%s")
        params.append(category)

    where = ("WHERE " + " AND ".join(clauses)) if clauses else ""

    # 현재 posts에는 별도 인기 점수가 없어 공개된 세 정렬값 모두 작성일 역순이에요.
    order_by = "p.created_at DESC"

    return fetch_all_dict(
        f"""
        SELECT p.post_id, p.user_id, p.category, p.title, p.body, p.media_url,
      DATE_FORMAT(p.created_at,'%Y-%m-%d %H:%i:%S') AS created_at
        FROM posts p
        {where}
        ORDER BY {order_by}
        LIMIT %s OFFSET %s
        """,
        tuple(params + [limit, offset]),
    )


def create_post(user_id: int, category: str, title: str, body: str, media_url: str | None) -> int:
    execute(
        """
        INSERT INTO posts (user_id, category, title, body, media_url)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (user_id, category, title, body, media_url),
    )
    row = fetch_one_dict("SELECT LAST_INSERT_ID() AS id")
    return int(row["id"]) if row else 0


def report_post(user_id: int, post_id: int, reason: str) -> None:
    execute(
        """
        INSERT INTO post_reports (post_id, user_id, reason)
        VALUES (%s, %s, %s)
        """,
        (post_id, user_id, reason),
    )
