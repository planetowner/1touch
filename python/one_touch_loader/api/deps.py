from __future__ import annotations

from fastapi import Header, HTTPException


def get_user_id(x_user_id: str | None = Header(default=None)) -> int:
    """X-User-Id 헤더의 정수를 요청 사용자 ID로 읽어요."""
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Missing X-User-Id header")
    try:
        return int(x_user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid X-User-Id (must be int)")
