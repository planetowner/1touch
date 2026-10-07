"""운영 DB를 열지 않고 익명 배정·조회·실시간 응답의 동일한 규칙을 검사해요."""
from datetime import datetime
import unittest
from unittest.mock import Mock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from mysql.connector import IntegrityError

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from diagnostics import migrate_fixture_chat_aliases as migration
    from one_touch_loader.api.repos import chat_repo
    from one_touch_loader.api.routes import chat
    from one_touch_loader.api.services import chat_aliases


NICKNAME = {"nickname_en": "Cruyff_A8Q4", "nickname_ko": "크루이프_A8Q4"}
OTHER_NICKNAME = {"nickname_en": "Rooney_X7K2", "nickname_ko": "루니_X7K2"}
PLAYERS = [{"short_en": "Cruyff", "short_ko": "크루이프"}, {"short_en": "Rooney", "short_ko": "루니"}]


def stored_message(**changes):
    return {"message_id": 11, "fixture_id": 42, "user_id": 928371, **NICKNAME,
            "text": "Hello", "created_at": datetime(2026, 9, 30, 12), **changes}


class ChatNicknameTests(unittest.TestCase):
    def test_both_languages_use_one_player_and_suffix_from_the_given_catalog(self):
        for player in PLAYERS:
            with patch.object(chat_aliases.secrets, "choice", side_effect=[player, "A", "8", "Q", "4"]):
                names = chat_aliases.new_nickname(PLAYERS)
            self.assertEqual(names, {f"nickname_{lang}": f"{player[f'short_{lang}']}_A8Q4" for lang in ("en", "ko")})

    def test_an_assigned_name_is_reused_without_generating_another(self):
        cursor = Mock()
        cursor.fetchone.return_value = NICKNAME
        with patch.object(chat_repo, "new_nickname") as generate:
            self.assertEqual(chat_repo.get_or_create_alias(cursor, 928371, 42), NICKNAME)
        generate.assert_not_called()
        self.assertEqual(cursor.execute.call_count, 1)
        cursor.fetchall.assert_not_called()

    def test_new_assignments_read_the_current_database_catalog(self):
        cursor = Mock()
        cursor.fetchone.return_value = None
        cursor.fetchall.side_effect = [[PLAYERS[0]], [PLAYERS[1]]]
        first = chat_repo.get_or_create_alias(cursor, 928371, 42)
        second = chat_repo.get_or_create_alias(cursor, 5, 42)
        self.assertTrue(first["nickname_en"].startswith("Cruyff_"))
        self.assertTrue(second["nickname_en"].startswith("Rooney_"))
        self.assertEqual(cursor.fetchall.call_count, 2)
        self.assertEqual(cursor.execute.call_args_list[1].args[0],
                         "SELECT short_en,short_ko FROM chat_alias_players ORDER BY english_name")

    def test_duplicate_nickname_is_replaced_but_other_database_errors_propagate(self):
        cursor = Mock()
        cursor.fetchone.return_value = None
        cursor.fetchall.return_value = PLAYERS
        cursor.execute.side_effect = [None, None, IntegrityError(errno=1062), None]
        with patch.object(chat_repo, "new_nickname", side_effect=[NICKNAME, OTHER_NICKNAME]) as generate:
            self.assertEqual(chat_repo.get_or_create_alias(cursor, 928371, 42), OTHER_NICKNAME)
        self.assertEqual([call.args for call in generate.call_args_list], [(PLAYERS,), (PLAYERS,)])
        cursor.fetchall.assert_called_once()
        self.assertEqual(cursor.execute.call_args.args[1], (42, 928371, "Rooney_X7K2", "루니_X7K2"))

        cursor.execute.side_effect = [None, None, IntegrityError(errno=1452)]
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
            history = chat_repo.history(5, 42, 20, None, 2, language="ko")
        self.assertEqual(fetch.call_args.args[1], (42, "ko", 5, 20, 2))
        self.assertEqual([m["message_id"] for m in history], [11, 12])
        self.assertEqual(history[0], chat_aliases.public_chat_message(stored_message(), 5))


class ChatAliasMigrationTests(unittest.TestCase):
    def test_preview_does_not_create_tables_or_assign_names(self):
        with patch("sys.argv", ["migrate_fixture_chat_aliases"]), patch("builtins.print") as output, \
                patch.object(migration, "fetch_one_dict", return_value=None), \
                patch.object(migration, "transaction") as transaction, \
                patch.object(migration, "pending_authors", return_value=[{}]) as pending, \
                patch.object(migration, "backfill_aliases") as backfill:
            migration.main()
        transaction.assert_not_called()
        backfill.assert_not_called()
        pending.assert_called_once_with(False)
        self.assertIn("Player catalog present: False; players: 0", output.call_args.args[0])

    def test_apply_prepares_only_missing_tables_before_backfill(self):
        for catalog_exists, aliases_exist in [(False, False), (False, True), (True, True)]:
            with self.subTest(catalog_exists=catalog_exists, aliases_exist=aliases_exist), \
                    patch("sys.argv", ["migrate_fixture_chat_aliases", "--apply"]), patch("builtins.print"), \
                    patch.object(migration, "fetch_one_dict", side_effect=[
                        {"present": 1} if catalog_exists else None,
                        {"present": 1} if aliases_exist else None, {"count": 145}]), \
                    patch.object(migration, "transaction") as transaction, \
                    patch.object(migration, "pending_authors", return_value=[]):
                cursor = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value

                def backfill():
                    statements = [call.args[0] for call in cursor.execute.call_args_list]
                    expected = [table for table, exists in zip(migration.TABLES, (catalog_exists, aliases_exist)) if not exists]
                    self.assertEqual(statements, [(migration.SQL_DIRECTORY / f"migrate_{table}.sql").read_text(encoding="utf-8")
                                                  for table in expected])
                    return 0

                with patch.object(migration, "backfill_aliases", side_effect=backfill) as assign:
                    migration.main()
                assign.assert_called_once_with()
                if catalog_exists and aliases_exist:
                    transaction.assert_not_called()


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
            with client.websocket_connect("/v1/fixtures/42/chat?language=ko") as sender, \
                    client.websocket_connect("/v1/fixtures/42/chat?language=ko") as recipient:
                sender.send_json({"token": "a" * 40})
                recipient.send_json({"token": "b" * 40})
                self.assertEqual(sender.receive_json()["type"], "ready")
                self.assertEqual(recipient.receive_json()["type"], "ready")
                sender.send_json({"text": "Hello"})
                own, other = sender.receive_json(), recipient.receive_json()
                self.assertEqual(own, {"type": "message", **chat_aliases.public_chat_message(row, 928371)})
                self.assertEqual(other, {**own, "is_mine": False})
                create.assert_called_once_with(928371, 42, "Hello", language="ko")

                from starlette.websockets import WebSocketDisconnect
                sender.send_json({"text": "Hello", "nickname_en": "Fake_AAAA"})
                with self.assertRaises(WebSocketDisconnect) as error:
                    sender.receive_json()
                self.assertEqual(error.exception.code, 4400)
                self.assertEqual(create.call_count, 1)


if __name__ == "__main__":
    unittest.main()
