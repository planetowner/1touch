"""LINE의 검증·탈퇴 경계와 기존 회원 저장 규칙의 재사용을 검사해요."""
import os
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

from fastapi import HTTPException
import requests

# 운영 DB 풀을 열지 않는 기존 격리 테스트 준비를 먼저 가져와요.
from diagnostics.test_user_community import CommunityDatabaseCase, auth_repo, social_login
from diagnostics.verify_line_login import verify_schema


def response(status=200, body=None):
    result = Mock(status_code=status)
    result.json.return_value = body
    return result


class LineProviderTests(unittest.TestCase):
    def setUp(self):
        settings = patch.dict(os.environ, {"LINE_CHANNEL_ID": "123456", "LINE_CHANNEL_SECRET": "server-secret"})
        settings.start()
        self.addCleanup(settings.stop)

    def verify_response(self, **changes):
        return response(body={"client_id": "123456", "expires_in": 30, "scope": "openid", **changes})

    def test_identity_comes_from_verified_token_and_provider_userinfo(self):
        with patch.object(social_login.requests, "request", side_effect=[
            self.verify_response(), response(body={"sub": "line-user"}),
        ]) as request:
            self.assertEqual(social_login.line_subject("user-token"), "line-user")
        self.assertEqual(request.call_args_list[0].kwargs["params"], {"access_token": "user-token"})
        self.assertEqual(request.call_args_list[1].kwargs["headers"], {"Authorization": "Bearer user-token"})
        self.assertTrue(all(call.kwargs["timeout"] == 15 for call in request.call_args_list))

    def test_wrong_channel_expired_and_rejected_tokens_never_retrieve_identity(self):
        for invalid in (self.verify_response(client_id="other-channel"), self.verify_response(expires_in=0),
                        self.verify_response(expires_in=-1), response(400), response(401)):
            with self.subTest(response=invalid), patch.object(social_login.requests, "request", return_value=invalid) as request:
                with self.assertRaises(HTTPException) as error:
                    social_login.line_subject("rejected-token")
                self.assertEqual(error.exception.status_code, 401)
                self.assertEqual(request.call_count, 1)

    def test_missing_settings_and_unavailable_provider(self):
        with patch.dict(os.environ, {"LINE_CHANNEL_ID": ""}), patch.object(social_login.requests, "request") as request:
            with self.assertRaises(HTTPException) as error:
                social_login.line_subject("user-token")
            self.assertEqual(error.exception.status_code, 503)
            request.assert_not_called()
        for failure in (response(503), requests.Timeout("unavailable")):
            with patch.object(social_login.requests, "request", side_effect=[failure]):
                with self.assertRaises(HTTPException) as error:
                    social_login.line_subject("user-token")
                self.assertEqual(error.exception.status_code, 503)

    def test_unlink_checks_owner_then_deauthorizes_with_separate_channel_token(self):
        empty = response(204)
        empty.json.side_effect = AssertionError("204 must not be decoded as JSON")
        with patch.object(social_login.requests, "request", side_effect=[self.verify_response(),
            response(body={"sub": "line-user"}), response(body={"access_token": "channel-token"}), empty,
        ]) as request:
            social_login.unlink_line("line-user", "user-token")
        issue, unlink = request.call_args_list[-2:]
        self.assertEqual(issue.args, ("POST", "https://api.line.me/oauth2/v3/token"))
        self.assertEqual(issue.kwargs["data"], {"grant_type": "client_credentials", "client_id": "123456", "client_secret": "server-secret"})
        self.assertEqual(unlink.args, ("POST", "https://api.line.me/user/v1/deauthorize"))
        self.assertEqual(unlink.kwargs["headers"], {"Authorization": "Bearer channel-token"})
        self.assertEqual(unlink.kwargs["json"], {"userAccessToken": "user-token"})

    def test_other_users_token_cannot_be_unlinked(self):
        with patch.object(social_login.requests, "request", side_effect=[self.verify_response(),
            response(body={"sub": "other-user"}),
        ]) as request:
            with self.assertRaises(HTTPException) as error:
                social_login.unlink_line("line-user", "another-token")
            self.assertEqual(error.exception.status_code, 403)
            self.assertEqual(request.call_count, 2)

    def test_unlink_requires_exact_success_response(self):
        with patch.object(social_login, "line_subject", return_value="line-user"):
            for status in (200, 400, 500):
                with self.subTest(status=status), patch.object(social_login.requests, "request", side_effect=[
                    response(body={"access_token": "channel-token"}), response(status),
                ]):
                    with self.assertRaises(HTTPException):
                        social_login.unlink_line("line-user", "user-token")


