"""기존의 격리 MySQL 테스트 환경에서 배정·마이그레이션·신고를 검사해요."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch

from diagnostics.test_user_community import CommunityDatabaseCase
from diagnostics.migrate_fixture_chat_aliases import backfill_aliases
from one_touch_loader.api.repos import chat_repo


class ChatAliasDatabaseTests(CommunityDatabaseCase):
    def setUp(self):
        super().setUp()
        self.apply_chat_alias_schema()

    def test_name_survives_profile_changes_and_differs_between_matches(self):
        with patch.object(chat_repo, "new_nickname", return_value={"nickname_en": "Cruyff_A8Q4", "nickname_ko": "크루이프_A8Q4"}):
            first = chat_repo.create_message(self.a, 10, "First")
        self.execute("UPDATE users SET username='renamed',display_name='NewName' WHERE user_id=%s", (self.a,))
        second = chat_repo.create_message(self.a, 10, "Second")
        for key in ("nickname_en", "nickname_ko"):
            self.assertEqual(first[key], second[key])
        self.execute("INSERT INTO fixtures VALUES (30,6,14)")
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
