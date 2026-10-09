"""공급자 ID 변경 전·후 원본과 저장된 Opta 연결의 교정을 확인해요."""
from copy import deepcopy
import json
from pathlib import Path
import sqlite3
import unittest
from unittest.mock import Mock, patch

from diagnostics import repair_sandro_identity as repair
from diagnostics.name_test_support import NameMigrationDatabase
from one_touch_loader.core.opta_ids import plan_match_ids
from one_touch_loader.core.opta_chalkboard import normalize_chalkboard
from one_touch_loader.core.opta_analysis import normalize_analysis
from one_touch_loader.core.sportmonks import SportmonksClient
from one_touch_loader.loaders.opta_shots_store import bind_events

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.loaders.fixture_details_loader import _normalize_fixture_details
    from one_touch_loader.loaders.team_squad_members_loader import _exclude_sportmonks_duplicate_players


SOURCE = json.loads(Path(__file__).with_name('fixtures').joinpath('sandro_identity.json').read_text())


class SandroSourceTests(unittest.TestCase):
    def test_current_profile_and_squad_are_preserved(self):
        self.assertIsNone(SOURCE['provider_profiles'][str(repair.OLD_PLAYER_ID)])
        current = SOURCE['provider_profiles'][str(repair.PLAYER_ID)]
        self.assertEqual((current['display_name'], current['date_of_birth']), ('Sandro Lima', '1990-10-28'))
        squad, excluded = _exclude_sportmonks_duplicate_players(SOURCE['provider_squad'])
        self.assertEqual(squad, SOURCE['provider_squad'])
        self.assertEqual(excluded, {})
        self.assertEqual(squad[0]['player_id'], repair.PLAYER_ID)

    def test_previous_and_current_lineups_statistics_and_events_use_current_id(self):
        for key in ('previous_fixture', 'current_fixture_fragment'):
            with self.subTest(source=key):
                raw = SOURCE[key]
                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(side_effect=AssertionError('Unexpected provider request'))
                corrected = client.correct_fixture_details(deepcopy(raw))
                # 현재 ID를 예전 ID로 되돌리던 VAR 보정은 더 이상 적용하지 않아요.
                self.assertEqual(corrected, raw)
                rows = _normalize_fixture_details(corrected, raw['id'])
                self.assertEqual({row[2] for row in rows['lineups']}, {repair.PLAYER_ID})
                self.assertTrue(all(row[2] == repair.PLAYER_ID for row in rows['player_stats']))
                if key == 'current_fixture_fragment':
                    self.assertTrue(rows['player_stats'])
                self.assertFalse(any(repair.OLD_PLAYER_ID in row[4:6] for row in rows['events']))
                for before, after in zip(raw['events'], rows['events']):
                    self.assertEqual((before['minute'], before['extra_minute']), after[6:8])

    def test_actual_failed_capture_resolves_after_repair_and_still_rejects_wrong_identity(self):
        known = {entity: {} for entity in ('fixture', 'team', 'player')}
        known['player'][repair.OPTA_ID] = repair.OLD_PLAYER_ID
        args = (SOURCE['raw'], SOURCE['match'], SOURCE['fixtures'], SOURCE['lineups'], known)
        with self.assertRaisesRegex(ValueError, '기존 player ID'):
            plan_match_ids(*args)
        known['player'][repair.OPTA_ID] = repair.PLAYER_ID
        plan = plan_match_ids(*args)
        self.assertEqual(plan['mappings']['player'][repair.OPTA_ID], repair.PLAYER_ID)
        for dataset, normalize, count in (('shots', normalize_chalkboard, 10),
                                           ('analysis', normalize_analysis, 897)):
            self.assertEqual(len(bind_events(normalize(SOURCE['raw']), plan, dataset=dataset)), count)
        known['player'][repair.OPTA_ID] = 999
        with self.assertRaisesRegex(ValueError, '기존 player ID'):
            plan_match_ids(*args)


