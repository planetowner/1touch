"""임시 환경 파일로 Google ID 추가 시 기존 연결 정보가 유지되는지 확인해요."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from dotenv import dotenv_values

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import configure_google


class ConfigureGoogleTests(unittest.TestCase):
    def test_add_and_repeat_preserve_existing_connections_and_client(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env"
            connections = "# keep\nDB_HOST=private-db\nSES_SMTP_PASSWORD='smtp$secret'\nR2_SECRET_ACCESS_KEY='r2-secret'\nAUTH_CODE_SECRET='auth-secret'\n"
            env_file.write_text(connections + "GOOGLE_CLIENT_IDS='existing.apps.googleusercontent.com'\n", encoding="utf-8")
            for _ in range(2):
                self.assertEqual(configure_google.configure_google(env_file, "new.apps.googleusercontent.com"), 2)
            self.assertTrue(env_file.read_text(encoding="utf-8").startswith(connections))
            self.assertEqual(dotenv_values(env_file)["GOOGLE_CLIENT_IDS"],
                             "existing.apps.googleusercontent.com,new.apps.googleusercontent.com")
            self.assertEqual(env_file.read_text(encoding="utf-8").count("GOOGLE_CLIENT_IDS="), 1)

    def test_non_client_id_does_not_modify_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env"
            env_file.write_text("DB_HOST=private-db\n", encoding="utf-8")
            before = env_file.read_bytes()
            with self.assertRaises(ValueError):
                configure_google.configure_google(env_file, "new.apps.googleusercontent.com,not-a-client-id")
            self.assertEqual(env_file.read_bytes(), before)

    def test_export_and_server_apply_only_transfer_google_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, exported, target = root / "local.env", root / "google.env", root / "server.env"
            source.write_text("DB_HOST=local-db\nR2_SECRET_ACCESS_KEY=local-secret\nGOOGLE_CLIENT_IDS=new.apps.googleusercontent.com\n", encoding="utf-8")
            exported.touch()
            target.write_text("DB_HOST=server-db\nR2_SECRET_ACCESS_KEY=server-secret\nGOOGLE_CLIENT_IDS=existing.apps.googleusercontent.com\n", encoding="utf-8")
            for origin, destination in ((source, exported), (exported, target)):
                args = ["/input/configure_google.py", "--from-env", str(origin), "--env-file", str(destination)]
                with patch("sys.argv", args), patch.object(configure_google, "__file__", "/input/configure_google.py"), contextlib.redirect_stdout(io.StringIO()):
                    configure_google.main()
            self.assertEqual(dotenv_values(exported), {"GOOGLE_CLIENT_IDS": "new.apps.googleusercontent.com"})
            self.assertEqual(dotenv_values(target), {
                "DB_HOST": "server-db", "R2_SECRET_ACCESS_KEY": "server-secret",
                "GOOGLE_CLIENT_IDS": "existing.apps.googleusercontent.com,new.apps.googleusercontent.com",
            })


if __name__ == "__main__":
    unittest.main()
