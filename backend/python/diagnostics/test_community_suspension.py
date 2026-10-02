"""제재 저장·조회 계약을 메모리 DB로 검사해요. 운영 DB에는 연결하지 않아요."""
from datetime import datetime, timedelta
from pathlib import Path
import re
import sqlite3
import unittest
from unittest.mock import patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api import db as api_db, deps
    from one_touch_loader.api.repos import community_repo, moderation_repo, users_repo
    from one_touch_loader.api.routes import community, moderation
    from one_touch_loader.api.schemas.community import CommunityBanReason
    from diagnostics import migrate_community_suspension_reason as migration


class CommunitySuspensionTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:", check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.addCleanup(self.db.close)
        self.db.executescript("""
            CREATE TABLE users (user_id INTEGER PRIMARY KEY, username TEXT,
                display_name TEXT, suspended_until TEXT);
            INSERT INTO users VALUES (1,'member','Member',NULL),
                (2,'admin','Admin',NULL);
        """)
        self.now = datetime(2026, 10, 1)
        self.patch(api_db, "get_conn", side_effect=AssertionError("External DB access is forbidden"))
        self.patch(community_repo, "get_user", side_effect=self.user)
        self.patch(moderation_repo, "get_user", side_effect=self.user)
        self.locks = self.patch(moderation_repo, "lock_user", side_effect=lambda cur, user_id: self.user(user_id))
        self.patch(moderation_repo, "utc_now", return_value=self.now)
        self.patch(users_repo, "utc_now", return_value=self.now)
        transaction = self.patch(moderation_repo, "transaction")
        cursor = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
        cursor.execute.side_effect = self.execute
        self.patch(deps, "session_user", side_effect=self.session)
        environment = patch.dict("os.environ", {"COMMUNITY_ADMIN_USER_IDS": "2"})
        environment.start()
        self.addCleanup(environment.stop)
        app = FastAPI()
        app.include_router(community.router, prefix="/v1")
        app.include_router(moderation.router, prefix="/v1")
        self.client = TestClient(app)
        self.addCleanup(self.client.close)
        self.db.executescript(migration.SQL_PATH.read_text(encoding="utf-8"))

    def patch(self, target, name, **kwargs):
        patcher = patch.object(target, name, **kwargs)
        result = patcher.start()
        self.addCleanup(patcher.stop)
        return result

    def execute(self, sql, params=()):
        values = [value.isoformat() if isinstance(value, datetime) else value for value in params]
        return self.db.execute(sql.replace("%s", "?"), values)

    def user(self, user_id):
        row = self.db.execute("SELECT * FROM users WHERE user_id=?", (user_id,)).fetchone()
        if row is None:
            raise HTTPException(401, "User not found")
        user = dict(row)
        if user["suspended_until"] is not None:
            user["suspended_until"] = datetime.fromisoformat(user["suspended_until"])
        return user

    def session(self, token):
        if token not in ("member", "admin"):
            raise HTTPException(401, "Unknown session")
        return {"user_id": 1 if token == "member" else 2}

    def suspend(self, body, token="admin", user_id=1):
        return self.client.put(f"/v1/admin/users/{user_id}/suspension", json=body,
                               headers={"Authorization": f"Bearer {token}"})

    def status(self, token="member"):
        return self.client.get("/v1/community/suspension", headers={"Authorization": f"Bearer {token}"})

    def test_all_twelve_reasons_round_trip_without_localized_copy(self):
        self.assertEqual(len(CommunityBanReason), 12)
        for reason in CommunityBanReason:
            with self.subTest(reason=reason):
                response = self.suspend({"suspended_until": "2026-10-02T09:00:00+09:00", "reason": reason.value})
                self.assertEqual(response.status_code, 200, response.text)
                self.assertEqual(self.status().json(), {"suspension": {
                    "reason": reason.value, "ends_at": "2026-10-02T00:00:00Z"}})
                self.assertEqual(self.user(1)["suspension_reason"], reason.value)
        self.assertEqual([call.args[1] for call in self.locks.call_args_list[:2]], [1, 2])

    def test_suspended_user_can_read_own_status_but_still_cannot_participate(self):
        self.suspend({"suspended_until": "2026-10-02T00:00:00Z", "reason": "spam"})
        self.assertEqual(self.status().status_code, 200)
        with self.assertRaises(HTTPException) as raised:
            users_repo.require_profile(self.user(1))
        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(self.status("admin").json(), {"suspension": None})

    def test_expired_suspension_remains_available_for_return_rules_without_blocking_access(self):
        self.execute("UPDATE users SET suspended_until=%s,suspension_reason='spam' WHERE user_id=1",
                     (self.now - timedelta(seconds=1),))
        self.assertEqual(self.status().json(), {"suspension": {
            "reason": "spam", "ends_at": "2026-09-30T23:59:59Z"}})
        users_repo.require_profile(self.user(1))

    def test_legacy_rows_preserve_unknown_reasons_and_end_times(self):
        self.execute("UPDATE users SET suspended_until=%s WHERE user_id=1", (self.now + timedelta(days=1),))
        self.assertEqual(self.status().json(), {"suspension": {
            "reason": None, "ends_at": "2026-10-02T00:00:00Z"}})

    def test_revoking_suspension_clears_both_fields_and_restores_access(self):
        self.suspend({"suspended_until": "2026-10-02T00:00:00Z", "reason": "hate_speech"})
        response = self.suspend({"suspended_until": None})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.status().json(), {"suspension": None})
        self.assertIsNone(self.user(1)["suspension_reason"])
        users_repo.require_profile(self.user(1))

    def test_invalid_requests_never_change_suspension(self):
        for body, expected in (
            ({"suspended_until": "2026-10-02T00:00:00Z"}, 422),
            ({"suspended_until": "2026-10-02T00:00:00Z", "reason": "unknown"}, 422),
            ({"suspended_until": "2026-10-02T00:00:00", "reason": "spam"}, 422),
            ({"suspended_until": "2026-10-01T00:00:00Z", "reason": "spam"}, 400),
            ({"suspended_until": None, "reason": "spam"}, 422),
        ):
            with self.subTest(body=body):
                self.assertEqual(self.suspend(body).status_code, expected)
                self.assertEqual(self.status().json(), {"suspension": None})

    def test_authentication_and_server_admin_permissions_are_preserved(self):
        self.assertEqual(self.client.get("/v1/community/suspension").status_code, 401)
        self.assertEqual(self.status("invalid").status_code, 401)
        body = {"suspended_until": "2026-10-02T00:00:00Z", "reason": "spam"}
        self.assertEqual(self.suspend(body, token="member").status_code, 403)
        self.assertEqual(self.suspend(body, user_id=2).status_code, 400)
        self.assertEqual(self.status().json(), {"suspension": None})

    def test_flutter_and_api_use_the_same_reason_codes(self):
        root = Path(__file__).resolve().parents[3]
        model = (root / "frontend/lib/models/community_ban.dart").read_text(encoding="utf-8")
        codes = set(re.findall(r"\b\w+\(\s*'([a-z_]+)'", model))
        self.assertEqual(codes, {reason.value for reason in CommunityBanReason})


