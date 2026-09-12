from __future__ import annotations

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from .repos.auth_repo import session_user

bearer = HTTPBearer(auto_error=False)


def get_token(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)) -> str:
    if credentials is None:
        raise HTTPException(401, "Bearer session required", headers={"WWW-Authenticate": "Bearer"})
    return credentials.credentials


def get_user_id(token: str = Depends(get_token)) -> int:
    # X-User-Id는 인증 근거로 사용하지 않아요. 작성자도 이 세션에서만 결정해요.
    return int(session_user(token)["user_id"])
