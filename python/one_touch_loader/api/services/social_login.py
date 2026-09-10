"""공급자가 검증한 앱·사용자 ID만 회원 계정에 연결해요."""
from functools import lru_cache
import os
import time
from fastapi import HTTPException
import jwt
import requests
from .auth_security import required_setting


@lru_cache(maxsize=2)
def _keys(url: str):
    return jwt.PyJWKClient(url, timeout=10)


def _verify_id_token(token: str, keys_url: str, issuers, audiences) -> dict:
    try:
        key = _keys(keys_url).get_signing_key_from_jwt(token)
        return jwt.decode(token, key.key, algorithms=["RS256"], issuer=issuers, audience=audiences,
                          options={"require": ["exp", "iat", "iss", "aud", "sub"]})
    except jwt.PyJWKClientConnectionError as exc:
        raise HTTPException(503, "Identity provider keys unavailable") from exc
    except (jwt.InvalidTokenError, jwt.PyJWKClientError) as exc:
        raise HTTPException(401, "Invalid provider identity token") from exc


def _provider_json(method: str, url: str, **kwargs) -> dict:
    try:
        response = requests.request(method, url, timeout=15, **kwargs)
    except requests.RequestException as exc:
        raise HTTPException(503, "Identity provider unavailable") from exc
    if response.status_code >= 500:
        raise HTTPException(503, "Identity provider unavailable")
    if response.status_code != 200:
        raise HTTPException(401, "Provider rejected login credentials")
    return response.json()


def google_subject(id_token: str) -> str:
    # Google 공식 백엔드 계약에 따라 HTTPS로 받은 ID 토큰의 서명·발급자·앱·만료를 검증해요.
    # 이메일이 같다는 이유로 기존 이메일 가입 계정과 합치지 않고 sub만 사용해요.
    audiences = [value.strip() for value in required_setting("GOOGLE_CLIENT_IDS").split(",")]
    claims = _verify_id_token(id_token, "https://www.googleapis.com/oauth2/v3/certs",
                              ["accounts.google.com", "https://accounts.google.com"], audiences)
    return claims["sub"]


def apple_subject(code: str, client_id: str, nonce: str) -> str:
    if client_id not in [value.strip() for value in required_setting("APPLE_CLIENT_IDS").split(",")]:
        raise HTTPException(401, "Unregistered Apple client")
    now = int(time.time())
    secret = jwt.encode({"iss": required_setting("APPLE_TEAM_ID"), "iat": now, "exp": now + 300,
                         "aud": "https://appleid.apple.com", "sub": client_id},
                        required_setting("APPLE_PRIVATE_KEY").replace("\\n", "\n"), algorithm="ES256",
                        headers={"kid": required_setting("APPLE_KEY_ID")})
    data = {"grant_type": "authorization_code", "code": code, "client_id": client_id, "client_secret": secret}
    # 웹용 Service ID는 등록한 redirect_uri가 필요하고, iOS App ID 교환에는 넣지 않아요.
    if client_id == os.getenv("APPLE_WEB_CLIENT_ID"):
        data["redirect_uri"] = required_setting("APPLE_REDIRECT_URI")
    payload = _provider_json("POST", "https://appleid.apple.com/auth/token", data=data)
    claims = _verify_id_token(payload["id_token"], "https://appleid.apple.com/auth/keys",
                              "https://appleid.apple.com", client_id)
    # 앱은 로그인 전에 nonce를 만들고 Apple에 전달한 바로 그 값을 보내요.
    # 일회용 authorization code를 Apple에서 교환해 같은 코드의 재사용을 막아요.
    if claims.get("nonce") != nonce:
        raise HTTPException(401, "Apple login nonce mismatch")
    return claims["sub"]


def kakao_subject(access_token: str) -> str:
    info = _provider_json("GET", "https://kapi.kakao.com/v1/user/access_token_info",
                          headers={"Authorization": f"Bearer {access_token}"})
    if str(info["app_id"]) != required_setting("KAKAO_APP_ID") or info["expires_in"] <= 0:
        raise HTTPException(401, "Invalid Kakao app or expired token")
    # 토큰 정보가 인증된 사용자 ID를 제공하므로 표시 이름으로 다시 매칭하지 않아요.
    return str(info["id"])