class SuspensionMigrationTests(unittest.TestCase):
    def test_preview_and_repeated_apply_do_not_execute_ddl(self):
        for exists, apply in ((None, False), ({"1": 1}, False), ({"1": 1}, True)):
            with self.subTest(exists=exists, apply=apply), \
                    patch.object(migration, "fetch_one_dict", return_value=exists), \
                    patch.object(migration, "transaction") as transaction:
                self.assertEqual(migration.migrate(apply=apply), exists is not None)
                transaction.assert_not_called()

    def test_apply_adds_nullable_column_without_changing_existing_rows(self):
        with sqlite3.connect(":memory:") as db:
            db.executescript("""CREATE TABLE users (user_id INTEGER, suspended_until TEXT);
                INSERT INTO users VALUES (1,'2026-10-02T00:00:00'),(2,NULL);""")
            original = db.execute("SELECT user_id,suspended_until FROM users").fetchall()
            with patch.object(migration, "fetch_one_dict", return_value=None), \
                    patch.object(migration, "transaction") as transaction:
                cursor = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
                cursor.execute.side_effect = db.executescript
                self.assertTrue(migration.migrate(apply=True))
                cursor.execute.assert_called_once()
            self.assertEqual(db.execute("SELECT user_id,suspended_until FROM users").fetchall(), original)
            self.assertEqual(db.execute("SELECT suspension_reason FROM users").fetchall(), [(None,), (None,)])


if __name__ == "__main__":
    unittest.main()
