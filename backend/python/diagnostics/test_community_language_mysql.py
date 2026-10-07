"""기존 격리 MySQL에서 언어 배정 후 원문과 관계가 유지되는지 확인해요."""
from unittest.mock import patch

from diagnostics.test_user_community import CommunityDatabaseCase
from diagnostics import migrate_community_language
from one_touch_loader.api.services.community_periods import utc_now


class CommunityLanguageMigrationTests(CommunityDatabaseCase):
    language_schema = False

    def test_existing_posts_drafts_and_messages_become_korean_without_changing_content(self):
        published = self.post()
        draft = self.post()
        self.execute("UPDATE posts SET state='draft',edited_at=%s WHERE post_id=%s", (utc_now(), draft))
        self.execute("""INSERT INTO post_comments (post_id,user_id,body,created_at)
            VALUES (%s,%s,'Reply',%s)""", (published, self.a, utc_now()))
        self.execute("""INSERT INTO fixture_chat_messages (fixture_id,user_id,body,created_at)
            VALUES (10,%s,'Old message',%s)""", (self.a, utc_now()))
        original = {table: self.execute(f"SELECT * FROM {table}")
                    for table in ("posts", "fixture_chat_messages", "post_comments")}
        with patch("sys.argv", ["migrate_community_language", "--apply"]), patch("builtins.print"):
            migrate_community_language.main()
        for table, rows in original.items():
            expected = rows if table == "post_comments" else [{**row, "language": "ko"} for row in rows]
            self.assertEqual(self.execute(f"SELECT * FROM {table}"), expected)
        for table, index, columns in (("posts", "team_posts", ["team_id", "language", "created_at", "post_id"]),
                                      ("fixture_chat_messages", "fixture_message_order", ["fixture_id", "language", "message_id"])):
            actual = self.execute("""SELECT column_name AS name FROM information_schema.statistics
                WHERE table_schema=DATABASE() AND table_name=%s AND index_name=%s ORDER BY seq_in_index""", (table, index))
            self.assertEqual([row["name"] for row in actual], columns)
