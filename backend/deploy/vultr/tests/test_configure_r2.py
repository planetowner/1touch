"""실제 키 대신 임시 환경 파일로 R2 설정 보존과 숨김 입력을 검사해요."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from dotenv import dotenv_values

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import configure_r2


class ConfigureR2Tests(unittest.TestCase):
    settings = dict(zip(configure_r2.R2_KEYS, ("test-account", "test-bucket", "test-access", "test-secret")))

    def test_prompt_and_repeat_preserve_database_smtp_and_auth_secret(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env"
            original = "# keep\nDB_HOST=private-db\nSES_SMTP_PASSWORD='smtp$secret'\nAUTH_CODE_SECRET='auth-secret'\n"
            env_file.write_text(original, encoding="utf-8")
            output = io.StringIO()
            args = ["configure_r2.py", "--env-file", str(env_file), "--prompt", "--account-id", "test-account", "--bucket", "test-bucket"]
            with patch("sys.argv", args), patch.object(configure_r2, "getpass", side_effect=["test-access", "test-secret"]), contextlib.redirect_stdout(output):
                configure_r2.main()
                configure_r2.configure_r2(env_file, self.settings)
            self.assertTrue(env_file.read_text(encoding="utf-8").startswith(original))
            self.assertEqual(configure_r2.r2_settings(env_file), self.settings)
            self.assertNotIn("test-secret", output.getvalue())
            self.assertNotIn("test-access", output.getvalue())
            self.assertEqual(env_file.read_text(encoding="utf-8").count("R2_BUCKET="), 1)

    def test_server_apply_only_copies_r2_values(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, target = root / "r2.env", root / ".env.production"
            source.write_text("DB_HOST=local-db\n" + "\n".join(f"{key}='{value}'" for key, value in self.settings.items()), encoding="utf-8")
            target.write_text("DB_HOST=server-db\nAPI_DOMAIN=api.example.test\n", encoding="utf-8")
            args = ["/input/configure_r2.py", "--env-file", str(target), "--from-env", str(source)]
            with patch("sys.argv", args), patch.object(configure_r2, "__file__", "/input/configure_r2.py"), contextlib.redirect_stdout(io.StringIO()):
                configure_r2.main()
            self.assertEqual(dotenv_values(target)["DB_HOST"], "server-db")
            self.assertEqual(configure_r2.r2_settings(target), self.settings)

    def test_missing_secret_leaves_environment_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / ".env"
            target.write_text("DB_HOST=server-db\n", encoding="utf-8")
            original = target.read_bytes()
            with self.assertRaises(ValueError):
                configure_r2.configure_r2(target, {**self.settings, "R2_SECRET_ACCESS_KEY": ""})
            self.assertEqual(target.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
