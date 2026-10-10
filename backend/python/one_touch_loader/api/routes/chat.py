"""현재 배포의 Uvicorn 프로세스 하나에서 경기 채팅을 전달해요."""
import asyncio
from dataclasses import dataclass
import json
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, WebSocketException
from pydantic import BaseModel, ConfigDict, Field, ValidationError
from starlette.concurrency import run_in_threadpool
from ..deps import get_user_id
from ..repos import auth_repo, chat_repo, posts_repo
from .posts import ReportBody
from ..services.content_visibility import is_blocked
from ..services.chat_aliases import public_chat_message
from ..schemas.community_language import CommunityLanguage

router = APIRouter()
CHAT_STATE_CHECK_SECONDS = 15
ChatRoom = tuple[int, CommunityLanguage]


def _close_code(exc: HTTPException) -> int:
    return {401: 4401, 410: 4410}.get(exc.status_code, 4403)


class ChatAuth(BaseModel):
    model_config = ConfigDict(extra="forbid")
    token: str = Field(min_length=40, max_length=100)


class ChatText(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    text: str = Field(min_length=1, max_length=2000)


async def _receive_text_json(socket: WebSocket):
    frame = await socket.receive()
    if frame["type"] == "websocket.disconnect":
        raise WebSocketDisconnect(frame["code"])
    # 바이너리 프레임은 receive_json의 KeyError를 일으켜요. 텍스트 전용 규칙으로 거절해요.
    if frame.get("text") is None:
        raise WebSocketException(code=4400, reason="Use JSON text frames")
    return json.loads(frame["text"])


@dataclass(eq=False)
class Peer:
    socket: WebSocket
    token: str


def _authorized(token: str, fixture_id: int) -> dict:
    user = auth_repo.session_user(token)
    chat_repo.check_chat_user(user, fixture_id)
    return user


class ChatHub:
    def __init__(self):
        self.rooms: dict[ChatRoom, set[Peer]] = {}
        self.delivery_lock = asyncio.Lock()

    def remove(self, room: ChatRoom, peer):
        peers = self.rooms.get(room)
        if peers is not None:
            peers.discard(peer)
            if not peers:
                self.rooms.pop(room, None)

    async def publish(self, room: ChatRoom, sender: Peer, text: str):
        fixture_id, language = room
        # 프로세스 하나에서 저장 순서와 전달 순서를 맞춰요. 여러 worker 배포에는 사용할 수 없어요.
        async with self.delivery_lock:
            user = await run_in_threadpool(_authorized, sender.token, fixture_id)
            await run_in_threadpool(auth_repo.rate_limit, f"chat:{user['user_id']}", 60, 60)
            message = await run_in_threadpool(chat_repo.create_message, user["user_id"], fixture_id, text, language=language)
            # 같은 경기라도 선택한 언어가 같은 연결에만 전달해요.
            for peer in tuple(self.rooms.get(room, ())):
                try:
                    # 최초 연결 이후 팔로우 변경·로그아웃·만료도 매 전달 전에 반영해요.
                    recipient = await run_in_threadpool(_authorized, peer.token, fixture_id)
                    if await run_in_threadpool(is_blocked, recipient["user_id"], message["user_id"]):
                        continue
                    public_message = public_chat_message(message, recipient["user_id"])
                    await asyncio.wait_for(peer.socket.send_json({"type": "message", **public_message}), 5)
                except HTTPException as exc:
                    self.remove(room, peer)
                    await peer.socket.close(code=_close_code(exc))
                except (WebSocketDisconnect, OSError, asyncio.TimeoutError):
                    self.remove(room, peer)


@router.get("/fixtures/{fixture_id}/chat/messages")
def messages(fixture_id: int, language: CommunityLanguage, before_id: int | None = Query(default=None, gt=0),
             after_id: int | None = Query(default=None, ge=0), limit: int = Query(default=50, ge=1, le=100),
             user_id: int = Depends(get_user_id)):
    return {"items": chat_repo.history(user_id, fixture_id, before_id, after_id, limit, language=language)}


@router.post("/chat/messages/{message_id}/report")
def report_message(message_id: int, body: ReportBody, user_id: int = Depends(get_user_id)):
    posts_repo.report_content(user_id, "message", message_id, body.reason)
    return {"ok": True}


@router.websocket("/fixtures/{fixture_id}/chat")
async def chat(socket: WebSocket, fixture_id: int, language: CommunityLanguage):
    await socket.accept()
    peer = None
    hub = socket.app.state.chat_hub
    room = (fixture_id, language)
    try:
        # 토큰을 URL에 넣으면 프록시 접속 로그에 남아요. 첫 프레임에서만 인증값을 받아요.
        auth = ChatAuth.model_validate(await asyncio.wait_for(_receive_text_json(socket), 10))
        await run_in_threadpool(_authorized, auth.token, fixture_id)
        peer = Peer(socket, auth.token)
        hub.rooms.setdefault(room, set()).add(peer)
        await socket.send_json({"type": "ready", "fixture_id": fixture_id, "language": language})
        while True:
            try:
                payload = await asyncio.wait_for(_receive_text_json(socket), CHAT_STATE_CHECK_SECONDS)
            except asyncio.TimeoutError:
                # 메시지를 보내지 않고 읽기만 하는 연결도 경기 종료 후에는 닫아요.
                await run_in_threadpool(_authorized, peer.token, fixture_id)
                continue
            body = ChatText.model_validate(payload)
            await hub.publish(room, peer, body.text)
    except HTTPException as exc:
        # 전달 중인 소켓을 동시에 닫거나, 전달 과정에서 이미 닫은 소켓을 다시 닫지 않아요.
        async with hub.delivery_lock:
            if peer is None or peer in hub.rooms.get(room, ()):
                if peer is not None:
                    hub.remove(room, peer)
                await socket.close(code=_close_code(exc), reason=str(exc.detail)[:100])
    except (ValidationError, json.JSONDecodeError, asyncio.TimeoutError):
        await socket.close(code=4400, reason="Invalid chat message or authentication timeout")
    except WebSocketDisconnect:
        pass
    finally:
        if peer is not None:
            hub.remove(room, peer)
