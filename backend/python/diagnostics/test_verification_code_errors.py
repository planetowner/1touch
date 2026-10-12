"""실제 DB 없이 인증번호 재시도와 만료·소진 안내를 확인해요."""
from contextlib import contextmanager
from datetime import timedelta
import unittest
from unittest.mock import MagicMock, patch

from fastapi import HTTPException

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api.repos import auth_repo


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
            self.assertEqual(self.verify(), (None, "Invalid verification code. Try again."))
            self.assertEqual(self.row["attempts"], attempt)
        self.assertEqual(self.verify("123456"), ("member@example.com", None))
        self.assertIsNone(self.row)

    def test_fifth_typo_requires_resending_and_blocks_further_attempts(self):
        self.row["attempts"] = 4
        expected = (None, "Too many incorrect attempts. Send a new code.")
        self.assertEqual(self.verify(), expected)
        self.assertEqual(self.row["attempts"], 5)
        self.assertEqual(self.verify("123456"), expected)
        self.assertEqual(self.row["attempts"], 5)

    def test_expired_code_requires_resending_without_using_an_attempt(self):
        self.row["expires_at"] = self.now
        self.assertEqual(self.verify("123456"), (None, "This code has expired. Send a new code."))
        self.assertEqual(self.row["attempts"], 0)

    def test_missing_or_wrong_purpose_code_requires_resending(self):
        self.row["purpose"] = "password_reset"
        expected = (None, "This code is no longer valid. Send a new code.")
        self.assertEqual(self.verify("123456"), expected)
        self.assertEqual(self.row["attempts"], 0)
        self.row = None
        self.assertEqual(self.verify("123456"), expected)

    def test_signup_commits_the_failed_attempt_before_returning_its_error(self):
        completed = []
        conn = MagicMock()
        conn.cursor.return_value.__enter__.return_value = self.cur

        @contextmanager
        def transaction():
            yield conn
            completed.append(True)

        with patch.object(auth_repo, "transaction", transaction), \
                patch.object(auth_repo.PASSWORDS, "hash", return_value="hash"):
            with self.assertRaises(HTTPException) as error:
                auth_repo.register_email("challenge", "000000", "Password123", {})
        self.assertEqual(completed, [True])
        self.assertEqual(self.row["attempts"], 1)
        self.assertEqual(error.exception.status_code, 400)
        self.assertEqual(error.exception.detail, "Invalid verification code. Try again.")


if __name__ == "__main__":
    unittest.main()
