"""기존의 격리 MySQL 테스트 환경에서 배정·마이그레이션·신고를 검사해요."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier, Event
from unittest.mock import patch
from fastapi import HTTPException

from diagnostics.test_user_community import CommunityDatabaseCase
from diagnostics import migrate_fixture_chat_aliases as migration
from diagnostics.migrate_fixture_chat_aliases import backfill_aliases
from one_touch_loader.api.repos import chat_repo
from one_touch_loader.api.services import chat_aliases


class ChatAliasDatabaseTests(CommunityDatabaseCase):
    def setUp(self):
        super().setUp()
        self.apply_chat_alias_schema()

    def test_catalog_migration_preserves_all_145_players(self):
        players = self.execute("SELECT * FROM chat_alias_players ORDER BY english_name")
        self.assertEqual(len(players), 145)
        self.assertEqual(len({p["english_name"] for p in players}), 145)
        by_name = {p["english_name"]: p for p in players}
        for full, english, korean in [("Johan Cruyff", "Cruyff", "크루이프"),
                                      ("Wayne Rooney", "Rooney", "루니"),
                                      ("Zinedine Zidane", "Zidane", "지단")]:
            self.assertEqual((by_name[full]["short_en"], by_name[full]["short_ko"]), (english, korean))
        self.assertIn("Samuel Eto'o", by_name)
        for player in players:
            self.assertRegex(player["short_en"], r"^[A-Za-z]+$")
            self.assertRegex(player["short_ko"], r"^[가-힣]+$")
            with patch.object(chat_aliases.secrets, "choice", side_effect=[player, "A", "8", "Q", "4"]):
                names = chat_aliases.new_nickname(players)
            self.assertEqual(names, {f"nickname_{lang}": f"{player[f'short_{lang}']}_A8Q4" for lang in ("en", "ko")})

    def test_catalog_edits_apply_to_new_authors_and_survive_migration(self):
        first = chat_repo.create_message(self.a, 10, "Before catalog change")
        self.execute("DELETE FROM chat_alias_players")
        self.execute("""INSERT INTO chat_alias_players (english_name,korean_name,short_en,short_ko)
            VALUES ('Park Ji-sung','박지성','ParkJiSung','박지성')""")
        catalog = self.execute("SELECT * FROM chat_alias_players")
        # 같은 배포를 다시 적용해도 운영 중 편집한 후보를 초기 목록으로 되돌리지 않아요.
        self.execute((migration.SQL_DIRECTORY / "migrate_chat_alias_players.sql").read_text(encoding="utf-8"))
        with patch("sys.argv", ["migrate_fixture_chat_aliases", "--apply"]), patch("builtins.print"):
            migration.main()
        self.assertEqual(self.execute("SELECT * FROM chat_alias_players"), catalog)
        repeated = chat_repo.create_message(self.a, 10, "After catalog change")
        self.assertEqual((repeated["nickname_en"], repeated["nickname_ko"]),
                         (first["nickname_en"], first["nickname_ko"]))
        new_author = chat_repo.create_message(self.b, 10, "New author")
        self.assertTrue(new_author["nickname_en"].startswith("ParkJiSung_"))
        self.assertTrue(new_author["nickname_ko"].startswith("박지성_"))

    def test_name_survives_profile_changes_and_differs_between_matches(self):
        with patch.object(chat_repo, "new_nickname", return_value={"nickname_en": "Cruyff_A8Q4", "nickname_ko": "크루이프_A8Q4"}):
            first = chat_repo.create_message(self.a, 10, "First")
        self.execute("UPDATE users SET username='renamed',display_name='NewName' WHERE user_id=%s", (self.a,))
        second = chat_repo.create_message(self.a, 10, "Second")
        for key in ("nickname_en", "nickname_ko"):
            self.assertEqual(first[key], second[key])
        self.execute("INSERT INTO fixtures VALUES (30,6,14,2)")
        repeat = {key: first[key] for key in ("nickname_en", "nickname_ko")}
        fresh = {"nickname_en": "Zidane_4821", "nickname_ko": "지단_4821"}
        with patch.object(chat_repo, "new_nickname", side_effect=[repeat, fresh]) as generate:
            third = chat_repo.create_message(self.a, 30, "Another match")
        self.assertEqual(generate.call_count, 2)
        self.assertEqual(third["nickname_en"], "Zidane_4821")
        history = chat_repo.history(self.b, 10, None, None, 50)
        self.assertEqual([m["nickname_en"] for m in history], [first["nickname_en"]] * 2)

    def test_same_room_names_are_unique_in_both_languages(self):
        with patch.object(chat_repo, "new_nickname", return_value={"nickname_en": "Cruyff_A8Q4", "nickname_ko": "크루이프_A8Q4"}):
            first = chat_repo.create_message(self.a, 10, "First")
        # 영문이 달라도 한국어 표시가 같으면 다른 닉네임을 배정해야 해요.
        collision = {"nickname_en": "Another_1111", "nickname_ko": first["nickname_ko"]}
        fresh = {"nickname_en": "Rooney_X7K2", "nickname_ko": "루니_X7K2"}
        with patch.object(chat_repo, "new_nickname", side_effect=[collision, fresh]) as generate:
            other = chat_repo.create_message(self.b, 10, "Second")
        self.assertEqual(generate.call_count, 2)
        self.assertEqual(other["nickname_en"], "Rooney_X7K2")

    def test_simultaneous_messages_from_one_user_share_one_assignment(self):
        barrier = Barrier(2)

        def send(text):
            barrier.wait(timeout=5)
            return chat_repo.create_message(self.a, 10, text)

        with ThreadPoolExecutor(max_workers=2) as executor:
            one, two = list(executor.map(send, ["One", "Two"]))
        self.assertEqual(one["nickname_en"], two["nickname_en"])
        self.assertEqual(len(self.execute("SELECT * FROM fixture_chat_aliases")), 1)
        self.assertEqual(len(self.execute("SELECT * FROM fixture_chat_messages")), 2)

    def test_backfill_preserves_messages_and_reports_and_is_repeatable(self):
        old = self.execute("""INSERT INTO fixture_chat_messages (fixture_id,user_id,body,created_at)
            VALUES (10,%s,'Old message',UTC_TIMESTAMP())""", (self.a,))
        deleted = self.execute("""INSERT INTO fixture_chat_messages (fixture_id,user_id,body,created_at)
            VALUES (10,NULL,'Deleted author',UTC_TIMESTAMP())""")
        original = self.execute("SELECT * FROM fixture_chat_messages ORDER BY message_id")
        self.assertEqual(backfill_aliases(), 1)
        assigned = self.execute("SELECT * FROM fixture_chat_aliases")
        self.assertEqual(backfill_aliases(), 0)
        self.assertEqual(self.execute("SELECT * FROM fixture_chat_aliases"), assigned)
        self.assertEqual(self.execute("SELECT * FROM fixture_chat_messages ORDER BY message_id"), original)
        later = chat_repo.create_message(self.a, 10, "New message")
        history = chat_repo.history(self.b, 10, None, None, 50)
        self.assertEqual(history[0]["message_id"], old)
        self.assertEqual(history[0]["nickname_en"], later["nickname_en"])
        self.assertEqual(history[1]["message_id"], deleted)
        self.assertTrue(history[1]["author_deleted"])
        self.assertEqual(self.request("POST", f"/v1/chat/messages/{old}/report", self.token_b,
                                      json={"reason": "Spam"}).status_code, 200)
        self.assertEqual(self.execute("SELECT message_id FROM content_reports"), [{"message_id": old}])

    def test_names_start_on_first_message_and_closure_preserves_stored_chat(self):
        from starlette.websockets import WebSocketDisconnect
        self.assertEqual(chat_repo.history(self.a, 10, None, None, 50), [])
        with self.client.websocket_connect("/v1/fixtures/10/chat") as socket:
            socket.send_json({"token": self.token_a})
            socket.receive_json()
            self.assertEqual(self.execute("SELECT * FROM fixture_chat_aliases"), [])
            socket.send_json({"text": "Before full time"})
            socket.receive_json()
            messages = self.execute("SELECT * FROM fixture_chat_messages")
            aliases = self.execute("SELECT * FROM fixture_chat_aliases")
            self.assertEqual(len(aliases), 1)
            self.execute("UPDATE fixtures SET state_id=5 WHERE fixture_id=10")
            socket.send_json({"text": "After full time"})
            with self.assertRaises(WebSocketDisconnect) as error:
                socket.receive_json()
            self.assertEqual(error.exception.code, 4410)
        self.assertEqual(self.request("GET", "/v1/fixtures/10/chat/messages").status_code, 410)
        with self.assertRaises(HTTPException) as error:
            chat_repo.create_message(self.b, 10, "New author after full time")
        self.assertEqual(error.exception.status_code, 410)
        self.assertEqual(self.execute("SELECT * FROM fixture_chat_messages"), messages)
        self.assertEqual(self.execute("SELECT * FROM fixture_chat_aliases"), aliases)
        self.assertEqual(self.request("POST", f"/v1/chat/messages/{messages[0]['message_id']}/report",
                                      self.token_b, json={"reason": "Spam"}).status_code, 200)

    def test_final_whistle_and_message_storage_follow_the_fixture_lock(self):
        before_write, finish_started, allow_write = Event(), Event(), Event()
        original = chat_repo.get_or_create_alias

        def assign(*args):
            before_write.set()
            if not allow_write.wait(5):
                raise AssertionError("Message transaction was not released")
            return original(*args)

        def finish():
            finish_started.set()
            self.execute("UPDATE fixtures SET state_id=5 WHERE fixture_id=10")

        with ThreadPoolExecutor(max_workers=2) as executor, \
                patch.object(chat_repo, "get_or_create_alias", side_effect=assign):
            sent = executor.submit(chat_repo.create_message, self.a, 10, "Before full time")
            try:
                self.assertTrue(before_write.wait(5))
                finished = executor.submit(finish)
                self.assertTrue(finish_started.wait(5))
                with self.assertRaises(TimeoutError):
                    finished.result(timeout=0.2)
            finally:
                allow_write.set()
            sent.result(timeout=5)
            finished.result(timeout=5)
        with self.assertRaises(HTTPException) as error:
            chat_repo.create_message(self.a, 10, "After full time")
        self.assertEqual(error.exception.status_code, 410)
