"""카카오가 서명한 연결 해제 알림을 받아 기존 탈퇴 규칙을 적용해요."""
from fastapi import APIRouter, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from starlette.concurrency import run_in_threadpool

from ..repos import users_repo
from ..services import social_login

router = APIRouter()


def _process_event(token: bytes) -> None:
    subject, event_id = social_login.kakao_unlink_event(token)
    users_repo.delete_social_account("kakao", subject, event_id)


@router.post("/auth/kakao/events", status_code=202)
async def receive_event(request: Request):
    # 회원 Bearer 세션 대신 카카오 SET 서명으로 인증해요. 원문 토큰은 로그나 DB에 남기지 않아요.
    if request.headers.get("content-type", "").split(";", 1)[0].strip().lower() != "application/secevent+jwt":
        return JSONResponse({"err": "invalid_request", "description": "Expected application/secevent+jwt"}, status_code=400)
    try:
        await run_in_threadpool(_process_event, await request.body())
    except HTTPException as exc:
        if exc.status_code != 400:
            raise
        # Kakao의 SET 오류 본문에는 FastAPI 기본 detail 포장을 붙이지 않아요.
        return JSONResponse(exc.detail, status_code=400)
    # DB 커밋 실패는 성공으로 응답하지 않아요. 카카오가 재전송할 때 다시 처리해요.
    return Response(status_code=202)
