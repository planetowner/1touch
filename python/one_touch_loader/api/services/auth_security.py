"""외부 서비스 설정과 회원 비밀번호·일회용 인증값을 관리해요."""
import hashlib
import hmac
import os
import secrets

from fastapi import HTTPException
from pwdlib import PasswordHash

PASSWORDS = PasswordHash.recommended()
CODE_LIFETIME_MINUTES = 10
CODE_ATTEMPTS = 5
SESSION_DAYS = 30


def required_setting(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        # 공급자 등록 전 상태를 임의 사용자나 테스트 토큰으로 대신하지 않아요.
        raise HTTPException(503, f"Service configuration missing: {name}")
    return value


def new_token() -> str:
    return secrets.token_urlsafe(32)


def token_hash(token: str) -> bytes:
    return hashlib.sha256(token.encode()).digest()


def code_hash(challenge: str, code: str) -> bytes:
    secret = required_setting("AUTH_CODE_SECRET")
    if len(secret) < 32:
        raise HTTPException(503, "AUTH_CODE_SECRET must have at least 32 characters")
    # 숫자 코드의 경우 단순 SHA256만 저장하면 DB 사본에서 100만 개를 대입할 수 있어요.
    return hmac.digest(secret.encode(), f"{challenge}:{code}".encode(), "sha256")
