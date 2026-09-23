"""언어별 표시 이름과 기존 선수 연결을 검증해요."""
from copy import deepcopy
import unittest
from unittest.mock import patch

with patch('mysql.connector.pooling.MySQLConnectionPool') as pool:
    pool.return_value.get_connection.side_effect = AssertionError('Operational DB access in tests')
    from diagnostics import migrate_sportmonks_names as migration


class SportmonksNamesTests(unittest.TestCase):
    def setUp(self):
        self.current = {'player_id': 997, 'display_name': 'Harry Kane', 'full_name': 'Harry Kane',
                        'date_of_birth': '1993-07-28', 'nationality_id': 462}
        base = {'id': 997, 'name': 'Harry Kane', 'display_name': 'Harry Kane\u00a0',
                'date_of_birth': '1993-07-28', 'nationality_id': 462}
        self.profiles = {'en': base, 'ja': {**base, 'name': 'ハリー', 'display_name': 'ハリー・ケイン'},
                         'zh': {**base, 'name': '哈里', 'display_name': '哈里·凯恩'}}

    def test_uses_display_name_and_preserves_source_spelling(self):
        row, conflicts = migration.reviewed_translation('players', self.current, self.profiles)
        self.assertEqual(conflicts, [])
        self.assertEqual((row['ja'], row['zh']), ('ハリー・ケイン', '哈里·凯恩'))
        self.assertEqual(row['identity']['display_name'], 'Harry Kane')

    def test_missing_or_english_fallback_is_not_a_translation(self):
        for locale in ('ja', 'zh'):
            for value in (None, '', '  ', 'Harry Kane', 'Harry Kane\u00a0', 'H. Kane'):
                self.assertIsNone(migration.localized_value(value, 'Harry Kane', locale))
        self.assertEqual(migration.localized_value('FCバルセロナ', 'FC Barcelona', 'ja'), 'FCバルセロナ')
        self.assertEqual(migration.localized_value('巴塞罗那足球俱乐部', 'FC Barcelona', 'zh'), '巴塞罗那足球俱乐部')

    def test_id_and_identity_conflicts_are_excluded(self):
        for field, value in [('id', 998), ('date_of_birth', '1993-08-28'), ('nationality_id', 5)]:
            profiles = deepcopy(self.profiles)
            profiles['ja'][field] = value
            row, conflicts = migration.reviewed_translation('players', self.current, profiles)
            self.assertIsNone(row)
            self.assertTrue(conflicts)
        for field in ('display_name', 'full_name', 'date_of_birth', 'nationality_id'):
            current = {**self.current, field: 'different'}
            row, conflicts = migration.reviewed_translation('players', current, self.profiles)
            self.assertIsNone(row)
            self.assertIn(field, conflicts)

    def test_partial_schema_is_not_treated_as_complete(self):
        with patch.object(migration, 'fetch_all', return_value=[]):
            self.assertFalse(migration.verify_schema(before=True))
        with patch.object(migration, 'fetch_all', side_effect=[[('varchar(160)', 'YES')]] * 2 + [[('varchar(255)', 'YES')]] * 2):
            self.assertTrue(migration.verify_schema(before=True))
        with patch.object(migration, 'fetch_all', side_effect=[[('varchar(160)', 'YES')], [], [], []]), \
                self.assertRaisesRegex(ValueError, 'Incomplete'):
            migration.verify_schema(before=True)

    def test_preview_checks_current_identity_and_existing_translations(self):
        player, _ = migration.reviewed_translation('players', self.current, self.profiles)
        reviewed = {'teams': [{'team_id': 83, 'identity': {'name': 'FC Barcelona'}, 'ja': 'FCバルセロナ', 'zh': None}],
                    'players': [player]}
        current = [(997, 'Harry Kane', 'Harry Kane', '1993-07-28', 462, None, None)]
        with patch.object(migration, 'reviewed_rows', return_value=reviewed), \
                patch.object(migration, 'verify_schema', return_value=True):
            with patch.object(migration, 'fetch_all', side_effect=[[(83, 'FC Barcelona', None, None)], current]):
                ready, result = migration.preview()
                self.assertTrue(ready)
                self.assertEqual((result['teams']['updates'], result['players']['updates']), (1, 2))
            for changed, message in ([(83, 'Another team', None, None)], 'identity'), \
                    ([(83, 'FC Barcelona', '別の名前', None)], 'differs'):
                with patch.object(migration, 'fetch_all', return_value=changed), self.assertRaisesRegex(ValueError, message):
                    migration.preview()


if __name__ == '__main__':
    unittest.main()
