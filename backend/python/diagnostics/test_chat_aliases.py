"""운영 DB를 열지 않고 익명 배정·조회·실시간 응답의 동일한 규칙을 검사해요."""
from datetime import datetime
import unittest
from unittest.mock import Mock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from mysql.connector import IntegrityError

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api.repos import chat_repo
    from one_touch_loader.api.routes import chat
    from one_touch_loader.api.services import chat_aliases


NICKNAME = {"nickname_en": "Cruyff_A8Q4", "nickname_ko": "크루이프_A8Q4"}
OTHER_NICKNAME = {"nickname_en": "Rooney_X7K2", "nickname_ko": "루니_X7K2"}


def stored_message(**changes):
    return {"message_id": 11, "fixture_id": 42, "user_id": 928371, **NICKNAME,
            "text": "Hello", "created_at": datetime(2026, 9, 30, 12), **changes}


class ChatNicknameTests(unittest.TestCase):
    def test_all_145_players_have_short_english_and_korean_names(self):
        players = chat_aliases.PLAYER_NAMES
        self.assertEqual(len(players), 145)
        self.assertEqual(len({p["english_name"] for p in players}), 145)
        by_name = {p["english_name"]: p for p in players}
        for full, english, korean in [("Johan Cruyff", "Cruyff", "크루이프"),
                                      ("Wayne Rooney", "Rooney", "루니"),
                                      ("Zinedine Zidane", "Zidane", "지단")]:
            self.assertEqual((by_name[full]["short_en"], by_name[full]["short_ko"]), (english, korean))
        for player in players:
            self.assertRegex(player["short_en"], r"^[A-Za-z]+$")
            self.assertRegex(player["short_ko"], r"^[가-힣]+$")
            with patch.object(chat_aliases.secrets, "choice", side_effect=[player, "A", "8", "Q", "4"]):
                names = chat_aliases.new_nickname()
            self.assertEqual(names, {f"nickname_{lang}": f"{player[f'short_{lang}']}_A8Q4" for lang in ("en", "ko")})

    def test_an_assigned_name_is_reused_without_generating_another(self):
        cursor = Mock()
        cursor.fetchone.return_value = NICKNAME
        with patch.object(chat_repo, "new_nickname") as generate:
            self.assertEqual(chat_repo.get_or_create_alias(cursor, 928371, 42), NICKNAME)
        generate.assert_not_called()
        self.assertEqual(cursor.execute.call_count, 1)

    def test_duplicate_nickname_is_replaced_but_other_database_errors_propagate(self):
        cursor = Mock()
        cursor.fetchone.return_value = None
        cursor.execute.side_effect = [None, IntegrityError(errno=1062), None]
        with patch.object(chat_repo, "new_nickname", side_effect=[NICKNAME, OTHER_NICKNAME]):
            self.assertEqual(chat_repo.get_or_create_alias(cursor, 928371, 42), OTHER_NICKNAME)
        self.assertEqual(cursor.execute.call_args.args[1], (42, 928371, "Rooney_X7K2", "루니_X7K2"))

        cursor.execute.side_effect = [None, IntegrityError(errno=1452)]
        with self.assertRaises(IntegrityError), patch.object(chat_repo, "new_nickname", return_value=NICKNAME):
            chat_repo.get_or_create_alias(cursor, 928371, 42)

    def test_public_message_has_no_account_identity_and_marks_only_the_owner(self):
        row = stored_message(username="private-login", display_name="Real Name", avatar_url="/v1/users/928371/avatar")
        for viewer, own in [(928371, True), (5, False)]:
            result = chat_aliases.public_chat_message(row, viewer)
            self.assertEqual(set(result), {"message_id", "fixture_id", "nickname_en", "nickname_ko",
                                           "is_mine", "author_deleted", "text", "created_at"})
            self.assertEqual(result["is_mine"], own)
            self.assertEqual(result["nickname_en"], "Cruyff_A8Q4")
            self.assertEqual(result["created_at"], "2026-09-30T12:00:00Z")
        self.assertEqual(row["user_id"], 928371)

    def test_deleted_authors_keep_existing_deleted_user_behavior(self):
        result = chat_aliases.public_chat_message(stored_message(user_id=None), 5)
        self.assertTrue(result["author_deleted"])
        self.assertFalse(result["is_mine"])
        self.assertIsNone(result["nickname_en"])
        self.assertIsNone(result["nickname_ko"])

    def test_unmigrated_authors_cannot_fall_back_to_real_names(self):
        with self.assertRaises(RuntimeError):
            chat_aliases.public_chat_message(stored_message(nickname_en=None, nickname_ko=None), 5)

    def test_history_uses_the_same_anonymous_payload_and_cursor_order(self):
        rows = [stored_message(message_id=12), stored_message(message_id=11)]
        with patch.object(chat_repo, "check_chat_user"), patch.object(chat_repo, "get_user"), \
                patch.object(chat_repo, "fetch_all_dict", return_value=rows) as fetch:
            history = chat_repo.history(5, 42, 20, None, 2)
        self.assertEqual(fetch.call_args.args[1], (42, 5, 20, 2))
        self.assertEqual([m["message_id"] for m in history], [11, 12])
        self.assertEqual(history[0], chat_aliases.public_chat_message(stored_message(), 5))


class ChatAnonymousSocketTests(unittest.TestCase):
    def test_both_viewers_receive_one_alias_without_real_identity_or_client_override(self):
        app = FastAPI()
        app.state.chat_hub = chat.ChatHub()
        app.include_router(chat.router, prefix="/v1")
        row = stored_message(username="private-login", display_name="Real Name", avatar_url="private-photo")
        with patch.object(chat, "_authorized", side_effect=lambda token, _: {"user_id": 928371 if token == "a" * 40 else 5}), \
                patch.object(chat.auth_repo, "rate_limit"), \
                patch.object(chat.chat_repo, "create_message", return_value=row) as create, \
                patch.object(chat, "is_blocked", return_value=False), TestClient(app) as client:
            with client.websocket_connect("/v1/fixtures/42/chat") as sender, \
                    client.websocket_connect("/v1/fixtures/42/chat") as recipient:
                sender.send_json({"token": "a" * 40})
                recipient.send_json({"token": "b" * 40})
                self.assertEqual(sender.receive_json()["type"], "ready")
                self.assertEqual(recipient.receive_json()["type"], "ready")
                sender.send_json({"text": "Hello"})
                own, other = sender.receive_json(), recipient.receive_json()
                self.assertEqual(own, {"type": "message", **chat_aliases.public_chat_message(row, 928371)})
                self.assertEqual(other, {**own, "is_mine": False})
                create.assert_called_once_with(928371, 42, "Hello")

                from starlette.websockets import WebSocketDisconnect
                sender.send_json({"text": "Hello", "nickname_en": "Fake_AAAA"})
                with self.assertRaises(WebSocketDisconnect) as error:
                    sender.receive_json()
                self.assertEqual(error.exception.code, 4400)
                self.assertEqual(create.call_count, 1)


if __name__ == "__main__":
    unittest.main()
