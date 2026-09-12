"""카카오 설정을 옮길 때 다른 서비스의 연결 정보가 유지되는지 확인해요."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from dotenv import dotenv_values

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import configure_kakao


class ConfigureKakaoTests(unittest.TestCase):
    def test_prompt_rest_key_preserves_connections_and_is_not_printed(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / '.env'
            original = "DB_HOST=server-db\nAPPLE_CLIENT_IDS=existing-apple\n"
            env_file.write_text(original, encoding="utf-8")
            key = "0123456789abcdef" * 2
            output = io.StringIO()
            with patch.object(configure_kakao, "getpass", return_value=key), patch.object(sys, "argv", [
                "configure_kakao.py", "--app-id", "123456", "--prompt-rest-api-key", "--env-file", str(env_file),
            ]), contextlib.redirect_stdout(output):
                configure_kakao.main()
            self.assertNotIn(key, output.getvalue())
            self.assertEqual(dotenv_values(env_file)["KAKAO_REST_API_KEY"], key)
            configure_kakao.configure_kakao(env_file, "123456")
            self.assertEqual(dotenv_values(env_file)["KAKAO_REST_API_KEY"], key)
            self.assertTrue(env_file.read_text(encoding="utf-8").startswith(original))
            before = env_file.read_bytes()
            with self.assertRaises(ValueError):
                configure_kakao.configure_kakao(env_file, "123456", "wrong-format")
            self.assertEqual(env_file.read_bytes(), before)

    def test_repeat_preserves_other_services_and_comments(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env"
            original = "# keep\nDB_HOST=private-db\nSES_SMTP_PASSWORD='smtp$secret'\nGOOGLE_CLIENT_IDS=existing-google\nAPPLE_CLIENT_IDS=com.example.football\nR2_SECRET_ACCESS_KEY=r2-secret\n"
            env_file.write_text(original, encoding="utf-8")
            for _ in range(2):
                configure_kakao.configure_kakao(env_file, "123456")
            self.assertTrue(env_file.read_text(encoding="utf-8").startswith(original))
            self.assertEqual(dotenv_values(env_file)["KAKAO_APP_ID"], "123456")
            self.assertEqual(env_file.read_text(encoding="utf-8").count("KAKAO_APP_ID="), 1)

    def test_app_key_or_missing_id_does_not_modify_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env"
            env_file.write_text("DB_HOST=private-db\n", encoding="utf-8")
            before = env_file.read_bytes()
            for invalid in ("", "example-native-key", "123456,789012"):
                with self.subTest(value=invalid), self.assertRaises(ValueError):
                    configure_kakao.configure_kakao(env_file, invalid)
                self.assertEqual(env_file.read_bytes(), before)

    def test_export_and_server_apply_transfer_only_app_id(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, exported, target = root / "local.env", root / "kakao.env", root / "server.env"
            key = "0123456789abcdef" * 2
            source.write_text(f"DB_HOST=local-db\nKAKAO_APP_ID=123456\nKAKAO_REST_API_KEY={key}\nR2_SECRET_ACCESS_KEY=local-secret\n", encoding="utf-8")
            exported.touch()
            target.write_text("DB_HOST=server-db\nKAKAO_APP_ID=789012\nR2_SECRET_ACCESS_KEY=server-secret\n", encoding="utf-8")
            for origin, destination in ((source, exported), (exported, target)):
                output = io.StringIO()
                with patch.object(sys, "argv", ["configure_kakao.py", "--from-env", str(origin),
                                               "--env-file", str(destination)]), contextlib.redirect_stdout(output):
                    configure_kakao.main()
                self.assertNotIn("local-secret", output.getvalue())
                self.assertNotIn("server-secret", output.getvalue())
                self.assertNotIn(key, output.getvalue())
            self.assertEqual(dotenv_values(exported), {"KAKAO_APP_ID": "123456", "KAKAO_REST_API_KEY": key})
            self.assertEqual(dotenv_values(target), {
                "DB_HOST": "server-db", "KAKAO_APP_ID": "123456", "R2_SECRET_ACCESS_KEY": "server-secret",
                "KAKAO_REST_API_KEY": key,
            })


if __name__ == "__main__":
    unittest.main()
