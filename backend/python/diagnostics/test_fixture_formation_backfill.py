from copy import deepcopy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from diagnostics import backfill_fixture_formations as job
from diagnostics import test_fixture_details as samples
from one_touch_loader.loaders import fixture_details_loader as details
from one_touch_loader.core.sportmonks import SportmonksClient


class FormationBackfillTests(unittest.TestCase):
    setUp = samples.FixtureDetailsStorageTests.setUp
    tearDown = samples.FixtureDetailsStorageTests.tearDown

    def prepare(self):
        self.connection.execute('ALTER TABLE fixtures ADD COLUMN home_team_id INTEGER DEFAULT 10')
        self.connection.execute('ALTER TABLE fixtures ADD COLUMN away_team_id INTEGER DEFAULT 20')
        payload = samples._payload()
        details.replace_fixture_detail_rows(500, details._normalize_fixture_details(payload, 500), payload['lineups'])
        self.connection.execute('DELETE FROM fixture_formations')
        self.connection.commit()
        return {'fixture_id': 500, 'participants': [{'id': 10, 'location': 'home'}, {'id': 20, 'location': 'away'}],
                'formations': [{'participant_id': 10, 'formation': '4-3-3'}]}

    def fetch(self, sql, params):
        return self.connection.execute(sql.replace('%s', '?'), params).fetchall()

    def test_fills_only_missing_source_formations_and_repeated_run_changes_nothing(self):
        snapshot = self.prepare()
        tables = ('fixture_events', 'fixture_lineups', 'fixture_player_stats', 'fixture_team_stats')
        before = {table: self.connection.execute(f'SELECT * FROM {table}').fetchall() for table in tables}
        with patch.object(job, 'fetch_all', side_effect=self.fetch), patch('builtins.print'):
            preview = job.backfill([snapshot], apply=False)
            self.assertEqual((preview['available'], preview['unavailable']), (1, 1))
            self.assertEqual(self.connection.execute('SELECT * FROM fixture_formations').fetchall(), [])
            applied = job.backfill([snapshot], apply=True)
            self.assertEqual(applied['inserted'], 1)
            self.assertEqual(self.connection.execute('SELECT * FROM fixture_formations').fetchall(), [(500, 10, '4-3-3')])
            snapshot['formations'][0]['formation'] = '4-4-2'
            repeated = job.backfill([snapshot], apply=True)
            self.assertEqual((repeated['inserted'], repeated['already_stored']), (0, 1))
            self.assertEqual(self.connection.execute('SELECT * FROM fixture_formations').fetchall(), [(500, 10, '4-3-3')])
        for table in tables:
            self.assertEqual(self.connection.execute(f'SELECT * FROM {table}').fetchall(), before[table])

    def test_validates_entire_snapshot_before_writing(self):
        valid = self.prepare()
        self.connection.execute('INSERT INTO fixtures VALUES (501,10,20)')
        self.connection.commit()
        for failure in ('participants', 'formation', 'duplicate'):
            invalid = deepcopy(valid)
            invalid['fixture_id'] = 501
            if failure == 'participants':
                invalid['participants'][0]['id'] = 99
            elif failure == 'formation':
                invalid['formations'][0]['participant_id'] = 99
            else:
                invalid['fixture_id'] = 500
            with self.subTest(failure=failure), patch.object(job, 'fetch_all', side_effect=self.fetch):
                with self.assertRaises(ValueError):
                    job.backfill([valid, invalid], apply=True)
                self.assertEqual(self.connection.execute('SELECT * FROM fixture_formations').fetchall(), [])

    def test_concurrent_collection_keeps_its_formation(self):
        snapshot = self.prepare()
        def fetch(sql, params):
            rows = self.fetch(sql, params)
            if 'FROM fixture_formations' in sql:
                self.connection.execute("INSERT INTO fixture_formations VALUES (500,10,'4-4-2')")
                self.connection.commit()
            return rows
        with patch.object(job, 'fetch_all', side_effect=fetch), patch('builtins.print'):
            job.backfill([snapshot], apply=True)
        self.assertEqual(self.connection.execute('SELECT * FROM fixture_formations').fetchall(), [(500, 10, '4-4-2')])

    def test_real_formation_team_ids_use_same_correction_in_collection_and_backfill(self):
        self.prepare()
        cases = json.loads((Path(__file__).parent / 'fixtures/sportmonks_formation_team_ids.json').read_text())['cases']
        snapshots = []
        expected = []
        for case in cases:
            raw = case['fixture']
            fid = raw['id']
            teams = {p['meta']['location']: p['id'] for p in raw['participants']}
            self.assertEqual(set(case['lineup_team_ids']), set(teams.values()))
            corrected = deepcopy(raw)
            SportmonksClient._correct_fixture_teams(corrected)
            for before, after in zip(raw['formations'], corrected['formations']):
                self.assertEqual(after['participant_id'], teams[before['location']])
                self.assertEqual(after['formation'], before['formation'])
            again = deepcopy(corrected)
            SportmonksClient._correct_fixture_teams(again)
            self.assertEqual(again, corrected)
            unrelated = dict(deepcopy(raw), id=1)
            SportmonksClient._correct_fixture_teams(unrelated)
            self.assertEqual(unrelated['formations'], raw['formations'])
            self.connection.execute('INSERT INTO fixtures VALUES (?,?,?)', (fid, teams['home'], teams['away']))
            for tid in teams.values():
                self.connection.execute('INSERT OR IGNORE INTO teams VALUES (?)', (tid,))
            snapshots.append({'fixture_id': fid, 'formations': raw['formations'],
                              'participants': [{'id': tid, 'location': side} for side, tid in teams.items()]})
            expected.extend(details.normalize_fixture_formations(corrected, fid))
        self.connection.commit()
        with patch.object(job, 'fetch_all', side_effect=self.fetch), patch('builtins.print'):
            result = job.backfill(snapshots, apply=True)
        self.assertEqual(result['inserted'], 26)
        self.assertEqual(self.connection.execute('SELECT * FROM fixture_formations ORDER BY fixture_id,team_id').fetchall(), sorted(expected))
