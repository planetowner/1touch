"""실제 감독 혼합 응답과 DB 교정의 재실행·보존·롤백을 확인해요."""
from copy import deepcopy
import json
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

from diagnostics.name_test_support import NameMigrationDatabase
from diagnostics import repair_coach_identities as repair
from one_touch_loader.core.sportmonks import SportmonksClient

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.loaders.fixture_details_loader import _normalize_fixture_details


SOURCE = json.loads(Path(__file__).with_name('fixtures').joinpath(
    'sportmonks_coach_identity_errors.json').read_text(encoding='utf-8'))


class CoachSourceCorrectionTests(unittest.TestCase):
    def test_observed_profiles_use_one_correction_for_import_and_live(self):
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(return_value={'data': deepcopy(SOURCE['correct_carlos_profile'])})
        expected = {19719455: (29935, 'Aleksandar Vasoski'),
                    18545231: (523914, 'Carlos Soares da Costa Faria Carvalhal'),
                    1726535: (457103, 'Patrice Garande'), 19719457: (462010, 'Ilir Daja')}
        for raw in SOURCE['fixtures']:
            with self.subTest(fixture_id=raw['id']):
                corrected = client.correct_fixture_details(deepcopy(raw))
                coach_id, name = expected[raw['id']]
                normalized = _normalize_fixture_details(corrected, raw['id'])
                self.assertIn((coach_id, name), normalized['coaches'])
                self.assertIn(coach_id, [row[2] for row in normalized['fixture_coaches']])
                self.assertEqual(client.correct_fixture_details(deepcopy(corrected)), corrected)
                if raw['id'] == 18545231:
                    carlos = next(c for c in corrected['coaches'] if c['id'] == coach_id)
                    self.assertEqual(carlos['player_id'], 523914)
                    self.assertEqual(carlos['date_of_birth'], '1965-12-04')
                    self.assertEqual(carlos['meta'], {'fixture_id': 18545231, 'participant_id': 36, 'coach_id': 523914})
                    self.assertEqual(corrected['coaches'][1], raw['coaches'][1])
        client._get.assert_called_once_with('coaches/523914')

    def test_jefferson_is_not_replaced_outside_the_verified_fixture_and_team(self):
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(side_effect=AssertionError('Unexpected replacement'))
        original = next(f for f in SOURCE['fixtures'] if f['id'] == 18545231)
        for change in ('fixture', 'team'):
            raw = deepcopy(original)
            if change == 'fixture':
                raw['id'] = 1
            else:
                raw['coaches'][0]['meta']['participant_id'] = 1
            self.assertEqual(client.correct_fixture_details(deepcopy(raw)), raw)


