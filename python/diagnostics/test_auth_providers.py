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

    def test_apple_exchanges_one_time_code_and_checks_nonce(self):
        apple_key = ec.generate_private_key(ec.SECP256R1()).private_bytes(serialization.Encoding.PEM,
                    serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()
        settings = {"APPLE_CLIENT_IDS": "our-apple-app", "APPLE_TEAM_ID": "test-team", "APPLE_KEY_ID": "test-key",
                    "APPLE_PRIVATE_KEY": apple_key}
        claims = {"sub": "apple-sub", "nonce": "the-client-nonce"}
        with patch.dict(os.environ, settings), patch.object(social_login, "_provider_json", return_value={"id_token": "signed-token"}) as exchange, patch.object(social_login, "_verify_id_token", return_value=claims):
            self.assertEqual(social_login.apple_subject("one-use-code", "our-apple-app", "the-client-nonce"), "apple-sub")
            self.assertEqual(exchange.call_args.kwargs["data"]["grant_type"], "authorization_code")
            with self.assertRaises(HTTPException):
                social_login.apple_subject("one-use-code", "our-apple-app", "wrong-nonce")

    def test_code_hash_requires_server_secret_and_binds_challenge(self):
        with patch.dict(os.environ, {"AUTH_CODE_SECRET": "x" * 32}):
            one = auth_security.code_hash("challenge-one", "012345")
            two = auth_security.code_hash("challenge-two", "012345")
            self.assertNotEqual(one, two)
        with patch.dict(os.environ, {"AUTH_CODE_SECRET": ""}):
            with self.assertRaises(HTTPException):
                auth_security.code_hash("challenge-one", "012345")

    def test_ses_uses_starttls_before_credentials_and_sends_code(self):
        settings = {"SES_SMTP_HOST": "smtp.test", "SES_SMTP_USERNAME": "test-user", "SES_SMTP_PASSWORD": "test-password",
                    "SES_FROM_EMAIL": "noreply@example.com"}
        with patch.dict(os.environ, settings), patch.object(email_sender.smtplib, "SMTP") as smtp:
            email_sender.send_verification_code("receiver@example.com", "012345", "signup")
            client = smtp.return_value.__enter__.return_value
            self.assertEqual([call[0] for call in client.method_calls], ["ehlo", "starttls", "ehlo", "login", "send_message"])
            message = client.send_message.call_args.args[0]
            self.assertEqual(message["To"], "receiver@example.com")
            self.assertIn("012345", message.get_content())


if __name__ == '__main__':
    unittest.main()
