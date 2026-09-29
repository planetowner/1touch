import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from dotenv import dotenv_values

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from configure_fcm import configure_fcm


class FcmSettingsTests(unittest.TestCase):
    def test_service_account_project_and_private_key_are_validated_before_writing(self):
        with tempfile.TemporaryDirectory() as folder:
            env, credentials = Path(folder) / '.env', Path(folder) / 'account.json'
            env.write_text('DB_HOST=existing-db\n')
            key = rsa.generate_private_key(public_exponent=65537, key_size=2048).private_bytes(
                serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()
            account = {'type': 'service_account', 'project_id': 'touch-42626',
                       'client_email': 'test@touch-42626.iam.gserviceaccount.com', 'private_key': key}
            credentials.write_text(json.dumps(account))
            with self.assertRaises(ValueError):
                configure_fcm(env, credentials, 'another-project')
            self.assertEqual(env.read_text(), 'DB_HOST=existing-db\n')
            configure_fcm(env, credentials, 'touch-42626')
            saved = dotenv_values(env, interpolate=False)
            self.assertEqual(saved['DB_HOST'], 'existing-db')
            self.assertEqual(saved['FCM_PRIVATE_KEY'].replace('\\n', '\n'), key)
            before = env.read_text()
            credentials.write_text(json.dumps({**account, 'private_key': 'not-a-key'}))
            with self.assertRaises(ValueError):
                configure_fcm(env, credentials, 'touch-42626')
            self.assertEqual(env.read_text(), before)

    def test_manual_commands_preserve_readonly_default_and_arguments(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(__file__).resolve().parents[1]
            target = Path(folder)
            shutil.copy2(source / 'sync-notifications.sh', target)
            (target / 'compose-production.sh').write_text('printf "%s\\n" "$@"\n')
            for task in ('schedule', 'push'):
                for options in ([], ['--apply']):
                    result = subprocess.run(['bash', 'sync-notifications.sh', task, *options], cwd=target,
                                            capture_output=True, text=True, check=True)
                    self.assertEqual(result.stdout.splitlines(), ['run', '--rm', '--no-deps', '-T', 'api',
                        'python', '-m', 'one_touch_loader.loaders.notifications', task, *options])


if __name__ == '__main__':
    unittest.main()
