from copy import deepcopy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from diagnostics import backfill_fixture_formations as backfill
from diagnostics import test_fixture_details as samples
from one_touch_loader.loaders import fixture_details_loader as details


SOURCE = json.loads((Path(__file__).parent / 'fixtures/sportmonks_formation_value_error.json').read_text())
FIXTURE_ID = SOURCE['fixture_id']
EXPECTED = [(FIXTURE_ID, 18, '3-4-3'), (FIXTURE_ID, 63, '3-5-2')]


class FormationCorrectionTests(unittest.TestCase):
    def test_verified_error_is_corrected_without_mutating_provider_snapshot(self):
        raw = deepcopy(SOURCE)
        self.assertEqual(sorted(details.normalize_fixture_formations(raw, FIXTURE_ID)), EXPECTED)
        self.assertEqual(raw, SOURCE)

    def test_other_fixture_team_and_values_are_not_rewritten(self):
        for fid, tid, value in ((1, 18, '4-3-4'), (FIXTURE_ID, 63, '4-3-4'),
                                (FIXTURE_ID, 18, '3-4-3'), (FIXTURE_ID, 18, '3-4-2-1')):
            with self.subTest(fixture_id=fid, team_id=tid, formation=value):
                raw = {'formations': [{'participant_id': tid, 'formation': value}]}
                self.assertEqual(details.normalize_fixture_formations(raw, fid), [(fid, tid, value)])


class FormationCorrectionStorageTests(unittest.TestCase):
    setUp = samples.FixtureDetailsStorageTests.setUp
    tearDown = samples.FixtureDetailsStorageTests.tearDown

    def test_full_and_player_only_recollection_keep_verified_formation(self):
        self.connection.execute('INSERT INTO fixtures VALUES (?)', (FIXTURE_ID,))
        self.connection.execute('INSERT INTO teams VALUES (18), (63)')
        self.connection.execute('INSERT INTO fixture_formations VALUES (?,18,?)', (FIXTURE_ID, '4-3-4'))
        self.connection.commit()
        payload = {**samples._payload(), 'id': FIXTURE_ID, 'formations': deepcopy(SOURCE['formations'])}
        with patch.object(details, '_load_scope', return_value=[FIXTURE_ID]), \
                patch.object(details, 'SportmonksClient') as client, patch('builtins.print'):
            client.return_value.get_fixture_details.return_value = payload
            client.return_value.get_fixture_details_batch.return_value = [payload]
            # 공급자가 계속 같은 오타를 보내도 전체·선수 통계 재수집 모두 정정 값을 저장해요.
            for player_stats_only in (False, True, False, True):
                details.collect_fixture_details(FIXTURE_ID, player_stats_only=player_stats_only)
                self.assertEqual(self.connection.execute(
                    'SELECT * FROM fixture_formations ORDER BY team_id').fetchall(), EXPECTED)
        self.assertEqual(payload['formations'], SOURCE['formations'])

    def test_missing_formation_backfill_uses_same_correction(self):
        self.connection.execute('ALTER TABLE fixtures ADD COLUMN home_team_id INTEGER DEFAULT 10')
        self.connection.execute('ALTER TABLE fixtures ADD COLUMN away_team_id INTEGER DEFAULT 20')
        self.connection.execute('INSERT INTO fixtures VALUES (?,18,63)', (FIXTURE_ID,))
        self.connection.execute('INSERT INTO teams VALUES (18), (63)')
        self.connection.commit()
        def fetch(sql, params):
            return self.connection.execute(sql.replace('%s', '?'), params).fetchall()
        with patch.object(backfill, 'fetch_all', side_effect=fetch), patch('builtins.print'):
            first = backfill.backfill([deepcopy(SOURCE)], apply=True)
            repeated = backfill.backfill([deepcopy(SOURCE)], apply=True)
        self.assertEqual(first['inserted'], 2)
        self.assertEqual(repeated['inserted'], 0)
        self.assertEqual(self.connection.execute(
            'SELECT * FROM fixture_formations ORDER BY team_id').fetchall(), EXPECTED)


if __name__ == '__main__':
    unittest.main()
