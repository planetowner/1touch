"""연결된 선수의 번역과 감독 신원을 대조하고 기존 이름 보존을 확인해요."""
from copy import deepcopy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from diagnostics.name_test_support import NameMigrationDatabase

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from diagnostics import migrate_coach_names as migration


class CoachNamesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = json.loads(Path(__file__).with_name('fixtures').joinpath(
            'sportmonks_coach_names.json').read_text(encoding='utf-8'))
        cls.profiles = {row['current']['coach_id']: row for row in source['coaches']}

    def test_linked_player_display_translation_preserves_provider_spelling(self):
        for key, names in [(50, ('S.ジェラード', 'S. 杰拉德')),
                           (307, ('ミケル・アルテタ', '米凯尔·阿尔塔塔')),
                           (455384, ('アントニオ・コンテ', '安东尼奥·孔特'))]:
            source = self.profiles[key]
            before = deepcopy(source)
            row, conflicts = migration.reviewed_player_translation(**source)
            self.assertEqual(conflicts, [])
            self.assertEqual((row['ja'], row['zh']), names)
            self.assertEqual(row['identity'], {'name': source['current']['name']})
            self.assertEqual(source, before)

    def test_observed_player_name_and_birthday_conflicts_are_excluded(self):
        for key, field in [(1260, 'display_name'), (94341, 'date_of_birth')]:
            row, conflicts = migration.reviewed_player_translation(**self.profiles[key])
            self.assertIsNone(row)
            self.assertIn(field, conflicts)

    def test_missing_link_and_wrong_ids_cannot_supply_translations(self):
        for field in ('id', 'player_id', 'player'):
            source = deepcopy(self.profiles[307])
            source['profiles']['ja'][field] = None
            row, conflicts = migration.reviewed_player_translation(**source)
            self.assertIsNone(row)
            self.assertTrue(conflicts)
        source = deepcopy(self.profiles[307])
        source['profiles']['zh']['player']['id'] = 50
        self.assertEqual(migration.reviewed_player_translation(**source), (None, ['provider_id']))

    def test_english_fallback_leaves_only_that_language_empty(self):
        source = deepcopy(self.profiles[307])
        source['profiles']['ja']['player']['display_name'] = 'Mikel Arteta'
        row, conflicts = migration.reviewed_player_translation(**source)
        self.assertEqual(conflicts, [])
        self.assertIsNone(row['ja'])
        self.assertEqual(row['zh'], '米凯尔·阿尔塔塔')

    def test_stored_name_changes_are_not_silently_relinked(self):
        source = deepcopy(self.profiles[307])
        source['current']['name'] = 'Another coach'
        self.assertEqual(migration.reviewed_player_translation(**source), (None, ['name']))

    def test_reviewed_seed_keeps_verified_source_and_excludes_conflicts(self):
        rows = migration.reviewed_rows('ja-zh')['coaches']
        by_id = {row['coach_id']: row for row in rows}
        for key in (50, 307, 455384):
            self.assertEqual(by_id[key], migration.reviewed_player_translation(**self.profiles[key])[0])
        for key in (1260, 94341, 3721, 127657, 37648736):
            self.assertNotIn(key, by_id)
        self.assertEqual(sum(row['ja'] is not None for row in rows), 544)
        self.assertEqual(sum(row['zh'] is not None for row in rows), 540)

    def test_migration_preserves_original_korean_and_unmatched_rows(self):
        fixture = NameMigrationDatabase()
        try:
            fixture.db.execute('CREATE TABLE coaches (coach_id INTEGER PRIMARY KEY, name TEXT, '
                               'name_ko TEXT, name_ja TEXT, name_zh TEXT)')
            before = [(1, 'Other', None, None, None),
                      (455384, 'Antonio Conte', '안토니오 콘테', None, None)]
            fixture.db.executemany('INSERT INTO coaches VALUES (?, ?, ?, ?, ?)', before)
            fixture.db.commit()
            reviewed = {'coaches': [migration.reviewed_player_translation(**self.profiles[455384])[0]]}
            with patch.object(migration, 'reviewed_rows', return_value=reviewed):
                migration.migrate_data(fixture.connection, 'ja-zh')
                migration.migrate_data(fixture.connection, 'ja-zh')
                after = fixture.db.execute('SELECT * FROM coaches ORDER BY coach_id').fetchall()
                self.assertEqual(after, [before[0], (*before[1][:3], 'アントニオ・コンテ', '安东尼奥·孔特')])
                reviewed['coaches'][0]['zh'] = '別の名前'
                with self.assertRaises(ValueError):
                    migration.migrate_data(fixture.connection, 'ja-zh')
                self.assertEqual(fixture.db.execute('SELECT * FROM coaches ORDER BY coach_id').fetchall(), after)
        finally:
            fixture.close()


if __name__ == '__main__':
    unittest.main()
