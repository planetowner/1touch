"""공급자가 검증한 앱·사용자 ID만 회원 계정에 연결해요."""
from functools import lru_cache
import time
from fastapi import HTTPException
import jwt
import requests
from .auth_security import required_setting


@lru_cache(maxsize=3)
def _keys(url: str, timeout: int = 10):
    return jwt.PyJWKClient(url, timeout=timeout)


def _verify_token(token: str, keys_url: str, issuers, audiences, *, required_claims=("exp", "iat", "iss", "aud", "sub")) -> dict:
    try:
        key = _keys(keys_url).get_signing_key_from_jwt(token)
        return jwt.decode(token, key.key, algorithms=["RS256"], issuer=issuers, audience=audiences,
                          options={"require": list(required_claims)})
    except jwt.PyJWKClientConnectionError as exc:
        raise HTTPException(503, "Identity provider keys unavailable") from exc
    except (jwt.InvalidTokenError, jwt.PyJWKClientError) as exc:
        raise HTTPException(401, "Invalid provider token") from exc


def _provider_response(method: str, url: str, *, expected_status: int = 200, **kwargs):
    try:
        response = requests.request(method, url, timeout=15, **kwargs)
    except requests.RequestException as exc:
        raise HTTPException(503, "Identity provider unavailable") from exc
    if response.status_code >= 500:
        raise HTTPException(503, "Identity provider unavailable")
    if response.status_code != expected_status:
        raise HTTPException(401, "Provider rejected login credentials")
    return response


def _provider_json(method: str, url: str, **kwargs) -> dict:
    return _provider_response(method, url, **kwargs).json()


def google_subject(id_token: str) -> str:
    # Google 공식 백엔드 계약에 따라 HTTPS로 받은 ID 토큰의 서명·발급자·앱·만료를 검증해요.
    # 모바일 SDK의 serverClientId로 쓴 Web Client ID를 허용해요. 이 검증에는 Client secret이 필요 없어요.
    # 이메일이 같다는 이유로 기존 이메일 가입 계정과 합치지 않고 sub만 사용해요.
    audiences = [value.strip() for value in required_setting("GOOGLE_CLIENT_IDS").split(",")]
    claims = _verify_token(id_token, "https://www.googleapis.com/oauth2/v3/certs",
                              ["accounts.google.com", "https://accounts.google.com"], audiences)
    return claims["sub"]


def _apple_secret(client_id: str) -> str:
    if client_id not in [value.strip() for value in required_setting("APPLE_CLIENT_IDS").split(",")]:
        raise HTTPException(401, "Unregistered Apple client")
    now = int(time.time())
    return jwt.encode({"iss": required_setting("APPLE_TEAM_ID"), "iat": now, "exp": now + 300,
                         "aud": "https://appleid.apple.com", "sub": client_id},
                        required_setting("APPLE_PRIVATE_KEY").replace("\\n", "\n"), algorithm="ES256",
                        headers={"kid": required_setting("APPLE_KEY_ID")})


def _apple_identity(code: str, client_id: str, nonce: str) -> tuple[dict, dict]:
    secret = _apple_secret(client_id)
    data = {"grant_type": "authorization_code", "code": code, "client_id": client_id, "client_secret": secret}
    # Apple은 iOS 네이티브 로그인만 제공하므로 웹 복귀 주소를 넣지 않아요.
    payload = _provider_json("POST", "https://appleid.apple.com/auth/token", data=data)
    claims = _verify_token(payload["id_token"], "https://appleid.apple.com/auth/keys",
                              "https://appleid.apple.com", client_id)
    # 앱은 로그인 전에 nonce를 만들고 Apple에 전달한 바로 그 값을 보내요.
    # 일회용 authorization code를 Apple에서 교환해 같은 코드의 재사용을 막아요.
    if claims.get("nonce") != nonce:
        raise HTTPException(401, "Apple login nonce mismatch")
    return claims, payload


def apple_subject(code: str, client_id: str, nonce: str) -> str:
    claims, _ = _apple_identity(code, client_id, nonce)
    return claims["sub"]


