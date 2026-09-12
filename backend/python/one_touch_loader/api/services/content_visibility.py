"""차단은 조회하는 회원에게만 적용하고 숨겨진 답글의 관계는 유지해요."""
from fastapi import HTTPException
from ..db import fetch_one_dict


def blocked_sql(author: str) -> str:
    # author는 아래 저장소가 지정한 SQL 컬럼이에요. 요청 문자열은 전달하지 않아요.
    return f"EXISTS(SELECT 1 FROM user_blocks b WHERE b.user_id=%s AND b.blocked_user_id={author})"


def is_blocked(viewer_id: int, author_id: int | None) -> bool:
    return fetch_one_dict("SELECT 1 FROM user_blocks WHERE user_id=%s AND blocked_user_id=%s",
                          (viewer_id, author_id)) is not None


def require_visible_author(viewer_id: int, author_id: int | None) -> None:
    if is_blocked(viewer_id, author_id):
        raise HTTPException(404, "Content not found")


def public_author(row: dict) -> dict:
    row["author_deleted"] = row["user_id"] is None
    row["avatar_url"] = f"/v1/users/{row['user_id']}/avatar" if row.pop("has_avatar", False) else None
    return row
