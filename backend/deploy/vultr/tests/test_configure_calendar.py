import json
from pathlib import Path
import sys
import tempfile
import unittest

from cryptography.fernet import Fernet
from dotenv import dotenv_values

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from configure_calendar import configure_calendar


class CalendarSettingsTests(unittest.TestCase):
    def test_preserves_existing_settings_and_encryption_key_on_reapply(self):
        with tempfile.TemporaryDirectory() as folder:
            env, client = Path(folder) / '.env', Path(folder) / 'client.json'
            env.write_text('DB_HOST=existing-db\nGOOGLE_CLIENT_IDS=web.apps.googleusercontent.com\n')
            client.write_text(json.dumps({'web': {'client_id': 'web.apps.googleusercontent.com', 'client_secret': 'secret'}}))
            configure_calendar(env, client)
            first = dotenv_values(env)
            encrypted = Fernet(first['CALENDAR_TOKEN_ENCRYPTION_KEY'].encode()).encrypt(b'refresh')
            configure_calendar(env, client)
            second = dotenv_values(env)
            self.assertEqual(first, second)
            self.assertEqual(second['DB_HOST'], 'existing-db')
            self.assertEqual(Fernet(second['CALENDAR_TOKEN_ENCRYPTION_KEY'].encode()).decrypt(encrypted), b'refresh')

    def test_rejects_a_different_web_client_without_modifying_settings(self):
        with tempfile.TemporaryDirectory() as folder:
            env, client = Path(folder) / '.env', Path(folder) / 'client.json'
            original = 'GOOGLE_CLIENT_IDS=existing.apps.googleusercontent.com\n'
            env.write_text(original)
            client.write_text(json.dumps({'web': {'client_id': 'other.apps.googleusercontent.com', 'client_secret': 'secret'}}))
            with self.assertRaises(ValueError):
                configure_calendar(env, client)
            self.assertEqual(env.read_text(), original)


if __name__ == '__main__':
    unittest.main()