def unlink_apple(subject: str, code: str, client_id: str, nonce: str) -> None:
    # Apple TN3194: 저장한 갱신 토큰이 없으므로 탈퇴 때 다시 인증받아 토큰을 교환해요.
    # 다른 Apple 계정의 인증값으로 연결을 해제하지 않도록 기존 sub와 먼저 대조해요.
    claims, payload = _apple_identity(code, client_id, nonce)
    if claims["sub"] != subject:
        raise HTTPException(403, "Authenticate the Apple account linked to this user")
    _provider_response("POST", "https://appleid.apple.com/auth/revoke", data={
        "client_id": client_id, "client_secret": _apple_secret(client_id),
        "token": payload["access_token"], "token_type_hint": "access_token",
    })
    # 성공 응답은 빈 HTTP 200이므로 JSON 본문을 요구하지 않아요.


def apple_account_event(token: str) -> tuple[str, str] | None:
    # Apple 계정 알림에는 exp와 최상위 sub가 없어요. 로그인과 같은 서명·앱 검증에 알림의 필수 항목을 전달해요.
    # https://developer.apple.com/documentation/signinwithapple/processing-changes-for-sign-in-with-apple-accounts
    claims = _verify_token(token, "https://appleid.apple.com/auth/keys", "https://appleid.apple.com",
        [value.strip() for value in required_setting("APPLE_CLIENT_IDS").split(",")],
        required_claims=("iss", "aud", "iat", "jti", "events"))
    event = claims["events"]
    if (not isinstance(event, dict) or not isinstance(event.get("sub"), str) or not event["sub"]
            or not claims["jti"] or event.get("type") not in (
                "consent-revoked", "account-deleted", "email-enabled", "email-disabled")):
        raise HTTPException(400, "Invalid Apple account event")
    # 소셜 이메일을 저장하거나 메일을 보내지 않으므로 전달 설정 변경으로 회원을 탈퇴시키지 않아요.
    if event["type"] in ("email-enabled", "email-disabled"):
        return None
    return event["sub"], claims["jti"]


def kakao_subject(access_token: str) -> str:
    info = _provider_json("GET", "https://kapi.kakao.com/v1/user/access_token_info",
                          headers={"Authorization": f"Bearer {access_token}"})
    if str(info["app_id"]) != required_setting("KAKAO_APP_ID") or info["expires_in"] <= 0:
        raise HTTPException(401, "Invalid Kakao app or expired token")
    # 토큰 정보가 인증된 사용자 ID를 제공하므로 표시 이름으로 다시 매칭하지 않아요.
    return str(info["id"])


def unlink_kakao(subject: str, access_token: str) -> None:
    if kakao_subject(access_token) != subject:
        raise HTTPException(403, "Authenticate the Kakao account linked to this user")
    _provider_json("POST", "https://kapi.kakao.com/v1/user/unlink",
                   headers={"Authorization": f"Bearer {access_token}"})


def line_subject(access_token: str) -> str:
    channel_id = required_setting("LINE_CHANNEL_ID")
    # 네이티브 SDK 토큰도 우리 채널용인지 먼저 확인해요. 클라이언트가 보낸 사용자 ID는 신뢰하지 않아요.
    # https://developers.line.biz/en/docs/line-login/secure-login-process/
    info = _provider_json("GET", "https://api.line.me/oauth2/v2.1/verify",
                          params={"access_token": access_token})
    if info["client_id"] != channel_id or info["expires_in"] <= 0:
        raise HTTPException(401, "Invalid LINE channel or expired token")
    # 앱은 openid 권한으로 로그인해요. 이름·이메일을 수집하지 않고 검증된 sub만 계정에 연결해요.
    claims = _provider_json("GET", "https://api.line.me/oauth2/v2.1/userinfo",
                            headers={"Authorization": f"Bearer {access_token}"})
    return claims["sub"]


