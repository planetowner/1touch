"""테스트 DB 확인과 기존 구조 보존을 실제 DB 변경 없이 검사해요."""
import unittest
from unittest.mock import patch

from . import migrate_schema

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from diagnostics import migrate_fixture_chat_aliases, migrate_sportmonks_names
    from one_touch_loader.core import db


class SchemaMigrationTest(unittest.TestCase):
    def test_preview_does_not_write_and_apply_skips_existing_columns(self):
        for apply, ready in ((False, False), (True, True), (True, False)):
            with self.subTest(apply=apply, ready=ready), \
                    patch('sys.argv', ['migrate_schema'] + (['--apply'] if apply else [])), \
                    patch.object(migrate_schema, 'require_test_database') as require, \
                    patch.object(migrate_sportmonks_names, 'verify_schema', return_value=ready) as verify, \
                    patch.object(db, 'execute') as execute, \
                    patch.object(migrate_fixture_chat_aliases, 'main') as chat:
                migrate_schema.main()
                require.assert_called_once()
                chat.assert_called_once()
                if apply and not ready:
                    self.assertIn('ALTER TABLE coaches', execute.call_args.args[0])
                    self.assertEqual(verify.call_count, 2)
                    self.assertFalse(verify.call_args.kwargs['before'])
                else:
                    execute.assert_not_called()

    def test_wrong_database_cannot_migrate(self):
        with patch('sys.argv', ['migrate_schema', '--apply']), \
                patch.object(migrate_schema, 'require_test_database', side_effect=RuntimeError('wrong database')), \
                patch.object(db, 'execute') as execute, \
                patch.object(migrate_fixture_chat_aliases, 'main') as chat:
            with self.assertRaisesRegex(RuntimeError, 'wrong database'):
                migrate_schema.main()
            execute.assert_not_called()
            chat.assert_not_called()


if __name__ == '__main__':
    unittest.main()