class LineDatabaseTests(CommunityDatabaseCase):
    def migrate(self):
        path = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_line_login.sql"
        self.execute(path.read_text(encoding="utf-8"))

    def test_migration_preserves_old_identities_sessions_and_unique_constraints(self):
        for provider in ("google", "apple", "kakao"):
            self.execute("INSERT INTO user_social_identities VALUES (%s,'same-subject',%s)", (provider, self.a))
        original = self.execute("SELECT * FROM user_social_identities ORDER BY provider,subject")
        verify_schema(before=True, print_report=False)
        self.migrate()
        verify_schema(before=False, print_report=False)
        self.assertEqual(self.execute("SELECT * FROM user_social_identities ORDER BY provider,subject"), original)
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 200)
        session = auth_repo.login_social("line", "same-subject")
        self.assertNotEqual(auth_repo.session_user(session["access_token"])["user_id"], self.a)
        with self.assertRaises(AssertionError):
            verify_schema(before=True, print_report=False)

    def test_login_repeat_recovery_and_rejected_provider_share_existing_account_rules(self):
        self.migrate()
        with patch.object(social_login, "line_subject", return_value="line-user"):
            body = {"access_token": "test-user-token"}
            found = self.client.post("/v1/auth/line?find_username=true", json=body)
            self.assertEqual(found.status_code, 404)
            self.assertEqual(self.execute("SELECT * FROM user_social_identities"), [])
            first = self.client.post("/v1/auth/line", json=body)
            again = self.client.post("/v1/auth/line", json=body)
            self.assertEqual(first.status_code, 200)
            account = auth_repo.session_user(first.json()["access_token"])
            self.assertEqual(auth_repo.session_user(again.json()["access_token"])["user_id"], account["user_id"])
            self.assertIsNone(account["username"])
            self.execute("UPDATE users SET username='line-member' WHERE user_id=%s", (account["user_id"],))
            sessions = self.execute("SELECT COUNT(*) AS count FROM user_sessions")
            self.assertEqual(self.client.post("/v1/auth/line?find_username=true", json=body).json(), {"username": "line-member"})
            self.assertEqual(self.execute("SELECT COUNT(*) AS count FROM user_sessions"), sessions)
            self.assertEqual(self.execute("SELECT * FROM user_email_credentials WHERE user_id=%s", (account["user_id"],)), [])
        with patch.object(social_login, "line_subject", side_effect=HTTPException(401, "rejected")):
            self.assertEqual(self.client.post("/v1/auth/line", json=body).status_code, 401)
        self.assertEqual(self.execute("SELECT COUNT(*) AS count FROM user_sessions"), sessions)
        self.assertEqual(self.client.post("/v1/auth/line", json={"access_token": ""}).status_code, 422)

    def test_deletion_keeps_account_on_unlink_failure_and_anonymizes_after_success(self):
        self.migrate()
        self.execute("INSERT INTO user_social_identities VALUES ('line','line-user',%s)", (self.a,))
        post = self.post()
        self.assertEqual(self.request("DELETE", "/v1/users/me").status_code, 400)
        proof = {"line": {"access_token": "fresh-user-token"}}
        with patch.object(social_login, "unlink_line", side_effect=HTTPException(503, "provider down")):
            self.assertEqual(self.request("DELETE", "/v1/users/me", json=proof).status_code, 503)
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 200)
        with patch.object(social_login, "unlink_line") as unlink:
            self.assertEqual(self.request("DELETE", "/v1/users/me", json=proof).status_code, 200)
            unlink.assert_called_once_with("line-user", access_token="fresh-user-token")
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 401)
        self.assertEqual(self.execute("SELECT * FROM user_social_identities"), [])
        self.assertIsNone(self.execute("SELECT user_id FROM posts WHERE post_id=%s", (post,))[0]["user_id"])


if __name__ == "__main__":
    unittest.main()
