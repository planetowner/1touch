"""운영자 설정이 다른 연결 정보를 바꾸거나 전송하지 않는지 확인해요."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from dotenv import dotenv_values

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import configure_community


class ConfigureCommunityTests(unittest.TestCase):
    def test_repeat_and_changed_admin_preserve_credentials_and_comments(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '.env'
            original = "# keep\nDB_PASSWORD='db-secret'\nR2_SECRET_ACCESS_KEY='r2-secret'\n"
            path.write_text(original, encoding='utf-8')
            for ids in (['1', '1'], ['1'], ['2', '3']):
                configure_community.configure_community(path, ids)
            self.assertTrue(path.read_text(encoding='utf-8').startswith(original))
            self.assertEqual(dotenv_values(path)['COMMUNITY_ADMIN_USER_IDS'], '2,3')
            self.assertEqual(path.read_text(encoding='utf-8').count('COMMUNITY_ADMIN_USER_IDS='), 1)

    def test_username_or_invalid_id_cannot_change_authority(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '.env'
            path.write_text('COMMUNITY_ADMIN_USER_IDS=1\n', encoding='utf-8')
            original = path.read_bytes()
            for invalid in ([], [''], ['planetowner'], ['0'], ['-1'], ['1', 'two']):
                with self.subTest(ids=invalid), self.assertRaises(ValueError):
                    configure_community.configure_community(path, invalid)
                self.assertEqual(path.read_bytes(), original)

    def test_export_and_server_apply_transfer_only_admin_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, exported, target = (root / name for name in ('local.env', 'community.env', 'server.env'))
            source.write_text('DB_PASSWORD=local-secret\nCOMMUNITY_ADMIN_USER_IDS=1\n', encoding='utf-8')
            exported.touch()
            target.write_text('DB_PASSWORD=server-secret\nCOMMUNITY_ADMIN_USER_IDS=2\n', encoding='utf-8')
            for origin, destination in ((source, exported), (exported, target)):
                output = io.StringIO()
                with patch.object(sys, 'argv', ['configure_community.py', '--from-env', str(origin), '--env-file', str(destination)]), contextlib.redirect_stdout(output):
                    configure_community.main()
                self.assertNotIn('secret', output.getvalue())
            self.assertEqual(dotenv_values(exported), {'COMMUNITY_ADMIN_USER_IDS': '1'})
            self.assertEqual(dotenv_values(target), {'DB_PASSWORD': 'server-secret', 'COMMUNITY_ADMIN_USER_IDS': '1'})


if __name__ == '__main__':
    unittest.main()
