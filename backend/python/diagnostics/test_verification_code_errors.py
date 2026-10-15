"""실제 DB 없이 인증번호 재시도와 만료·소진 안내를 확인해요."""
from contextlib import contextmanager
from datetime import timedelta
import unittest
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from fastapi.testclient import TestClient
from mysql.connector import IntegrityError

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api.repos import auth_repo
    from one_touch_loader.api.main import create_app


class VerificationCodeErrorsTests(unittest.TestCase):
    def setUp(self):
        self.now = auth_repo.utc_now()
        self.row = {
            "email": "member@example.com", "purpose": "signup",
            "expires_at": self.now + timedelta(minutes=10),
            "attempts": 0, "code_hash": b"123456",
        }
        self.cur = MagicMock()
        self.cur.fetchone.side_effect = lambda: dict(self.row) if self.row else None
        self.cur.execute.side_effect = self.execute
        self.enterContext(patch.object(auth_repo, "utc_now", return_value=self.now))
        self.enterContext(patch.object(auth_repo, "code_hash", side_effect=lambda _, code: code.encode()))

    def execute(self, sql, params):
        if sql.startswith("UPDATE email_verification_codes SET attempts"):
            self.row["attempts"] += 1
        elif sql.startswith("DELETE FROM email_verification_codes"):
            self.row = None

    def verify(self, code="000000"):
        return auth_repo._consume_code(self.cur, "challenge", code, "signup")

    def test_four_typos_can_be_corrected_on_the_fifth_attempt(self):
        for attempt in range(1, 5):
            self.assertEqual(self.verify(), (None, "verification_code_invalid"))
            self.assertEqual(self.row["attempts"], attempt)
        self.assertEqual(self.verify("123456"), ("member@example.com", None))
        self.assertIsNone(self.row)

    def test_fifth_typo_requires_resending_and_blocks_further_attempts(self):
        self.row["attempts"] = 4
        expected = (None, "verification_code_attempts_exceeded")
        self.assertEqual(self.verify(), expected)
        self.assertEqual(self.row["attempts"], 5)
        self.assertEqual(self.verify("123456"), expected)
        self.assertEqual(self.row["attempts"], 5)

    def test_expired_code_requires_resending_without_using_an_attempt(self):
        self.row["expires_at"] = self.now
        self.assertEqual(self.verify("123456"), (None, "verification_code_expired"))
        self.assertEqual(self.row["attempts"], 0)

    def test_missing_or_wrong_purpose_code_requires_resending(self):
        self.row["purpose"] = "password_reset"
        expected = (None, "verification_code_unusable")
        self.assertEqual(self.verify("123456"), expected)
        self.assertEqual(self.row["attempts"], 0)
        self.row = None
        self.assertEqual(self.verify("123456"), expected)

    def test_all_code_consumers_commit_failed_attempts_and_return_stable_codes(self):
        completed = []
        conn = MagicMock()
        conn.cursor.return_value.__enter__.return_value = self.cur

        @contextmanager
        def transaction():
            yield conn
            completed.append(True)

        cases = [
            ("register", "signup", {"password": "Password123", "username": "member", "display_name": "Member"}),
            ("reset-password", "password_reset", {"password": "Password123"}),
            ("find-username", "username_recovery", {}),
        ]
        with patch.object(auth_repo, "transaction", transaction), \
                patch.object(auth_repo.PASSWORDS, "hash", return_value="hash"), \
                patch.object(auth_repo, "rate_limit"), TestClient(create_app()) as client:
            for route, purpose, body in cases:
                for code, changes, uses_attempt in [
                    ("verification_code_invalid", {}, True),
                    ("verification_code_expired", {"expires_at": self.now}, False),
                    ("verification_code_unusable", {"purpose": "email_change"}, False),
                    ("verification_code_attempts_exceeded", {"attempts": 4}, True),
                ]:
                    with self.subTest(route=route, code=code):
                        self.row.update(purpose=purpose, expires_at=self.now + timedelta(minutes=10), attempts=0)
                        self.row.update(changes)
                        before = self.row["attempts"]
                        completed.clear()
                        response = client.post(f"/v1/auth/email/{route}", json={
                            "challenge_id": "c" * 40, "code": "000000", **body})
                        self.assertEqual(response.status_code, 400, response.text)
                        self.assertEqual(response.json(), {"detail": {"code": code}})
                        self.assertEqual(completed, [True])
                        self.assertEqual(self.row["attempts"], before + uses_attempt)

    def test_registration_duplicate_returns_conflict_code(self):
        with patch.object(auth_repo, "transaction", side_effect=IntegrityError(errno=1062)), \
                patch.object(auth_repo.PASSWORDS, "hash", return_value="hash"):
            with self.assertRaises(HTTPException) as error:
                auth_repo.register_email("challenge", "123456", "Password123", {})
        self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(error.exception.detail, {"code": "registration_conflict"})

    def test_rate_limit_keeps_retry_after_and_commits_count(self):
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchone.return_value = {"window_started_at": self.now, "attempts": 1}
        completed = []

        @contextmanager
        def transaction():
            yield conn
            completed.append(True)

        with patch.object(auth_repo, "transaction", transaction):
            with self.assertRaises(HTTPException) as error:
                auth_repo.rate_limit("test", 1, 60)
        self.assertEqual(error.exception.status_code, 429)
        self.assertEqual(error.exception.detail, {"code": "auth_rate_limited"})
        self.assertEqual(error.exception.headers, {"Retry-After": "60"})
        self.assertEqual(completed, [True])
        self.assertEqual(cur.execute.call_args.args[1][1], 2)


if __name__ == "__main__":
    unittest.main()