class CoachDatabaseRepairTests(unittest.TestCase):
    def setUp(self):
        self.fixture = NameMigrationDatabase()
        self.db = self.fixture.db
        self.conn = self.fixture.connection
        self.reviewed = repair.reviewed_korean_rows()
        self.db.execute('CREATE TABLE coaches (coach_id INTEGER PRIMARY KEY, name TEXT, name_ko TEXT, name_ja TEXT, name_zh TEXT)')
        self.db.execute('CREATE TABLE fixture_coaches (fixture_id INTEGER, team_id INTEGER, coach_id INTEGER, PRIMARY KEY(fixture_id,team_id))')
        self.db.executemany('INSERT INTO coaches VALUES (?,?,?,?,?)', [
            (29935, 'Jovan Pop Zlatanov', '기존 한국어', None, None),
            (224127, 'Jefferson', None, None, None),
            (457103, 'Jessy Deminguet', None, 'ジェシー・デミンゲット', '杰西·德明盖特'),
            (462010, 'Djair', None, None, None),
            (523914, 'Carlos Soares da Costa Faria Carvalhal', None, None, None),
            (456014, 'Jorge Sampaoli Moya', '호르헤 삼파올리', 'existing-ja', 'existing-zh'),
            (94064, 'Laurent Batlles', None, 'held-ja', 'held-zh'),
        ])
        existing = {row[0] for row in self.db.execute('SELECT coach_id FROM coaches')}
        self.db.executemany('INSERT INTO coaches VALUES (?,?,?,?,?)', [
            (row['coach_id'], row['identity']['name'], None, 'reviewed-ja', 'reviewed-zh')
            for row in self.reviewed if row['coach_id'] not in existing
        ])
        self.db.executemany('INSERT INTO fixture_coaches VALUES (?,?,?)', [
            (18545231, 36, 224127), (18545231, 676, 456014), (1, 36, 224127),
        ])
        self.db.commit()

    def tearDown(self):
        self.fixture.close()

    def snapshot(self):
        return {table: self.db.execute(f'SELECT * FROM {table} ORDER BY 1,2').fetchall()
                for table in ('coaches', 'fixture_coaches')}

    def test_preview_apply_and_second_apply_preserve_other_names_and_relations(self):
        before = self.snapshot()
        preview = repair.repair(self.conn)
        # 한국어 한 건은 이미 있고, 신원·오역·경기 연결 여섯 건을 함께 교정해요.
        self.assertEqual(preview['change_count'], len(self.reviewed) - 1 + 6)
        self.assertEqual(self.snapshot(), before)
        applied = repair.repair(self.conn, apply=True)
        self.assertEqual(applied['changes'], preview['changes'])
        after = self.snapshot()
        coaches = {r[0]: r for r in after['coaches']}
        self.assertEqual(coaches[29935][1:3], ('Aleksandar Vasoski', '기존 한국어'))
        self.assertEqual(coaches[457103][1:], ('Patrice Garande', '파트리스 가랑드', None, None))
        self.assertEqual(coaches[462010][1:3], ('Ilir Daja', '일리르 다야'))
        self.assertEqual(coaches[523914][1:], ('Carlos Soares da Costa Faria Carvalhal', '카를루스 카르발랼', None, None))
        for row in self.reviewed:
            if row['coach_id'] in (29935, 457103, 462010, 523914):
                continue
            self.assertEqual(coaches[row['coach_id']][1:],
                             (row['identity']['name'], row['ko'], 'reviewed-ja', 'reviewed-zh'))
        for key in (224127, 456014, 94064):
            self.assertEqual(coaches[key], next(row for row in before['coaches'] if row[0] == key))
        self.assertEqual(after['fixture_coaches'], [(1, 36, 224127), (18545231, 36, 523914), (18545231, 676, 456014)])
        self.assertEqual(repair.repair(self.conn, apply=True)['change_count'], 0)
        self.assertEqual(self.snapshot(), after)

    def test_already_corrected_translation_is_preserved(self):
        self.db.execute('UPDATE coaches SET name_ja=? WHERE coach_id=457103', ('検証済み',))
        self.db.commit()
        self.assertEqual(repair.repair(self.conn, apply=True)['change_count'], len(self.reviewed) - 1 + 5)
        self.assertEqual(self.db.execute('SELECT name_ja FROM coaches WHERE coach_id=457103').fetchone()[0], '検証済み')

    def test_korean_names_fill_only_empty_values_for_the_correct_people(self):
        for existing in (None, '', '   ', '이미 검토한 이름'):
            with self.subTest(existing=existing):
                self.db.execute('UPDATE coaches SET name_ko=?', (existing,))
                self.db.commit()
                preview = repair.repair(self.conn)
                changes = [row for row in preview['changes'] if row.get('column') == 'name_ko']
                self.assertEqual(len(changes), len(self.reviewed) if existing != '이미 검토한 이름' else 0)
                repair.repair(self.conn, apply=True)
                saved = dict(self.db.execute('SELECT coach_id,name_ko FROM coaches').fetchall())
                for row in self.reviewed:
                    expected = existing if existing == '이미 검토한 이름' else row['ko']
                    self.assertEqual(saved[row['coach_id']], expected)
                for coach_id in (224127, 456014, 94064):
                    self.assertEqual(saved[coach_id], existing)

    def test_new_reviewed_identity_change_aborts_the_entire_repair(self):
        self.db.execute('UPDATE coaches SET name=? WHERE coach_id=57037', ('Another person',))
        self.db.commit()
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, 'Coach identity changed: 57037'):
            repair.repair(self.conn, apply=True)
        self.assertEqual(self.snapshot(), before)

    def test_reviewed_seed_keeps_evidence_and_excludes_held_people(self):
        seed = json.loads(repair.KOREAN_SEED_PATH.read_text(encoding='utf-8'))
        by_id = {row['coach_id']: row for row in self.reviewed}
        self.assertEqual(len(seed['additional_review_ids']), 16)
        self.assertEqual(len(seed['held_coach_ids']), 29)
        self.assertEqual(by_id[1500238]['ko'], '유라 아르시치')
        self.assertEqual(by_id[37660199]['ko'], '비탈리 포노마료우')
        self.assertEqual(by_id[455650]['ko'], '헤이미르 그뷔드욘손')
        self.assertEqual(by_id[37524062]['ko'], '시기 에이욜프손')
        self.assertEqual(by_id[37648171]['ko'], '비사르 세르마자이')
        self.assertFalse(set(by_id) & set(seed['held_coach_ids']))
        self.assertNotIn(224127, by_id)
        for row in self.reviewed:
            self.assertEqual(row['ko'], row['review']['proposed_ko'])
            self.assertTrue(row['review']['identity_evidence'])
            self.assertTrue(row['review']['language_assessment'])
            self.assertTrue(row['review']['rule_or_missing_evidence'])
            self.assertTrue(row['review']['nikl_same_person'])
            self.assertTrue(row['review']['sources'])
        for evidence in SOURCE['evidence']:
            review = evidence['korean_name_review']
            self.assertEqual(by_id[review['target_coach_id']]['ko'], review['name_ko'])

    def test_unexpected_identity_or_relation_aborts_before_updates(self):
        for statement in ('UPDATE coaches SET name="Unexpected" WHERE coach_id=29935',
                          'UPDATE fixture_coaches SET coach_id=456014 WHERE team_id=36 AND fixture_id=18545231'):
            with self.subTest(statement=statement):
                self.db.execute(statement)
                self.db.commit()
                before = self.snapshot()
                with self.assertRaises(ValueError):
                    repair.repair(self.conn, apply=True)
                self.assertEqual(self.snapshot(), before)
                self.db.execute('UPDATE coaches SET name="Jovan Pop Zlatanov" WHERE coach_id=29935')
                self.db.commit()

    def test_write_failure_rolls_back_name_and_translation_changes(self):
        before = self.snapshot()
        self.db.execute("CREATE TRIGGER fail_coach_link BEFORE UPDATE ON fixture_coaches "
                        "BEGIN SELECT RAISE(ABORT, 'test failure'); END")
        self.db.commit()
        with self.assertRaisesRegex(Exception, 'test failure'):
            repair.repair(self.conn, apply=True)
        self.assertEqual(self.snapshot(), before)


if __name__ == '__main__':
    unittest.main()