def unlink_line(subject: str, access_token: str) -> None:
    channel_id = required_setting("LINE_CHANNEL_ID")
    channel_secret = required_setting("LINE_CHANNEL_SECRET")
    if line_subject(access_token) != subject:
        raise HTTPException(403, "Authenticate the LINE account linked to this user")
    # 탈퇴에는 토큰 폐기(revoke)만으로 부족해요. LINE 공식 deauthorize로 앱 동의를 해제해요.
    # https://developers.line.biz/en/reference/line-login/#deauthorize
    # 사용자 토큰은 저장하지 않고 탈퇴 요청에서 받아요. 채널 토큰은 이 요청에만 발급해 써요.
    channel = _provider_json("POST", "https://api.line.me/oauth2/v3/token", data={
        "grant_type": "client_credentials", "client_id": channel_id, "client_secret": channel_secret,
    })
    _provider_response("POST", "https://api.line.me/user/v1/deauthorize", expected_status=204,
        headers={"Authorization": f"Bearer {channel['access_token']}"}, json={"userAccessToken": access_token})
    # LINE 연결 해제 성공은 본문 없는 204예요. 다른 공급자의 200 응답 규칙은 유지해요.


def kakao_unlink_event(token: bytes) -> tuple[str, str]:
    # 로그인 ID 토큰과 달리 SET에는 exp가 없어요. typ·서명·발급자·수신 앱을 검증해요.
    # https://developers.kakao.com/docs/ko/kakaologin/callback#validate-set
    audience = required_setting("KAKAO_REST_API_KEY")
    app_id = required_setting("KAKAO_APP_ID")
    try:
        header = jwt.get_unverified_header(token)
        if header.get("typ") != "secevent+jwt" or header.get("alg") != "RS256" or not header.get("kid"):
            raise jwt.InvalidTokenError("Expected a signed security event token")
        # 모르는 kid는 PyJWT가 키를 두 번 조회해요. 카카오의 3초 응답을 위해 조회마다 1초만 기다려요.
        key = _keys("https://kauth.kakao.com/.well-known/jwks.json", timeout=1).get_signing_key_from_jwt(token)
        claims = jwt.decode(token, key.key, algorithms=["RS256"], issuer="https://kauth.kakao.com", audience=audience,
                            options={"require": ["iss", "aud", "iat", "sub", "app_id", "jti", "events"]})
    except jwt.PyJWKClientConnectionError as exc:
        # 키 조회 장애를 잘못된 서명으로 응답하면 공급자가 재전송하지 않을 수 있어요.
        raise HTTPException(503, "Kakao signing keys unavailable") from exc
    except jwt.InvalidIssuerError as exc:
        raise HTTPException(400, {"err": "invalid_issuer", "description": "Unexpected event issuer"}) from exc
    except jwt.InvalidAudienceError as exc:
        raise HTTPException(400, {"err": "invalid_audience", "description": "Unexpected event audience"}) from exc
    except (jwt.InvalidSignatureError, jwt.PyJWKClientError) as exc:
        raise HTTPException(400, {"err": "invalid_key", "description": "Invalid event signature or key"}) from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(400, {"err": "invalid_request", "description": "Invalid security event token"}) from exc
    if claims["app_id"] != app_id:
        raise HTTPException(400, {"err": "invalid_audience", "description": "Unexpected Kakao app"})
    events = claims["events"]
    schema = "https://schemas.openid.net/secevent/oauth/event-type/user-unlinked"
    if not isinstance(events, dict) or set(events) != {schema} or not isinstance(events[schema], dict):
        raise HTTPException(400, {"err": "invalid_request", "description": "Expected a User Unlinked event"})
    subject = events[schema].get("subject")
    if (not isinstance(subject, dict) or subject.get("subject_type") != "iss-sub"
            or subject.get("iss") != "https://kauth.kakao.com" or subject.get("sub") != claims["sub"]
            or not claims["sub"] or not claims["jti"]):
        raise HTTPException(400, {"err": "invalid_request", "description": "Invalid event subject or ID"})
    return claims["sub"], claims["jti"]
