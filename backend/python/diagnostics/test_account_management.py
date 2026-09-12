"""인증번호는 모의 메일로 받고, 계정 변경·코드 소진은 격리 MySQL에서 확인해요."""
from unittest.mock import patch

from fastapi import HTTPException

from diagnostics.test_user_community import CommunityDatabaseCase
from one_touch_loader.api.repos import auth_repo
from one_touch_loader.api.services import auth_security, social_login
from diagnostics.verify_account_management import verify_schema

PASSWORD = "CurrentPassword123"


class AccountManagementTests(CommunityDatabaseCase):
    def setUp(self):
        super().setUp()
        self.execute("INSERT INTO user_email_credentials VALUES (%s,%s,%s)",
                     (self.a, "alpha@example.com", auth_security.PASSWORDS.hash(PASSWORD)))

    def email_code(self, email, purpose):
        with patch.object(auth_repo, "send_verification_code") as send:
            challenge = auth_repo.request_email_code(email, purpose)
        return {"challenge_id": challenge["challenge_id"], "code": send.call_args.args[1]}

    def change_codes(self, email="new@example.com"):
        with patch.object(auth_repo, "send_verification_code") as send:
            response = self.request("POST", "/v1/users/me/email/code", json={"email": email, "password": PASSWORD})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual([c.args[0] for c in send.call_args_list], ["alpha@example.com", email])
        self.assertTrue(all(c.args[2] == "email_change" for c in send.call_args_list))
        payload = response.json()
        return {"password": PASSWORD, **{key: {"challenge_id": payload[key]["challenge_id"], "code": call.args[1]}
                for key, call in zip(("current_email", "new_email"), send.call_args_list)}}

    def test_username_requires_its_own_single_use_email_code_and_does_not_login(self):
        original_sessions = self.execute("SELECT * FROM user_sessions ORDER BY user_id")
        code = self.email_code("alpha@example.com", "username_recovery")
        response = self.client.post("/v1/auth/email/find-username", json=code)
        self.assertEqual(response.json(), {"username": "alpha"})
        self.assertEqual(self.client.post("/v1/auth/email/find-username", json=code).status_code, 400)
        self.assertEqual(self.execute("SELECT * FROM user_sessions ORDER BY user_id"), original_sessions)

    def test_signup_code_cannot_recover_a_username(self):
        code = self.email_code("alpha@example.com", "signup")
        self.assertEqual(self.client.post("/v1/auth/email/find-username", json=code).status_code, 400)

    def test_missing_email_account_is_disclosed_only_after_verification(self):
        code = self.email_code("unknown@example.com", "username_recovery")
        self.assertEqual(self.client.post("/v1/auth/email/find-username", json=code).status_code, 404)
        self.assertEqual(len(self.execute("SELECT * FROM users")), 3)

    def test_social_login_recovers_existing_profile_without_creating_email_credentials(self):
        self.execute("INSERT INTO user_social_identities VALUES ('google','same-provider-account',%s)", (self.b,))
        with patch.object(social_login, "google_subject", return_value="same-provider-account"):
            response = self.client.post("/v1/auth/google", json={"id_token": "test-token"})
        self.assertEqual(response.status_code, 200)
        member = self.request("GET", "/v1/users/me", response.json()["access_token"]).json()
        self.assertEqual((member["user_id"], member["username"], member["email"]), (self.b, "beta", None))
        self.assertEqual(len(self.execute("SELECT * FROM users")), 3)
        self.assertEqual(len(self.execute("SELECT * FROM user_email_credentials")), 1)

    def test_social_username_finding_does_not_register_unknown_accounts(self):
        original_sessions = self.execute("SELECT * FROM user_sessions ORDER BY user_id")
        bodies = {"google": {"id_token": "test-token"}, "kakao": {"access_token": "test-token"},
                  "apple": {"code": "test-code", "client_id": "test-app", "nonce": "n" * 16}}
        for provider, body in bodies.items():
            with self.subTest(provider=provider), patch.object(social_login, f"{provider}_subject", return_value="unknown"):
                response = self.client.post(f"/v1/auth/{provider}?find_username=true", json=body)
            self.assertEqual(response.status_code, 404)
        self.assertEqual(len(self.execute("SELECT * FROM users")), 3)
        self.assertEqual(self.execute("SELECT * FROM user_social_identities"), [])
        self.assertEqual(self.execute("SELECT * FROM user_sessions ORDER BY user_id"), original_sessions)

    def test_social_username_finding_returns_current_username_without_a_session(self):
        self.execute("INSERT INTO user_social_identities VALUES ('google','existing-subject',%s)", (self.b,))
        original_sessions = self.execute("SELECT * FROM user_sessions ORDER BY user_id")
        with patch.object(social_login, "google_subject", return_value="existing-subject"):
            response = self.client.post("/v1/auth/google?find_username=true", json={"id_token": "test-token"})
        self.assertEqual(response.json(), {"username": "beta"})
        self.assertEqual(self.execute("SELECT * FROM user_sessions ORDER BY user_id"), original_sessions)

    def test_email_change_requires_session_current_password_and_email_account(self):
        body = {"email": "new@example.com", "password": PASSWORD}
        with patch.object(auth_repo, "send_verification_code") as send:
            self.assertEqual(self.client.post("/v1/users/me/email/code", json=body).status_code, 401)
            self.assertEqual(self.request("POST", "/v1/users/me/email/code", json={**body, "password": "WrongPassword123"}).status_code, 401)
            self.assertEqual(self.request("POST", "/v1/users/me/email/code", self.token_b, json=body).status_code, 403)
            self.assertEqual(self.client.post("/v1/auth/email/code", json={"email": body["email"], "purpose": "email_change"}).status_code, 422)
            send.assert_not_called()

    def test_both_codes_change_only_email_and_invalidate_old_sessions_and_recovery_codes(self):
        old_recovery = self.email_code("alpha@example.com", "password_reset")
        # 메일당 제한 시간을 실제로 기다리지 않고, 시간 경과만 모사해요.
        self.execute("DELETE FROM api_rate_limits")
        original_user = self.execute("SELECT * FROM users WHERE user_id=%s", (self.a,))[0]
        original_hash = self.execute("SELECT password_hash FROM user_email_credentials WHERE user_id=%s", (self.a,))[0]
        body = self.change_codes()
        self.assertEqual(self.execute("SELECT email FROM user_email_credentials WHERE user_id=%s", (self.a,))[0]["email"], "alpha@example.com")
        self.assertEqual(self.request("PUT", "/v1/users/me/email", json=body).status_code, 200)
        self.assertEqual(self.execute("SELECT * FROM users WHERE user_id=%s", (self.a,))[0], original_user)
        self.assertEqual(self.execute("SELECT password_hash FROM user_email_credentials WHERE user_id=%s", (self.a,))[0], original_hash)
        self.assertEqual(self.execute("SELECT email FROM user_email_credentials WHERE user_id=%s", (self.a,))[0]["email"], "new@example.com")
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 401)
        self.assertEqual(self.execute("SELECT * FROM email_verification_codes"), [])
        response = self.client.post("/v1/auth/email/reset-password", json={**old_recovery, "password": "ChangedPassword123"})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(self.client.post("/v1/auth/login", json={"username": "alpha", "password": PASSWORD}).status_code, 200)

    def test_wrong_new_code_keeps_current_code_for_retry_and_counts_failure(self):
        body = self.change_codes()
        wrong = "000000" if body["new_email"]["code"] != "000000" else "111111"
        invalid = {**body, "new_email": {**body["new_email"], "code": wrong}}
        self.assertEqual(self.request("PUT", "/v1/users/me/email", json=invalid).status_code, 400)
        self.assertEqual([r["attempts"] for r in self.execute("SELECT attempts FROM email_verification_codes")], [1, 1])
        self.assertEqual(self.request("PUT", "/v1/users/me/email", json=body).status_code, 200)

    def test_verified_other_account_address_and_same_code_twice_cannot_change_email(self):
        other = self.email_code("other@example.com", "email_change")
        new = self.email_code("new@example.com", "email_change")
        body = {"password": PASSWORD, "current_email": other, "new_email": new}
        self.assertEqual(self.request("PUT", "/v1/users/me/email", json=body).status_code, 400)
        self.execute("DELETE FROM api_rate_limits")
        valid = self.change_codes("fresh@example.com")
        valid["new_email"] = valid["current_email"]
        self.assertEqual(self.request("PUT", "/v1/users/me/email", json=valid).status_code, 400)
        self.assertEqual(self.execute("SELECT email FROM user_email_credentials WHERE user_id=%s", (self.a,))[0]["email"], "alpha@example.com")

    def test_existing_destination_email_rolls_back_and_preserves_session(self):
        self.execute("INSERT INTO user_email_credentials VALUES (%s,%s,%s)", (self.b, "taken@example.com", auth_security.PASSWORDS.hash(PASSWORD)))
        body = self.change_codes("taken@example.com")
        self.assertEqual(self.request("PUT", "/v1/users/me/email", json=body).status_code, 409)
        self.assertEqual(self.request("GET", "/v1/users/me").json()["email"], "alpha@example.com")
        self.assertEqual(len(self.execute("SELECT * FROM email_verification_codes")), 2)

    def test_second_mail_failure_keeps_original_email_and_rolls_back_both_new_codes(self):
        with patch.object(auth_repo, "send_verification_code", side_effect=[None, HTTPException(502, "test delivery failed")]):
            response = self.request("POST", "/v1/users/me/email/code", json={"email": "new@example.com", "password": PASSWORD})
        self.assertEqual(response.status_code, 502)
        self.assertEqual(self.execute("SELECT * FROM email_verification_codes"), [])
        self.assertEqual(self.request("GET", "/v1/users/me").json()["email"], "alpha@example.com")

    def test_profile_edit_without_timezone_keeps_email_and_changes_login_username(self):
        response = self.request("PUT", "/v1/users/me/profile", json={"username": "changed", "last_name": "정", "first_name": "준"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["email"], "alpha@example.com")
        self.assertNotIn("timezone", response.json())
        self.assertEqual(self.client.post("/v1/auth/login", json={"username": "changed", "password": PASSWORD}).status_code, 200)
        self.assertEqual(self.client.post("/v1/auth/login", json={"username": "alpha", "password": PASSWORD}).status_code, 401)


class AccountMigrationTests(CommunityDatabaseCase):
    account_management_schema = False

    def test_existing_members_credentials_sessions_and_codes_survive(self):
        self.execute("UPDATE users SET timezone='Asia/Seoul' WHERE user_id=%s", (self.a,))
        self.execute("INSERT INTO user_email_credentials VALUES (%s,%s,%s)", (self.a, "alpha@example.com", auth_security.PASSWORDS.hash(PASSWORD)))
        with patch.object(auth_repo, "send_verification_code"):
            auth_repo.request_email_code("alpha@example.com", "password_reset")
        tables = ("users", "user_email_credentials", "user_sessions", "email_verification_codes", "user_following_teams")
        before = {table: self.execute(f"SELECT * FROM {table}") for table in tables}
        verify_schema(before=True)
        self.apply_account_management_schema()
        verify_schema(before=False)
        for table, original in before.items():
            expected = [{key: value for key, value in row.items() if key != "timezone"} for row in original]
            self.assertEqual(self.execute(f"SELECT * FROM {table}"), expected, table)
