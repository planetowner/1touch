"""채팅 저장·신고가 같은 트랜잭션의 팔로우 목록을 쓰는지 운영 DB 없이 검사해요."""
import unittest
from unittest.mock import patch

from fastapi import HTTPException

from diagnostics.test_chat_aliases import NICKNAME, chat_repo
from one_touch_loader.api.repos import posts_repo, teams_repo


class ChatFollowedAccessTests(unittest.TestCase):
    def setUp(self):
        self.user = {"user_id": 1, "favorite_team_id": 503, "display_name": "Member", "suspended_until": None}
        self.fixture = {"home_team_id": 6, "away_team_id": 14, "state_id": 2}
        # 별도 연결로 읽으면 팔로우 변경과 저장 사이의 사용자 잠금을 공유할 수 없어요.
        self.enterContext(patch.object(teams_repo, "fetch_all_dict", side_effect=AssertionError("Use the active transaction")))

    def test_message_storage_checks_current_following_before_assigning_alias_or_inserting(self):
        for followed, allowed in [([503, 6], True), ([503, 14], True), ([503], False), ([], False)]:
            with self.subTest(followed=followed), patch.object(chat_repo, "transaction") as transaction, \
                    patch.object(chat_repo, "get_or_create_alias", return_value=NICKNAME) as alias:
                cursor = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
                cursor.fetchone.side_effect = [self.user, self.fixture]
                cursor.fetchall.return_value = [{"team_id": team_id} for team_id in followed]
                cursor.lastrowid = 10
                if allowed:
                    message = chat_repo.create_message(1, 42, "Followed team", language="ko")
                    self.assertEqual(message["message_id"], 10)
                    self.assertEqual(message["text"], "Followed team")
                    alias.assert_called_once_with(cursor, 1, 42)
                    self.assertTrue(cursor.execute.call_args.args[0].startswith("INSERT INTO fixture_chat_messages"))
                else:
                    with self.assertRaises(HTTPException) as error:
                        chat_repo.create_message(1, 42, "Not following", language="ko")
                    self.assertEqual(error.exception.status_code, 403)
                    alias.assert_not_called()
                    self.assertTrue(all(call.args[0].lstrip().startswith("SELECT")
                                        for call in cursor.execute.call_args_list))

    def test_chat_reports_use_following_without_requiring_a_live_match(self):
        for followed, allowed in [([503, 6], True), ([503, 14], True), ([503], False), ([], False)]:
            with self.subTest(followed=followed), patch.object(posts_repo, "transaction") as transaction, \
                    patch.object(posts_repo, "require_visible_author") as visible:
                cursor = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
                cursor.fetchone.side_effect = [self.user, {**self.fixture, "state_id": 5, "user_id": 2}]
                cursor.fetchall.return_value = [{"team_id": team_id} for team_id in followed]
                if allowed:
                    posts_repo.report_content(1, "message", 10, "Spam")
                    visible.assert_called_once_with(1, 2)
                    self.assertTrue(cursor.execute.call_args.args[0].startswith("INSERT INTO content_reports"))
                    self.assertEqual(cursor.execute.call_args.args[1][:3], (1, 10, "Spam"))
                else:
                    with self.assertRaises(HTTPException) as error:
                        posts_repo.report_content(1, "message", 10, "Spam")
                    self.assertEqual(error.exception.status_code, 403)
                    visible.assert_not_called()
                    self.assertTrue(all(call.args[0].lstrip().startswith("SELECT")
                                        for call in cursor.execute.call_args_list))


if __name__ == "__main__":
    unittest.main()
