"""실제 키·환경 파일 대신 임시 파일로 설정 보존과 재실행을 확인해요."""
import contextlib
import csv
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from dotenv import dotenv_values

SPEC = importlib.util.spec_from_file_location("configure_ses", Path(__file__).resolve().parents[1] / "configure_ses.py")
configure_ses = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(configure_ses)


class ConfigureSesTests(unittest.TestCase):
    def test_explicit_environment_path_works_at_server_mount_location(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env.production"
            env_file.write_text("API_DOMAIN=api.example.test\n", encoding="utf-8")
            credentials = Path(directory) / "smtp.csv"
            credentials.write_text("IAM 사용자 이름,SMTP 사용자 이름,SMTP 비밀번호\n1touch-auth-smtp,test-user,test-password\n", encoding="utf-8")
            # 실제 서버의 /input/configure_ses.py에는 parents[2]가 없어요.
            mounted_script = Path(directory).anchor + "input/configure_ses.py"
            arguments = [mounted_script, "--credentials-csv", str(credentials), "--env-file", str(env_file),
                         "--from-email", "noreply@auth.1touch.football"]
            output = io.StringIO()
            with patch.object(configure_ses, "__file__", mounted_script), patch("sys.argv", arguments), contextlib.redirect_stdout(output):
                configure_ses.main()
            settings = dotenv_values(env_file)
            self.assertEqual(settings["SES_SMTP_USERNAME"], "test-user")
            self.assertNotIn("test-password", output.getvalue())

    def test_preserves_other_settings_and_secret_on_repeat_without_printing_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env"
            credentials = Path(directory) / "smtp.csv"
            original = "# 기존 설정\nDB_HOST=127.0.0.1\nCOLLAB_PASSWORD_HASH='$test$value'\n"
            env_file.write_text(original, encoding="utf-8")
            with credentials.open("w", encoding="utf-8-sig", newline="") as stream:
                writer = csv.writer(stream)
                writer.writerow(["IAM 사용자 이름", "SMTP 사용자 이름", "SMTP 비밀번호"])
                writer.writerow(["1touch-auth-smtp", "test-smtp-user", "test-smtp-password"])
            output = io.StringIO()
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                configure_ses.configure_ses(credentials, env_file, "noreply@auth.1touch.football")
                first = dotenv_values(env_file, interpolate=False)
                configure_ses.configure_ses(credentials, env_file, "noreply@auth.1touch.football")
            self.assertEqual(output.getvalue(), "")
            self.assertTrue(env_file.read_text(encoding="utf-8").startswith(original))
            self.assertEqual(dotenv_values(env_file, interpolate=False), first)
            self.assertGreaterEqual(len(first["AUTH_CODE_SECRET"]), 32)
            self.assertEqual(first["SES_SMTP_PASSWORD"], "test-smtp-password")
            self.assertEqual(first["SES_SMTP_HOST"], "email-smtp.ap-northeast-2.amazonaws.com")

    def test_old_account_csv_does_not_modify_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env"
            credentials = Path(directory) / "account.csv"
            env_file.write_text("DB_HOST=127.0.0.1\n", encoding="utf-8")
            original = env_file.read_bytes()
            credentials.write_text("Root User Email\ntest@example.com\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                configure_ses.configure_ses(credentials, env_file, "noreply@auth.1touch.football")
            self.assertEqual(env_file.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
