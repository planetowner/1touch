"""운영 DB 없이 정리 대상, 경계 시각, 조회 전용 모드와 배치 제한을 확인해요."""
from contextlib import ExitStack
from datetime import datetime, timedelta
import sqlite3
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from diagnostics.test_notifications import SqliteConnection

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.core import db
    from one_touch_loader.loaders import community_maintenance as maintenance


class ReportRetentionTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.raw = sqlite3.connect(":memory:")
        self.addCleanup(self.raw.close)
        self.raw.execute("PRAGMA foreign_keys=ON")
        self.raw.executescript("""
            CREATE TABLE user_sessions (expires_at TEXT);
            CREATE TABLE email_verification_codes (expires_at TEXT);
            CREATE TABLE api_rate_limits (window_started_at TEXT);
            CREATE TABLE media_deletions (object_key TEXT);
            CREATE TABLE posts (post_id INTEGER PRIMARY KEY, user_id INTEGER,
                state TEXT, edited_at TEXT, body TEXT);
            CREATE TABLE post_attachments (attachment_id INTEGER, user_id INTEGER,
                post_id INTEGER, created_at TEXT);
            CREATE TABLE content_reports (report_id INTEGER PRIMARY KEY,
                post_id INTEGER REFERENCES posts(post_id), resolved_at TEXT);
            INSERT INTO posts VALUES (1, 10, 'hidden', '2025-01-01', 'Retained content');
        """)
        self.now = datetime(2026, 10, 6, 12)
        boundary = self.now - timedelta(days=180)
        self.raw.executemany("INSERT INTO content_reports VALUES (?, 1, ?)", [
            (1, None),
            (2, boundary + timedelta(microseconds=1)),
            (3, boundary),
            (4, boundary - timedelta(days=30)),
        ])
        self.raw.commit()
        self.conn = SqliteConnection(self.raw)
        self.conn.start_transaction = lambda **options: self.raw.execute("BEGIN")
        self.stack.enter_context(patch.object(db, "_pool", SimpleNamespace(get_connection=lambda: self.conn)))
        self.stack.enter_context(patch.object(maintenance, "utc_now", return_value=self.now))
        self.storage = self.stack.enter_context(patch.object(maintenance, "object_operation"))

    def remaining(self):
        return [row[0] for row in self.raw.execute("SELECT report_id FROM content_reports ORDER BY report_id")]

    def test_check_counts_expired_reports_without_any_writes(self):
        # SQL 쓰기를 거부해 조회 모드가 삭제·수정 없이 실행되는지 확인해요.
        writes = {sqlite3.SQLITE_INSERT, sqlite3.SQLITE_UPDATE, sqlite3.SQLITE_DELETE}
        self.raw.set_authorizer(lambda action, *_: sqlite3.SQLITE_DENY if action in writes else sqlite3.SQLITE_OK)
        result = maintenance.maintain_community(check=True)
        self.assertEqual(result["content_reports"], 2)
        self.assertEqual(self.remaining(), [1, 2, 3, 4])
        self.storage.assert_not_called()

    def test_apply_preserves_pending_recent_reports_and_reported_content(self):
        result = maintenance.maintain_community(check=False)
        self.assertEqual(result["content_reports"], 2)
        self.assertEqual(self.remaining(), [1, 2])
        self.assertEqual(self.raw.execute("SELECT state,body FROM posts").fetchone(),
                         ("hidden", "Retained content"))
        self.storage.assert_not_called()
        self.assertEqual(maintenance.maintain_community(check=False)["content_reports"], 0)

    def test_batch_limit_continues_until_only_unexpired_reports_remain(self):
        for remaining in (3, 2):
            result = maintenance.maintain_community(check=False, limit=1)
            self.assertEqual(result["content_reports"], 1)
            self.assertEqual(len(self.remaining()), remaining)
        self.assertEqual(self.remaining(), [1, 2])


if __name__ == "__main__":
    unittest.main()
