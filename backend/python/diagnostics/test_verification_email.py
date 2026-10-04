"""실제 메일·운영 DB 없이 확정 문구, MIME 본문, 요청 언어 전달을 확인해요."""
from email import policy
from email.parser import BytesParser
import os
import unittest
from unittest.mock import patch

from bs4 import BeautifulSoup
from fastapi import FastAPI
from fastapi.testclient import TestClient

from one_touch_loader.api.services import email_sender, verification_email

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.repos import auth_repo
    from one_touch_loader.api.routes.auth import router


SETTINGS = {
    "SES_SMTP_HOST": "smtp.test", "SES_SMTP_USERNAME": "test-user", "SES_SMTP_PASSWORD": "test-password",
    "SES_FROM_EMAIL": "noreply@example.com", "SES_FEEDBACK_EMAIL": "operator@example.com",
    "AUTH_CODE_SECRET": "test-secret-" * 4,
}


HEADINGS = {
    "ko": ("이메일 인증번호", "1touch 인증번호예요", "이 인증번호를 요청한 적이 없다면 이 이메일은 무시해도 돼요."),
    "en": ("Email Verification Code", "Your 1touch code is",
           "If you didn't request this verification code, you can ignore this email."),
    "ja": ("メール認証コード", "1touchの認証コードです",
           "この認証コードに心当たりがない場合は、このメールを無視してかまいません。"),
    "zh": ("邮箱验证码", "这是你的1touch验证码", "如果你没有申请此验证码，可以忽略这封邮件。"),
}


class VerificationEmailTests(unittest.TestCase):
    def test_approved_copy_survives_mime_encoding_for_every_purpose_and_language(self):
        instructions = {
            "ko": {
                "signup": "회원가입을 계속하려면 10분 안에 이 번호를 입력해 주세요.",
                "password_reset": "비밀번호를 다시 설정하려면 10분 안에 이 번호를 입력해 주세요.",
                "username_recovery": "아이디를 찾으려면 10분 안에 이 번호를 입력해 주세요.",
                "email_change": "이메일 주소를 바꾸려면 10분 안에 이 번호를 입력해 주세요.",
            },
            "en": {
                "signup": "To continue signing up, enter this code within 10 minutes.",
                "password_reset": "To reset your password, enter this code within 10 minutes.",
                "username_recovery": "To find your username, enter this code within 10 minutes.",
                "email_change": "To change your email address, enter this code within 10 minutes.",
            },
            "ja": {
                "signup": "新規登録を続けるには、10分以内にこのコードを入力してください。",
                "password_reset": "パスワードを再設定するには、10分以内にこのコードを入力してください。",
                "username_recovery": "ユーザー名を確認するには、10分以内にこのコードを入力してください。",
                "email_change": "メールアドレスを変更するには、10分以内にこのコードを入力してください。",
            },
            "zh": {
                "signup": "要继续注册，请在10分钟内输入此验证码。",
                "password_reset": "要重置密码，请在10分钟内输入此验证码。",
                "username_recovery": "要找回用户名，请在10分钟内输入此验证码。",
                "email_change": "要更改邮箱地址，请在10分钟内输入此验证码。",
            },
        }
        for language, purposes in instructions.items():
            title, label, ignore = HEADINGS[language]
            for purpose, instruction in purposes.items():
                with self.subTest(language=language, purpose=purpose), patch.dict(os.environ, SETTINGS), \
                        patch.object(email_sender.smtplib, "SMTP") as smtp:
                    email_sender.send_verification_code("member@example.com", "012345", purpose, language)
                    sent = smtp.return_value.__enter__.return_value.send_message.call_args.args[0]
                    message = BytesParser(policy=policy.default).parsebytes(sent.as_bytes(policy=policy.SMTP))
                    self.assertEqual(message["Subject"], title)
                    self.assertEqual(message.get_content_type(), "multipart/alternative")
                    plain = message.get_body(preferencelist=("plain",)).get_content().replace("\r\n", "\n")
                    self.assertEqual(plain, f"{label}\n012345\n\n{instruction}\n\n{ignore}\n")
                    html = message.get_body(preferencelist=("html",)).get_content()
                    document = BeautifulSoup(html, "html.parser")
                    self.assertEqual(document.html["lang"], language)
                    self.assertEqual(document.h1.get_text(), title)
                    self.assertEqual(document.select_one(".verification-code").get_text(), "012345")
                    for text in (label, instruction, ignore):
                        self.assertIn(text, document.get_text())
                    images = {part["Content-ID"].strip("<>"): part for part in message.walk()
                              if part.get_content_maintype() == "image"}
                    self.assertEqual({img["src"] for img in document.find_all("img")},
                                     {f"cid:{cid}" for cid in images})
                    self.assertEqual(len(images), 3)
                    for part in images.values():
                        self.assertEqual(part.get_content_disposition(), "inline")
                        self.assertTrue(part.get_payload(decode=True).startswith(b"\x89PNG\r\n\x1a\n"))
                    self.assertNotIn("figma.com", html)
                    self.assertEqual(document.find_all("a"), [])

    def test_expiry_copy_uses_the_code_lifetime_setting(self):
        with patch.object(verification_email, "CODE_LIFETIME_MINUTES", 7):
            for language, expected in (("ko", "7분 안에"), ("en", "within 7 minutes"),
                                       ("ja", "7分以内"), ("zh", "7分钟内")):
                _, plain, html = verification_email.render_verification_email("012345", "signup", language)
                self.assertIn(expected, plain)
                self.assertIn(expected, html)


class VerificationEmailRequestTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(patch.dict(os.environ, SETTINGS))
        self.smtp = self.enterContext(patch.object(email_sender.smtplib, "SMTP"))
        self.enterContext(patch.object(auth_repo, "transaction"))
        self.enterContext(patch.object(auth_repo, "rate_limit"))
        self.enterContext(patch.object(auth_repo, "_lock_email_account", return_value={"email": "old@example.com"}))
        app = FastAPI()
        app.dependency_overrides[get_user_id] = lambda: 7
        app.include_router(router, prefix="/v1")
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def sent_messages(self):
        return [call.args[0] for call in self.smtp.return_value.__enter__.return_value.send_message.call_args_list]

    def test_signup_reset_and_username_requests_deliver_the_requested_language(self):
        for language in HEADINGS:
            for purpose in ("signup", "password_reset", "username_recovery"):
                with self.subTest(language=language, purpose=purpose):
                    response = self.client.post("/v1/auth/email/code", json={
                        "email": "member@example.com", "purpose": purpose, "language": language})
                    self.assertEqual(response.status_code, 200, response.text)
                    self.assertEqual(response.json()["expires_in"], 600)
                    expected = HEADINGS[language][0]
                    self.assertEqual(self.sent_messages()[-1]["Subject"], expected)

    def test_email_change_sends_both_addresses_the_same_language_and_distinct_codes(self):
        for language in HEADINGS:
            with self.subTest(language=language), patch.object(auth_repo.secrets, "randbelow", side_effect=[12345, 987654]):
                response = self.client.post("/v1/users/me/email/code", json={
                    "email": "new@example.com", "password": "Password123", "language": language})
                self.assertEqual(response.status_code, 200, response.text)
                messages = self.sent_messages()[-2:]
                self.assertEqual([message["To"] for message in messages], ["old@example.com", "new@example.com"])
                for message, code in zip(messages, ("012345", "987654")):
                    expected = HEADINGS[language][0]
                    self.assertEqual(message["Subject"], expected)
                    self.assertIn(code, message.get_body(preferencelist=("plain",)).get_content())

    def test_existing_clients_without_language_keep_english(self):
        response = self.client.post("/v1/auth/email/code", json={"email": "member@example.com"})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(self.sent_messages()[-1]["Subject"], "Email Verification Code")
        response = self.client.post("/v1/users/me/email/code", json={
            "email": "new@example.com", "password": "Password123"})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertTrue(all(message["Subject"] == "Email Verification Code" for message in self.sent_messages()))

    def test_untranslated_language_is_rejected_before_sending(self):
        for path, body in (("/v1/auth/email/code", {"email": "member@example.com"}),
                           ("/v1/users/me/email/code", {"email": "new@example.com", "password": "Password123"})):
            response = self.client.post(path, json={**body, "language": "fr"})
            self.assertEqual(response.status_code, 422, response.text)
        self.smtp.assert_not_called()


if __name__ == "__main__":
    unittest.main()
