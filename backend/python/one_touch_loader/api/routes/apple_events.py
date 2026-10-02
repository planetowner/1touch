"""Apple 연결을 해제하고 다른 로그인 수단이 없을 때만 회원을 삭제해요."""
from fastapi import APIRouter, Response
from pydantic import BaseModel, Field

from ..repos import users_repo
from ..services import social_login

router = APIRouter()


class AppleEventBody(BaseModel):
    payload: str = Field(min_length=1)


@router.post("/auth/apple/events", status_code=200)
def receive_event(body: AppleEventBody):
    # 카카오의 SET 원문과 달리 Apple은 JSON의 payload로 JWT를 보내므로 요청 해석만 분리해요.
    # 회원 세션 대신 Apple 서명을 확인하고, 서명된 원문은 로그나 DB에 남기지 않아요.
    event = social_login.apple_account_event(body.payload)
    if event is not None:
        users_repo.delete_social_account("apple", *event)
    # DB 실패를 수신 성공으로 표시하지 않아요. 계정 보존·탈퇴와 중복 수신 처리는 카카오와 공유해요.
    return Response(status_code=200)
