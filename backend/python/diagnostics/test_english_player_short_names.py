"""복합 성의 이니셜 예외와 다른 이름·언어의 보존을 확인해요."""
import io
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

from diagnostics.name_test_support import NameMigrationDatabase

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from diagnostics import migrate_english_player_short_names as migration


class EnglishPlayerShortNamesTests(unittest.TestCase):
    def test_initials_preserve_compound_family_names_and_accents(self):
        cases = [
            ('E. Garcia', 'Garcia'), ('J. Cancelo', 'Cancelo'),
            ('E. García', 'García'), ('K. De Bruyne', 'De Bruyne'),
            ('T. Alexander-Arnold', 'Alexander-Arnold'),
            ('Á. Morata', 'Morata'), ('Ł. Fabiański', 'Fabiański'),
        ]
        changes = migration.name_changes(enumerate(before for before, _ in cases))
        self.assertEqual([row['after'] for row in changes], [after for _, after in cases])

    def test_lowercase_compounds_keep_or_restore_reviewed_initials(self):
        names = ['F. de Jong', 'V. van Dijk', 'M. ter Stegen', 'E. da Silva', 'K. í Bartalsstovu']
        reviewed = dict(enumerate(names))
        current = [(player_id, name[3:]) for player_id, name in reviewed.items()]
        changes = migration.name_changes(current, reviewed)
        self.assertEqual([row['after'] for row in changes], names)
        self.assertEqual(migration.name_changes(reviewed.items(), reviewed), [])

    def test_restore_does_not_replace_an_edited_name_or_guess_an_initial(self):
        current = [(1, 'Duarte'), (2, 'de Jong'), (3, 'de Jong')]
        reviewed = {1: 'E. dos Santos', 2: 'F. de Jong', 3: 'L. de Boer'}
        self.assertEqual(migration.name_changes(current, reviewed), [
            {'player_id': 2, 'before': 'de Jong', 'after': 'F. de Jong'},
        ])
        self.assertEqual(migration.name_changes([(4, 'de Jong')], reviewed), [])

    def test_other_names_are_unchanged_and_conversion_is_idempotent(self):
        names = ['Rodri', 'Neymar', 'de Jong', 'ter Stegen', 'João Cancelo', None, '']
        self.assertEqual(migration.name_changes(enumerate(names)), [])
        changes = migration.name_changes([(1, 'J. Cancelo')])
        self.assertEqual(migration.name_changes([(row['player_id'], row['after']) for row in changes]), [])

    def test_preview_does_not_write(self):
        with patch.object(migration, 'fetch_all', return_value=[(1, 'J. Cancelo')]), \
                patch.object(migration, 'get_conn') as connect, \
                patch.object(migration, 'migrate_data') as save, redirect_stdout(io.StringIO()):
            migration.main([])
        connect.assert_not_called()
        save.assert_not_called()

    def test_storage_preserves_other_languages_and_rolls_back_conflicts(self):
        fixture = NameMigrationDatabase()
        self.addCleanup(fixture.close)
        for column in ('short_name', 'short_name_ko', 'short_name_ja', 'short_name_zh'):
            fixture.db.execute(f'ALTER TABLE players ADD COLUMN {column} TEXT')
        fixture.db.execute("UPDATE players SET short_name='Rodri' WHERE player_id=1")
        fixture.db.execute("UPDATE players SET short_name='H. Kane', short_name_ko='H. 케인', "
                           "short_name_ja='H・ケイン', short_name_zh='H·凯恩' WHERE player_id=997")
        fixture.db.execute("INSERT INTO players VALUES "
                           "(2, 'Frenkie de Jong', 'Frenkie de Jong', '프렝키 더용', "
                           "'de Jong', 'F. 더용', 'F・デ・ヨング', 'F·德容')")
        fixture.db.commit()
        before = fixture.db.execute('SELECT * FROM players ORDER BY player_id').fetchall()
        changes = migration.name_changes(fixture.db.execute('SELECT player_id,short_name FROM players'),
                                         {2: 'F. de Jong'})
        migration.migrate_data(fixture.connection, changes)
        after = fixture.db.execute('SELECT * FROM players ORDER BY player_id').fetchall()
        expected_names = {2: 'F. de Jong', 997: 'Kane'}
        expected = [tuple(expected_names.get(row[0], value) if index == 4 else value
                          for index, value in enumerate(row)) for row in before]
        self.assertEqual(after, expected)
        migration.migrate_data(fixture.connection, changes)
        self.assertEqual(fixture.db.execute('SELECT * FROM players ORDER BY player_id').fetchall(), after)

        fixture.db.execute("UPDATE players SET short_name='Changed' WHERE player_id=997")
        fixture.db.commit()
        before_conflict = fixture.db.execute('SELECT * FROM players ORDER BY player_id').fetchall()
        # 한 선수의 값이 바뀌었으면 다른 선수도 수정하지 않아야 해요.
        with self.assertRaises(ValueError):
            migration.migrate_data(fixture.connection, [
                {'player_id': 1, 'before': 'Rodri', 'after': 'Test'}, *changes,
            ])
        self.assertEqual(fixture.db.execute('SELECT * FROM players ORDER BY player_id').fetchall(), before_conflict)


if __name__ == '__main__':
    unittest.main()
