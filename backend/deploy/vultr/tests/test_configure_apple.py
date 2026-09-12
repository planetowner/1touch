"""격리 환경과 임시 키로 Apple 설정 보존·전송·서명 검사를 확인해요."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from dotenv import dotenv_values

scripts = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(scripts))
import configure_apple


def _test_pem(curve):
    return ec.generate_private_key(curve).private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption()).decode()


class ConfigureAppleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pem = _test_pem(ec.SECP256R1())
        cls.settings = dict(zip(configure_apple.APPLE_KEYS,
                               ("com.example.football", "TESTTEAM01", "TESTKEY001", cls.pem)))

    def test_file_import_and_repeat_preserve_connections_and_existing_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            private_key = root / "AuthKey_TESTKEY001.p8"
            private_key.write_text(self.pem, encoding="utf-8")
            env_file = root / ".env"
            original = "# keep\nDB_HOST=private-db\nSES_SMTP_PASSWORD='smtp$secret'\nR2_SECRET_ACCESS_KEY=r2-secret\nGOOGLE_CLIENT_IDS=google-id\nAPPLE_WEB_CLIENT_ID=existing-web\n"
            env_file.write_text(original + "APPLE_CLIENT_IDS=com.example.previous\n", encoding="utf-8")
            args = ["configure_apple.py", "--private-key-file", str(private_key),
                    "--client-id", "com.example.football", "--team-id", "TESTTEAM01", "--key-id", "TESTKEY001",
                    "--env-file", str(env_file)]
            output = io.StringIO()
            with patch("sys.argv", args), contextlib.redirect_stdout(output):
                configure_apple.main()
                configure_apple.main()
            contents = env_file.read_text(encoding="utf-8")
            self.assertTrue(contents.startswith(original))
            self.assertEqual(contents.count("APPLE_PRIVATE_KEY="), 1)
            saved = dotenv_values(env_file, interpolate=False)
            self.assertEqual(saved["APPLE_CLIENT_IDS"], "com.example.previous,com.example.football")
            self.assertEqual(saved["APPLE_PRIVATE_KEY"].replace("\\n", "\n"), self.pem.strip())
            self.assertNotIn(self.pem.splitlines()[1], output.getvalue())
            self.assertEqual(private_key.read_text(encoding="utf-8"), self.pem)

    def test_export_and_apply_only_copy_apple_values(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, exported, target = (root / name for name in ("local.env", "apple.env", "server.env"))
            source.write_text("DB_HOST=local-db\nR2_SECRET_ACCESS_KEY=local-r2\n", encoding="utf-8")
            exported.touch()
            target.write_text("DB_HOST=server-db\nGOOGLE_CLIENT_IDS=server-google\nAPPLE_CLIENT_IDS=com.example.previous\n", encoding="utf-8")
            configure_apple.configure_apple(source, self.settings)
            before = source.read_bytes()
            for origin, destination in ((source, exported), (exported, target)):
                args = ["/input/configure_apple.py", "--from-env", str(origin), "--env-file", str(destination)]
                with patch("sys.argv", args), patch.object(configure_apple, "__file__", "/input/configure_apple.py"), contextlib.redirect_stdout(io.StringIO()):
                    configure_apple.main()
            self.assertEqual(set(dotenv_values(exported)), set(configure_apple.APPLE_KEYS))
            saved = dotenv_values(target, interpolate=False)
            self.assertEqual(saved["DB_HOST"], "server-db")
            self.assertEqual(saved["GOOGLE_CLIENT_IDS"], "server-google")
            self.assertEqual(saved["APPLE_CLIENT_IDS"], "com.example.previous,com.example.football")
            self.assertEqual(saved["APPLE_PRIVATE_KEY"], dotenv_values(source, interpolate=False)["APPLE_PRIVATE_KEY"])
            self.assertEqual(source.read_bytes(), before)

    def test_incomplete_or_wrong_file_does_not_modify_environment(self):
        cases = [{**self.settings, key: ""} for key in configure_apple.APPLE_KEYS]
        cases.extend(({**self.settings, "APPLE_PRIVATE_KEY": "not a private key"},
                      {**self.settings, "APPLE_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\n!!bad!!\n-----END PRIVATE KEY-----"},
                      {**self.settings, "APPLE_CLIENT_IDS": "com.example.football,"}))
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env"
            env_file.write_text("DB_HOST=private-db\n", encoding="utf-8")
            before = env_file.read_bytes()
            for settings in cases:
                with self.subTest(fields=[key for key in settings if settings[key] != self.settings[key]]):
                    with self.assertRaises(ValueError):
                        configure_apple.configure_apple(env_file, settings)
                    self.assertEqual(env_file.read_bytes(), before)

    def _server_check(self, selected_settings, saved_settings):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            selected_file, saved_file = root / "apple.env", root / "server.env"
            selected_file.touch()
            saved_file.touch()
            configure_apple.configure_apple(selected_file, selected_settings)
            configure_apple.configure_apple(saved_file, saved_settings)
            # 서버 스크립트의 실제 검사 본문을 임시 경로에서 실행해 서명까지 검증해요.
            code = (scripts / "prepare-apple.sh").read_text(encoding="utf-8").split("<<'PY'\n", 1)[1].split("\nPY\n", 1)[0]
            code = code.replace("'/input/apple.env'", repr(str(selected_file))).replace(
                "'/settings/.env.production'", repr(str(saved_file))).replace("'/input'", repr(str(scripts)))
            output = io.StringIO()
            before = saved_file.read_bytes()
            with contextlib.redirect_stdout(output):
                exec(compile(code, "prepare-apple.sh", "exec"), {})
            self.assertEqual(saved_file.read_bytes(), before)
            self.assertNotIn(self.pem.splitlines()[1], output.getvalue())
            return output.getvalue()

    def test_server_saved_key_can_sign_and_keeps_existing_client(self):
        output = self._server_check(self.settings, {**self.settings, "APPLE_CLIENT_IDS": "com.example.previous,com.example.football"})
        self.assertIn("allowed=2 P-256 signature=valid", output)
        self.assertIn("Real Apple sign-in has not been tested", output)

    def test_server_rejects_mismatched_key(self):
        with self.assertRaisesRegex(SystemExit, "signing settings were not saved correctly"):
            self._server_check(self.settings, {**self.settings, "APPLE_KEY_ID": "OTHERKEY01"})

    def test_server_rejects_wrong_curve(self):
        settings = {**self.settings, "APPLE_PRIVATE_KEY": _test_pem(ec.SECP384R1())}
        with self.assertRaisesRegex(SystemExit, "P-256 private key"):
            self._server_check(settings, settings)


if __name__ == "__main__":
    unittest.main()
