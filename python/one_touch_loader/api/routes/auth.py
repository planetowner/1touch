from typing import Literal
from fastapi import APIRouter, Depends, Query, Request
from ..deps import get_token, get_user_id
from ..repos import auth_repo
from ..schemas.users import (
    AppleLoginBody, CodeBody, EmailCodeBody, EmailChangeRequestBody, EmailChangeConfirmBody, GoogleLoginBody, KakaoLoginBody,
    PasswordLoginBody, RegisterEmailBody, ResetPasswordBody,
)
from ..services import social_login

router = APIRouter()


def auth_request_limit(request: Request):
    # 프록시에서 신뢰한 연결 IP를 써요. X-Forwarded-For를 직접 신뢰하지 않아요.
    auth_repo.rate_limit(f"auth-ip:{request.client.host}", 20, 60)


@router.get("/auth/providers")
def providers(platform: Literal["ios", "android"], country_code: str = Query(min_length=2, max_length=2)):
    # 카카오 표시 여부는 국적을 추정하는 인증 규칙이 아니라 가입 화면 규칙이에요.
    # Apple 로그인은 iPhone에서만 제공해요. 기기 정보가 없으면 임의로 iOS를 선택하지 않아요.
    return {"providers": (["kakao"] if country_code.upper() == "KR" else [])
            + (["apple"] if platform == "ios" else []) + ["google", "email"]}


@router.post("/auth/email/code", dependencies=[Depends(auth_request_limit)])
def email_code(body: EmailCodeBody):
    return auth_repo.request_email_code(str(body.email), body.purpose)


@router.post("/auth/email/register", dependencies=[Depends(auth_request_limit)], status_code=201)
def register_email(body: RegisterEmailBody):
    return auth_repo.register_email(body.challenge_id, body.code, body.password,
                                   body.model_dump(include={"username", "first_name", "last_name"}))


@router.post("/auth/login", dependencies=[Depends(auth_request_limit)])
def password_login(body: PasswordLoginBody):
    return auth_repo.login_password(body.username, body.password)


@router.post("/auth/email/reset-password", dependencies=[Depends(auth_request_limit)])
def reset_password(body: ResetPasswordBody):
    auth_repo.reset_password(body.challenge_id, body.code, body.password)
    return {"ok": True}


@router.post("/auth/email/find-username", dependencies=[Depends(auth_request_limit)])
def find_username(body: CodeBody):
    return {"username": auth_repo.find_username(body.challenge_id, body.code)}


@router.post("/users/me/email/code", dependencies=[Depends(auth_request_limit)])
def email_change_code(body: EmailChangeRequestBody, user_id: int = Depends(get_user_id)):
    return auth_repo.request_email_change(user_id, str(body.email), body.password)


@router.put("/users/me/email", dependencies=[Depends(auth_request_limit)])
def change_email(body: EmailChangeConfirmBody, user_id: int = Depends(get_user_id)):
    auth_repo.change_email(user_id, body.password, body.current_email.model_dump(), body.new_email.model_dump())
    return {"ok": True}


@router.post("/auth/google", dependencies=[Depends(auth_request_limit)])
def google_login(body: GoogleLoginBody, find_username: bool = False):
    return _social_response("google", social_login.google_subject(body.id_token), find_username)


@router.post("/auth/apple", dependencies=[Depends(auth_request_limit)])
def apple_login(body: AppleLoginBody, find_username: bool = False):
    return _social_response("apple", social_login.apple_subject(body.code, body.client_id, body.nonce), find_username)


@router.post("/auth/kakao", dependencies=[Depends(auth_request_limit)])
def kakao_login(body: KakaoLoginBody, find_username: bool = False):
    return _social_response("kakao", social_login.kakao_subject(body.access_token), find_username)


def _social_response(provider: str, subject: str, find_username: bool) -> dict:
    # 공급자 인증은 같지만 찾기에서는 회원·세션을 생성하지 않고 유저네임만 반환해요.
    if find_username:
        return {"username": auth_repo.find_social_username(provider, subject)}
    return auth_repo.login_social(provider, subject)


@router.post("/auth/logout")
def logout(token: str = Depends(get_token), user_id: int = Depends(get_user_id)):
    auth_repo.logout(token)
    return {"ok": True}
