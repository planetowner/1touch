"""LINE 키를 숨겨 저장하고 다른 서비스 설정을 보존하는지 확인해요."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from dotenv import dotenv_values

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import configure_line


class ConfigureLineTests(unittest.TestCase):
    def test_invalid_inputs_leave_file_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '.env'
            path.write_text('# keep\nDB_PASSWORD=other-secret\n', encoding='utf-8')
            original = path.read_bytes()
            for channel_id, secret in (('', 'key'), ('com.example.app', 'key'), ('0', 'key'),
                                       ('123456', ''), ('123456', 'injected\nKEY=value')):
                with self.subTest(channel_id=channel_id), self.assertRaises(ValueError):
                    configure_line.configure_line(path, channel_id, secret)
                self.assertEqual(path.read_bytes(), original)

    def test_hidden_prompt_export_and_server_apply_preserve_other_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            source, exported, target = (Path(directory) / name for name in ('local.env', 'line.env', 'server.env'))
            source.write_text('# local\nDB_PASSWORD=local-secret\n', encoding='utf-8')
            exported.touch()
            target.write_text('# server\nDB_PASSWORD=server-secret\n', encoding='utf-8')
            commands = [(['--channel-id', '123456'], source), (['--from-env', str(source)], exported),
                        (['--from-env', str(exported)], target)]
            for arguments, destination in commands:
                output = io.StringIO()
                with patch.object(sys, 'argv', ['configure_line.py', *arguments, '--env-file', str(destination)]), \
                     patch.object(configure_line, 'getpass', return_value='line-secret'), contextlib.redirect_stdout(output):
                    configure_line.main()
                self.assertNotIn('line-secret', output.getvalue())
            self.assertEqual(dotenv_values(exported), {'LINE_CHANNEL_ID': '123456', 'LINE_CHANNEL_SECRET': 'line-secret'})
            self.assertEqual(dotenv_values(target), {'DB_PASSWORD': 'server-secret', 'LINE_CHANNEL_ID': '123456', 'LINE_CHANNEL_SECRET': 'line-secret'})
            self.assertTrue(target.read_text(encoding='utf-8').startswith('# server\nDB_PASSWORD=server-secret\n'))


if __name__ == '__main__':
    unittest.main()
