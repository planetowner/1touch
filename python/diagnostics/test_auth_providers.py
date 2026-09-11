"""실제 계정 없이도 서명·앱 ID·만료·TLS·설정 누락의 인증 경계를 검사해요."""
import os
from types import SimpleNamespace
import time
import unittest
from unittest.mock import Mock, patch
from cryptography.hazmat.primitives.asymmetric import rsa, ec
from cryptography.hazmat.primitives import serialization
from fastapi import HTTPException
import jwt

from one_touch_loader.api.services import auth_security, email_sender, social_login


class ProviderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.public = cls.private.public_key()

    def token(self, **changes):
        claims = {"sub": "verified-user", "iss": "https://accounts.google.com", "aud": "our-app",
                  "iat": int(time.time()), "exp": int(time.time()) + 300}
        claims.update(changes)
        return jwt.encode(claims, self.private, algorithm="RS256", headers={"kid": "test"})

    def test_google_rejects_wrong_signature_audience_issuer_and_expiry(self):
        keys = Mock()
        keys.get_signing_key_from_jwt.return_value = SimpleNamespace(key=self.public)
        with patch.object(social_login, "_keys", return_value=keys), patch.dict(os.environ, {"GOOGLE_CLIENT_IDS": "our-app"}):
            self.assertEqual(social_login.google_subject(self.token()), "verified-user")
            for token in (self.token(aud="other-app"), self.token(iss="https://attacker.example"), self.token(exp=int(time.time()) - 1),
                          jwt.encode({"sub": "fake"}, "not-the-provider-key", algorithm="HS256")):
                with self.assertRaises(HTTPException) as error:
                    social_login.google_subject(token)
                self.assertEqual(error.exception.status_code, 401)

    def test_missing_settings_do_not_allow_test_login(self):
        with patch.dict(os.environ, {"GOOGLE_CLIENT_IDS": ""}):
            with self.assertRaises(HTTPException) as error:
                social_login.google_subject("unverified")
        self.assertEqual(error.exception.status_code, 503)

    def test_kakao_checks_app_and_expiry(self):
        response = {"id": 321, "app_id": 123, "expires_in": 60}
        with patch.dict(os.environ, {"KAKAO_APP_ID": "123"}), patch.object(social_login, "_provider_json", return_value=response):
            self.assertEqual(social_login.kakao_subject("token"), "321")
            response["app_id"] = 124
            with self.assertRaises(HTTPException):
                social_login.kakao_subject("token")
            response.update(app_id=123, expires_in=0)
            with self.assertRaises(HTTPException):
                social_login.kakao_subject("token")

    def kakao_event_token(self, *, header=None, **changes):
        claims = {"iss": "https://kauth.kakao.com", "aud": "our-rest-key", "iat": int(time.time()),
                  "app_id": "123", "sub": "321", "jti": "event-one", "events": {
            "https://schemas.openid.net/secevent/oauth/event-type/user-unlinked": {
                "subject": {"subject_type": "iss-sub", "iss": "https://kauth.kakao.com", "sub": "321"},
                "reason": "UNLINK_FROM_APPS"}}}
        claims.update(changes)
        return jwt.encode(claims, self.private, algorithm="RS256", headers={"kid": "test", "typ": "secevent+jwt", **(header or {})}).encode()

    def test_kakao_event_requires_signature_type_issuer_audience_and_matching_subject(self):
        keys = Mock()
        keys.get_signing_key_from_jwt.return_value = SimpleNamespace(key=self.public)
        settings = {"KAKAO_APP_ID": "123", "KAKAO_REST_API_KEY": "our-rest-key"}
        with patch.dict(os.environ, settings), patch.object(social_login, "_keys", return_value=keys):
            # 실제 SET 규격처럼 exp 없이도 서명을 검증해요.
            self.assertEqual(social_login.kakao_unlink_event(self.kakao_event_token()), ("321", "event-one"))
            for token, code in (
                (b"not-jwt", "invalid_request"),
                (self.kakao_event_token(header={"typ": "JWT"}), "invalid_request"),
                (self.kakao_event_token(iss="https://example.invalid"), "invalid_issuer"),
                (self.kakao_event_token(aud="other-app"), "invalid_audience"),
                (self.kakao_event_token(app_id="124"), "invalid_audience"),
                (self.kakao_event_token(sub="another-member"), "invalid_request"),
                (self.kakao_event_token(events={}), "invalid_request"),
                (self.kakao_event_token(jti=""), "invalid_request"),
            ):
                with self.subTest(error=code), self.assertRaises(HTTPException) as error:
                    social_login.kakao_unlink_event(token)
                self.assertEqual((error.exception.status_code, error.exception.detail["err"]), (400, code))
            keys.get_signing_key_from_jwt.return_value = SimpleNamespace(key=rsa.generate_private_key(public_exponent=65537, key_size=2048).public_key())
            with self.assertRaises(HTTPException) as error:
                social_login.kakao_unlink_event(self.kakao_event_token())
            self.assertEqual(error.exception.detail["err"], "invalid_key")

    def test_kakao_event_key_service_failure_is_retryable(self):
        keys = Mock()
        keys.get_signing_key_from_jwt.side_effect = jwt.PyJWKClientConnectionError("unavailable")
        with patch.dict(os.environ, {"KAKAO_APP_ID": "123", "KAKAO_REST_API_KEY": "our-rest-key"}), patch.object(social_login, "_keys", return_value=keys):
            with self.assertRaises(HTTPException) as error:
                social_login.kakao_unlink_event(self.kakao_event_token())
            self.assertEqual(error.exception.status_code, 503)

    def test_apple_exchanges_one_time_code_and_checks_nonce(self):
        apple_key = ec.generate_private_key(ec.SECP256R1()).private_bytes(serialization.Encoding.PEM,
                    serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()
        settings = {"APPLE_CLIENT_IDS": "our-apple-app", "APPLE_TEAM_ID": "test-team", "APPLE_KEY_ID": "test-key",
                    "APPLE_PRIVATE_KEY": apple_key}
        claims = {"sub": "apple-sub", "nonce": "the-client-nonce"}
        with patch.dict(os.environ, settings), patch.object(social_login, "_provider_json", return_value={"id_token": "signed-token"}) as exchange, patch.object(social_login, "_verify_token", return_value=claims):
            self.assertEqual(social_login.apple_subject("one-use-code", "our-apple-app", "the-client-nonce"), "apple-sub")
            self.assertEqual(exchange.call_args.kwargs["data"]["grant_type"], "authorization_code")
            self.assertNotIn("redirect_uri", exchange.call_args.kwargs["data"])
            with self.assertRaises(HTTPException):
                social_login.apple_subject("one-use-code", "our-apple-app", "wrong-nonce")

    def apple_event_token(self, event_type="consent-revoked", subject="apple-member", **changes):
        claims = {"iss": "https://appleid.apple.com", "aud": "our-apple-app", "iat": int(time.time()),
                  "jti": "event-one", "events": {"type": event_type, "sub": subject, "event_time": int(time.time())}}
        claims.update(changes)
        return jwt.encode(claims, self.private, algorithm="RS256", headers={"kid": "test"})

    def test_apple_events_verify_signatures_audience_and_event_identity_without_exp(self):
        keys = SimpleNamespace(get_signing_key_from_jwt=lambda token: SimpleNamespace(key=self.public))
        with patch.dict(os.environ, {"APPLE_CLIENT_IDS": "our-apple-app"}), patch.object(social_login, "_keys", return_value=keys):
            for event_type in ("consent-revoked", "account-deleted"):
                self.assertEqual(social_login.apple_account_event(self.apple_event_token(event_type)), ("apple-member", "event-one"))
            for event_type in ("email-disabled", "email-enabled"):
                self.assertIsNone(social_login.apple_account_event(self.apple_event_token(event_type)))
            for token in ("not-signed", self.apple_event_token(aud="another-app"),
                          self.apple_event_token(iss="https://example.invalid"), self.apple_event_token(jti=""),
                          self.apple_event_token(events={"type": "consent-revoked", "sub": ""}),
                          self.apple_event_token(events="unverified-event"), self.apple_event_token("unsupported")):
                with self.subTest(token_case=token[:12]), self.assertRaises(HTTPException):
                    social_login.apple_account_event(token)
            wrong_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
            claims = jwt.decode(self.apple_event_token(), options={"verify_signature": False})
            with self.assertRaises(HTTPException):
                social_login.apple_account_event(jwt.encode(claims, wrong_key, algorithm="RS256", headers={"kid": "test"}))

    def test_apple_event_key_outage_does_not_acknowledge_delivery(self):
        keys = Mock()
        keys.get_signing_key_from_jwt.side_effect = jwt.PyJWKClientConnectionError("unavailable")
        with patch.dict(os.environ, {"APPLE_CLIENT_IDS": "our-apple-app"}), patch.object(social_login, "_keys", return_value=keys):
            with self.assertRaises(HTTPException) as error:
                social_login.apple_account_event(self.apple_event_token())
            self.assertEqual(error.exception.status_code, 503)

    def test_code_hash_requires_server_secret_and_binds_challenge(self):
        with patch.dict(os.environ, {"AUTH_CODE_SECRET": "x" * 32}):
            one = auth_security.code_hash("challenge-one", "012345")
            two = auth_security.code_hash("challenge-two", "012345")
            self.assertNotEqual(one, two)
        with patch.dict(os.environ, {"AUTH_CODE_SECRET": ""}):
            with self.assertRaises(HTTPException):
                auth_security.code_hash("challenge-one", "012345")

    def test_apple_unlink_checks_same_subject_and_accepts_empty_200(self):
        claims, tokens = {"sub": "right-account"}, {"access_token": "new-provider-token"}
        response = Mock(status_code=200)
        with patch.object(social_login, "_apple_identity", return_value=(claims, tokens)), patch.object(social_login, "_apple_secret", return_value="secret"), patch.object(social_login.requests, "request", return_value=response) as request:
            with self.assertRaises(HTTPException):
                social_login.unlink_apple("other-account", "code", "client", "nonce")
            request.assert_not_called()
            social_login.unlink_apple("right-account", "code", "client", "nonce")
            self.assertEqual(request.call_args.kwargs["data"]["token_type_hint"], "access_token")
            self.assertEqual(request.call_args.kwargs["data"]["token"], tokens["access_token"])
            response.json.assert_not_called()

    def test_kakao_unlink_cannot_disconnect_another_account(self):
        with patch.object(social_login, "kakao_subject", return_value="one"), patch.object(social_login, "_provider_json") as unlink:
            with self.assertRaises(HTTPException):
                social_login.unlink_kakao("two", "token")
            unlink.assert_not_called()
            social_login.unlink_kakao("one", "token")
            self.assertEqual(unlink.call_args.args[:2], ("POST", "https://kapi.kakao.com/v1/user/unlink"))

    def test_ses_uses_starttls_before_credentials_and_sends_code(self):
        settings = {"SES_SMTP_HOST": "smtp.test", "SES_SMTP_USERNAME": "test-user", "SES_SMTP_PASSWORD": "test-password",
                    "SES_FROM_EMAIL": "noreply@example.com", "SES_FEEDBACK_EMAIL": "operator@example.com"}
        actions = {"signup": "create your account", "password_reset": "reset your password",
                   "username_recovery": "find your 1Touch username", "email_change": "change your account email address"}
        for purpose, action in actions.items():
            with self.subTest(purpose=purpose), patch.dict(os.environ, settings), patch.object(email_sender.smtplib, "SMTP") as smtp:
                email_sender.send_verification_code("receiver@example.com", "012345", purpose)
                client = smtp.return_value.__enter__.return_value
                self.assertEqual([call[0] for call in client.method_calls], ["ehlo", "starttls", "ehlo", "login", "send_message"])
                message = client.send_message.call_args.args[0]
                self.assertEqual(message["To"], "receiver@example.com")
                self.assertEqual(message["From"], "noreply@example.com")
                self.assertEqual(message["Return-Path"], "operator@example.com")
                self.assertIn("012345", message.get_content())
                self.assertIn(action, message.get_content())


if __name__ == '__main__':
    unittest.main()
