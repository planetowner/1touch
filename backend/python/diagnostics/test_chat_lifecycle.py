"""경기 상태와 팔로우 변경을 조회·전송·대기 중인 연결에 반영하는지 검사해요."""
from threading import Event
import unittest
from unittest.mock import patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from diagnostics.test_chat_aliases import chat, chat_repo, stored_message
from one_touch_loader.core.fixture_states import LIVE_STATE_IDS, PAST_STATE_IDS, UPCOMING_STATE_IDS


class ChatLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.user = {"user_id": 928371, "username": "member", "display_name": "Member", "suspended_until": None, "favorite_team_id": 503}
        self.followed = [503, 6]
        self.fixtures = {42: {"home_team_id": 6, "away_team_id": 14, "state_id": 2},
                         43: {"home_team_id": 6, "away_team_id": 14, "state_id": 2}}
        for target, name, options in [
            (chat_repo, "fetch_one_dict", {"side_effect": lambda sql, params: self.fixtures.get(params[0])}),
            (chat_repo, "get_user", {"return_value": self.user}),
            (chat_repo, "list_following_team_ids", {"side_effect": lambda user_id, cur=None: self.followed}),
            (chat.auth_repo, "session_user", {"return_value": self.user}),
            (chat.auth_repo, "rate_limit", {}),
            (chat, "is_blocked", {"return_value": False}),
        ]:
            self.enterContext(patch.object(target, name, **options))
        self.fetch_messages = self.enterContext(patch.object(chat_repo, "fetch_all_dict", return_value=[]))
        self.create = self.enterContext(patch.object(chat_repo, "create_message", side_effect=
            lambda user_id, fixture_id, text, *, language: stored_message(user_id=user_id, fixture_id=fixture_id, text=text)))
        self.app = FastAPI()
        self.app.state.chat_hub = chat.ChatHub()
        self.app.include_router(chat.router, prefix="/v1")
        self.app.dependency_overrides[chat.get_user_id] = lambda: self.user["user_id"]

    def test_followed_home_or_away_team_allows_history_connection_and_sending(self):
        with TestClient(self.app) as client:
            for team_id in (6, 14):
                with self.subTest(team_id=team_id):
                    self.followed = [503, team_id]
                    self.assertEqual(client.get("/v1/fixtures/42/chat/messages?language=ko").status_code, 200)
                    with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as socket:
                        socket.send_json({"token": "a" * 40})
                        self.assertEqual(socket.receive_json()["type"], "ready")
                        socket.send_json({"text": "My followed team"})
                        self.assertEqual(socket.receive_json()["text"], "My followed team")
        self.assertEqual(self.create.call_count, 2)
        self.assertEqual(self.user["favorite_team_id"], 503)

    def test_unfollowed_match_denies_history_and_new_connections(self):
        with TestClient(self.app) as client:
            for followed in ([], [503, 591]):
                with self.subTest(followed=followed):
                    self.followed = followed
                    self.assertEqual(client.get("/v1/fixtures/42/chat/messages?language=ko").status_code, 403)
                    with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as socket:
                        socket.send_json({"token": "a" * 40})
                        with self.assertRaises(WebSocketDisconnect) as error:
                            socket.receive_json()
                        self.assertEqual(error.exception.code, 4403)
        self.fetch_messages.assert_not_called()
        self.create.assert_not_called()

    def test_unfollowing_revokes_history_and_sending_without_changing_favorite(self):
        with patch.object(chat, "CHAT_STATE_CHECK_SECONDS", 3600), TestClient(self.app) as client:
            with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as socket:
                socket.send_json({"token": "a" * 40})
                socket.receive_json()
                self.followed = [503]
                self.assertEqual(client.get("/v1/fixtures/42/chat/messages?language=ko").status_code, 403)
                socket.send_json({"text": "No longer following"})
                with self.assertRaises(WebSocketDisconnect) as error:
                    socket.receive_json()
                self.assertEqual(error.exception.code, 4403)
        self.create.assert_not_called()

    def test_unfollowing_closes_idle_viewers(self):
        with patch.object(chat, "CHAT_STATE_CHECK_SECONDS", 0.02), TestClient(self.app) as client:
            with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as socket:
                socket.send_json({"token": "a" * 40})
                socket.receive_json()
                self.followed = [503]
                with self.assertRaises(WebSocketDisconnect) as error:
                    socket.receive_json()
                self.assertEqual(error.exception.code, 4403)
        self.assertEqual(self.app.state.chat_hub.rooms, {})

    def test_changing_favorite_keeps_chat_access_while_still_following(self):
        self.user["favorite_team_id"] = 6
        with TestClient(self.app) as client:
            with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as socket:
                socket.send_json({"token": "a" * 40})
                socket.receive_json()
                self.user["favorite_team_id"] = 503
                socket.send_json({"text": "Still following"})
                self.assertEqual(socket.receive_json()["text"], "Still following")

    def test_unfollowed_recipient_does_not_receive_the_next_message(self):
        recipient = {**self.user, "user_id": 2}
        with patch.object(chat, "CHAT_STATE_CHECK_SECONDS", 3600), \
                patch.object(chat.auth_repo, "session_user", side_effect=lambda token: self.user if token == "a" * 40 else recipient), \
                patch.object(chat_repo, "list_following_team_ids", side_effect=lambda user_id, cur=None: [503, 6] if user_id == self.user["user_id"] else self.followed), \
                TestClient(self.app) as client:
            with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as sender, \
                    client.websocket_connect("/v1/fixtures/42/chat?language=ko") as viewer:
                for socket, token in ((sender, "a" * 40), (viewer, "b" * 40)):
                    socket.send_json({"token": token})
                    socket.receive_json()
                self.followed = [503]
                sender.send_json({"text": "After unfollow"})
                self.assertEqual(sender.receive_json()["text"], "After unfollow")
                with self.assertRaises(WebSocketDisconnect) as error:
                    viewer.receive_json()
                self.assertEqual(error.exception.code, 4403)

    def test_only_shared_live_states_allow_history_and_new_connections(self):
        with TestClient(self.app) as client:
            for state in (*LIVE_STATE_IDS, *UPCOMING_STATE_IDS, *PAST_STATE_IDS):
                with self.subTest(state=state):
                    self.fixtures[42]["state_id"] = state
                    live = state in LIVE_STATE_IDS
                    self.fetch_messages.reset_mock()
                    response = client.get("/v1/fixtures/42/chat/messages?language=ko")
                    self.assertEqual(response.status_code, 200 if live else 410)
                    if not live:
                        self.fetch_messages.assert_not_called()
                    with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as socket:
                        socket.send_json({"token": "a" * 40})
                        if live:
                            self.assertEqual(socket.receive_json()["type"], "ready")
                        else:
                            with self.assertRaises(WebSocketDisconnect) as error:
                                socket.receive_json()
                            self.assertEqual(error.exception.code, 4410)
        self.create.assert_not_called()
        self.assertEqual(self.app.state.chat_hub.rooms, {})

    def test_missing_fixture_still_returns_not_found(self):
        with self.assertRaises(HTTPException) as error:
            chat_repo.live_fixture_teams(99)
        self.assertEqual(error.exception.status_code, 404)

    def test_message_after_full_time_is_rejected_without_waiting_for_poll(self):
        with patch.object(chat, "CHAT_STATE_CHECK_SECONDS", 3600), TestClient(self.app) as client:
            with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as socket:
                socket.send_json({"token": "a" * 40})
                socket.receive_json()
                self.fixtures[42]["state_id"] = 5
                socket.send_json({"text": "Too late"})
                with self.assertRaises(WebSocketDisconnect) as error:
                    socket.receive_json()
                self.assertEqual(error.exception.code, 4410)
        self.create.assert_not_called()

    def test_idle_viewers_close_after_full_time_without_affecting_another_match(self):
        with patch.object(chat, "CHAT_STATE_CHECK_SECONDS", 0.02), TestClient(self.app) as client:
            with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as first, \
                    client.websocket_connect("/v1/fixtures/42/chat?language=ko") as second, \
                    client.websocket_connect("/v1/fixtures/43/chat?language=ko") as other:
                for socket in (first, second, other):
                    socket.send_json({"token": "a" * 40})
                    socket.receive_json()
                self.fixtures[42]["state_id"] = 5
                for socket in (first, second):
                    with self.assertRaises(WebSocketDisconnect) as error:
                        socket.receive_json()
                    self.assertEqual(error.exception.code, 4410)
                other.send_json({"text": "Still live"})
                self.assertEqual(other.receive_json()["text"], "Still live")
        self.assertEqual(self.app.state.chat_hub.rooms, {})

    def test_live_connection_survives_idle_checks_and_can_still_send(self):
        checked = Event()
        calls = 0
        original = chat._authorized

        def authorize(token, fixture_id):
            nonlocal calls
            user = original(token, fixture_id)
            calls += 1
            if calls >= 3:
                checked.set()
            return user

        with patch.object(chat, "CHAT_STATE_CHECK_SECONDS", 0.02), \
                patch.object(chat, "_authorized", side_effect=authorize), TestClient(self.app) as client:
            with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as socket:
                socket.send_json({"token": "a" * 40})
                socket.receive_json()
                self.assertTrue(checked.wait(5), "Idle connections must be rechecked")
                socket.send_json({"text": "Still here"})
                self.assertEqual(socket.receive_json()["text"], "Still here")


if __name__ == "__main__":
    unittest.main()