class SandroDatabaseTests(unittest.TestCase):
    def setUp(self):
        self.fixture = NameMigrationDatabase()
        self.addCleanup(self.fixture.close)
        self.db, self.conn = self.fixture.db, self.fixture.connection
        self.db.execute('ALTER TABLE players ADD COLUMN date_of_birth TEXT')
        self.db.executemany('INSERT INTO players(player_id,display_name,date_of_birth) VALUES (?,?,?)',
                            [(pid, 'Sandro Lima', '1990-10-28') for pid in (repair.OLD_PLAYER_ID, repair.PLAYER_ID)])
        self.db.execute('CREATE TABLE player_external_ids (player_id INT, provider TEXT, external_player_id TEXT, '
                        'PRIMARY KEY(player_id,provider), UNIQUE(provider,external_player_id))')
        self.db.executemany('INSERT INTO player_external_ids VALUES (?,?,?)',
                            [(row['player_id'], row['provider'], row['external_player_id'])
                             for row in SOURCE['external_ids']])
        self.db.execute('CREATE TABLE fixture_events (event_id INT PRIMARY KEY, fixture_id INT, team_id INT, '
                        'player_id INT, related_player_id INT, minute INT, info TEXT)')
        self.db.executemany('INSERT INTO fixture_events VALUES (?,?,?,?,?,?,?)', [
            (157569490, 19788665, 132649, repair.OLD_PLAYER_ID, None, 63, 'Goal Disallowed'),
            (1, 19788665, 132649, 1, repair.PLAYER_ID, 12, 'Assist'),
        ])
        for table in ('fixture_opta_shots', 'fixture_opta_events'):
            self.db.execute(f'CREATE TABLE {table} (external_event_id TEXT PRIMARY KEY, fixture_id INT, '
                            'team_id INT, player_id INT, minute INT, start_x TEXT)')
            self.db.executemany(f'INSERT INTO {table} VALUES (?,?,?,?,?,?)', [
                ('sandro', 19788649, 132649, repair.OLD_PLAYER_ID, 98, '93.300000'),
                ('other', 19788649, 132649, 1, 42, '50.100000'),
            ])
        self.db.commit()

    def snapshot(self):
        return {table: self.db.execute(f'SELECT * FROM {table} ORDER BY 1,2').fetchall()
                for table in ('players', *(scope[0] for scope in repair.SCOPES))}

    def test_preview_apply_and_repeat_preserve_profiles_provider_ids_and_event_details(self):
        before = self.snapshot()
        preview = repair.repair(self.conn)
        self.assertEqual(sum(preview['changes'].values()), 4)
        self.assertEqual(self.snapshot(), before)
        applied = repair.repair(self.conn, apply=True)
        self.assertEqual(applied['before'], preview['before'])
        self.assertEqual(applied['changes'], preview['changes'])
        expected = deepcopy(before)
        for table, column_index in (('player_external_ids', 0), ('fixture_events', 3),
                                    ('fixture_opta_shots', 3), ('fixture_opta_events', 3)):
            rows = []
            for row in before[table]:
                values = list(row)
                if values[column_index] == repair.OLD_PLAYER_ID and not (table == 'player_external_ids' and row[1] == 'sportmonks'):
                    values[column_index] = repair.PLAYER_ID
                rows.append(tuple(values))
            expected[table] = sorted(rows, key=lambda row: (row[0], row[1]))
        self.assertEqual(self.snapshot(), expected)
        self.assertEqual(sum(repair.repair(self.conn, apply=True)['changes'].values()), 0)
        self.assertEqual(self.snapshot(), expected)

    def test_identity_conflict_is_rejected_before_any_change(self):
        self.db.execute("UPDATE player_external_ids SET player_id=1 WHERE provider='opta'")
        self.db.commit()
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, 'Opta identity'):
            repair.repair(self.conn, apply=True)
        self.assertEqual(self.snapshot(), before)

    def test_later_write_failure_rolls_back_all_tables(self):
        self.db.execute("CREATE TRIGGER fail_repair BEFORE UPDATE ON fixture_opta_events "
                        "BEGIN SELECT RAISE(ABORT, 'test write failure'); END")
        self.db.commit()
        before = self.snapshot()
        with self.assertRaises(sqlite3.IntegrityError):
            repair.repair(self.conn, apply=True)
        self.assertEqual(self.snapshot(), before)


if __name__ == '__main__':
    unittest.main()
