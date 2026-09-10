from fastapi import APIRouter, Depends, Query, Request
from ..deps import get_token, get_user_id
from ..repos import auth_repo
from ..schemas.users import (
    AppleLoginBody, EmailCodeBody, GoogleLoginBody, KakaoLoginBody,
    PasswordLoginBody, RegisterEmailBody, ResetPasswordBody,
)
from ..services import social_login

router = APIRouter()


def auth_request_limit(request: Request):
    # 프록시에서 신뢰한 연결 IP를 써요. X-Forwarded-For를 직접 신뢰하지 않아요.
    auth_repo.rate_limit(f"auth-ip:{request.client.host}", 20, 60)


@router.get("/auth/providers")
def providers(country_code: str = Query(min_length=2, max_length=2)):
    # 카카오 표시 여부는 국적을 추정하는 인증 규칙이 아니라 가입 화면 규칙이에요.
    return {"providers": (["kakao"] if country_code.upper() == "KR" else []) + ["apple", "google", "email"]}


@router.post("/auth/email/code", dependencies=[Depends(auth_request_limit)])
def email_code(body: EmailCodeBody):
    return auth_repo.request_email_code(str(body.email), body.purpose)


@router.post("/auth/email/register", dependencies=[Depends(auth_request_limit)], status_code=201)
def register_email(body: RegisterEmailBody):
    return auth_repo.register_email(body.challenge_id, body.code, body.password,
                                   body.model_dump(include={"username", "first_name", "last_name", "timezone"}))


@router.post("/auth/login", dependencies=[Depends(auth_request_limit)])
def password_login(body: PasswordLoginBody):
    return auth_repo.login_password(body.username, body.password)


@router.post("/auth/email/reset-password", dependencies=[Depends(auth_request_limit)])
def reset_password(body: ResetPasswordBody):
    auth_repo.reset_password(body.challenge_id, body.code, body.password)
    return {"ok": True}


@router.post("/auth/google", dependencies=[Depends(auth_request_limit)])
def google_login(body: GoogleLoginBody):
    return auth_repo.login_social("google", social_login.google_subject(body.id_token))


@router.post("/auth/apple", dependencies=[Depends(auth_request_limit)])
def apple_login(body: AppleLoginBody):
    return auth_repo.login_social("apple", social_login.apple_subject(body.code, body.client_id, body.nonce))


@router.post("/auth/kakao", dependencies=[Depends(auth_request_limit)])
def kakao_login(body: KakaoLoginBody):
    return auth_repo.login_social("kakao", social_login.kakao_subject(body.access_token))


@router.post("/auth/logout")
def logout(token: str = Depends(get_token), user_id: int = Depends(get_user_id)):
    auth_repo.logout(token)
    return {"ok": True}
