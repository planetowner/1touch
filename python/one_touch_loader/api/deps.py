from __future__ import annotations

from fastapi import Header, HTTPException


def get_user_id(x_user_id: str | None = Header(default=None)) -> int:
    """
    MVP 단계 임시 인증:
    - 클라에서 X-User-Id 헤더로 정수 user_id를 보낸다고 가정
    - 추후 JWT/OAuth로 교체
    """
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Missing X-User-Id header")
    try:
        return int(x_user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid X-User-Id (must be int)")
