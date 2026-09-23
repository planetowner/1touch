"""자료 없음의 재확인 간격과 부분 실패·중단 뒤 처리 기록을 검증해요."""
from copy import deepcopy
from datetime import timedelta
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from diagnostics.test_match_refresh import fixture, NOW
from diagnostics.reconcile_opta_refresh import plan_reconciliation
from diagnostics import reconcile_opta_refresh as recovery
from one_touch_loader.loaders.opta_shots_loader import scheduled_fixture
from one_touch_loader.loaders import match_refresh as jobs


def item(fid, status='unavailable', seconds=0):
    return {'fixture_id': fid, 'external_fixture_id': f'opta-{fid}', 'status': status,
            'source': {'signature': [8, '2026/2027', 'home', 'away', '2026-09-22', '18:00:00Z'],
                       'starting_at': '2026-09-22T18:00:00Z'},
            'checked_at_utc': (NOW + timedelta(seconds=seconds)).isoformat()}


class OptaRefreshTests(unittest.TestCase):
    def setUp(self):
        directory = TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / 'opta.json'
        self.rows = [fixture()]
        read = patch.object(jobs, 'read_current_fixtures', side_effect=lambda: deepcopy(self.rows))
        read.start()
        self.addCleanup(read.stop)

    def run_job(self, seconds=0, apply=True):
        return jobs.refresh('opta', state_path=self.path, apply=apply, now=NOW+timedelta(seconds=seconds))

    def seed(self, status='unavailable', seconds=0):
        self.path.write_text(json.dumps({str(f['fixture_id']): jobs.opta_state_entry(
            f, item(f['fixture_id'], status, seconds)) for f in self.rows}))

    def test_recent_unavailable_retries_after_five_minutes(self):
        self.seed()
        with patch.object(jobs, '_provider_refresh', return_value=(set(), set())) as collect:
            self.run_job(299)
            collect.assert_not_called()
            self.run_job(300)
            collect.assert_called_once()

    def test_old_unavailable_retries_daily_instead_of_being_permanently_excluded(self):
        self.rows[0]['starting_at'] = '2026-07-07 18:00:00'
        self.seed()
        with patch.object(jobs, '_provider_refresh', return_value=(set(), set())) as collect:
            self.run_job(300)
            self.run_job(86399)
            collect.assert_not_called()
            self.run_job(86400)
            collect.assert_called_once()

    def test_48_hour_boundary_and_errors_are_not_treated_as_no_data(self):
        f = fixture(starting_at=(NOW-timedelta(hours=48)).isoformat())
        self.assertEqual(jobs.opta_retry_seconds(f, {'status':'unavailable'}, NOW), 300)
        self.assertEqual(jobs.opta_retry_seconds(f, {'status':'unavailable'}, NOW+timedelta(seconds=1)), 86400)
        self.assertEqual(jobs.opta_retry_seconds(f, {'status':'failed'}, NOW+timedelta(days=1)), 300)

    def test_new_result_bypasses_old_unavailable_wait(self):
        self.rows[0]['starting_at'] = '2026-07-07 18:00:00'
        self.seed()
        self.rows[0]['home_score'] = 2
        with patch.object(jobs, '_provider_refresh', return_value=({1}, set())) as collect:
            self.run_job(15)
        collect.assert_called_once()

    def test_new_games_first_with_global_limit_and_one_old_game(self):
        self.rows = [fixture(fixture_id=i, starting_at='2026-07-07 18:00:00', season_id=i) for i in range(10,20)]
        self.rows += [fixture(fixture_id=i, season_id=i) for i in range(1,5)]
        with patch.object(jobs, '_provider_refresh', return_value=(set(), set())) as collect:
            result = self.run_job()
        ids = [f['fixture_id'] for call in collect.call_args_list for f in call.args[1]]
        self.assertEqual(ids, [1,2,3,4,10])
        self.assertEqual((result['attempted'],result['deferred']), (5,9))
        with patch.object(jobs, '_provider_refresh', return_value=(set(), set())) as collect:
            self.run_job(15)
        self.assertEqual(collect.call_args.args[1][0]['fixture_id'], 11)

    def test_one_failed_game_preserves_other_results_immediately(self):
        self.rows = [fixture(fixture_id=i) for i in range(1,4)]
        def collect(task, rows, *, on_result, **kwargs):
            on_result(item(1,'stored',120))
            self.assertEqual(json.loads(self.path.read_text())['1']['status'], 'complete')
            on_result(item(2,'unavailable',180))
            on_result(item(3,'failed',240))
            raise ValueError('one capture failed')
        with patch.object(jobs, '_provider_refresh', side_effect=collect):
            result = self.run_job()
        state = json.loads(self.path.read_text())
        self.assertEqual([state[str(i)]['status'] for i in range(1,4)], ['complete','unavailable','failed'])
        self.assertEqual((result['completed'],result['pending'],len(result['failures'])), (1,2,1))
        with patch.object(jobs, '_provider_refresh', return_value=(set(),set())) as collect:
            self.run_job(479)
            collect.assert_not_called()
            self.run_job(480)
        self.assertEqual([f['fixture_id'] for f in collect.call_args.args[1]], [2])

    def test_process_interruption_keeps_already_reported_game(self):
        self.rows = [fixture(fixture_id=1),fixture(fixture_id=2)]
        def collect(task, rows, *, on_result, **kwargs):
            on_result(item(1,'unavailable',30))
            raise KeyboardInterrupt()
        with patch.object(jobs, '_provider_refresh', side_effect=collect):
            with self.assertRaises(KeyboardInterrupt): self.run_job()
        self.assertEqual(json.loads(self.path.read_text())['1']['status'], 'unavailable')

    def test_preview_callback_never_writes_state(self):
        def collect(task, rows, *, on_result, **kwargs):
            on_result(item(1))
            return set(),set()
        with patch.object(jobs, '_provider_refresh', side_effect=collect):
            self.run_job(apply=False)
        self.assertFalse(self.path.exists())

    def test_unlinked_source_result_is_saved_and_waits_without_guessing_db_identity(self):
        outcome = item(99)
        outcome['source']['starting_at'] = '2026-07-07T17:15:00Z'
        def collect(task, rows, *, on_result, should_retry, **kwargs):
            self.assertTrue(should_retry(outcome))
            on_result(outcome)
            self.assertFalse(should_retry(outcome))
            return set(), set()
        with patch.object(jobs, '_provider_refresh', side_effect=collect):
            self.run_job()
        state = json.loads(self.path.read_text())
        self.assertEqual(state['opta:opta-99']['status'], 'unavailable')
        self.assertEqual(state['1']['status'], 'pending')
        self.assertNotIn('99', state)
        self.assertFalse(jobs.opta_source_due(outcome, state, NOW+timedelta(seconds=86399)))
        self.assertTrue(jobs.opta_source_due(outcome, state, NOW+timedelta(days=1)))

    def test_source_schedule_and_db_result_corrections_bypass_source_wait(self):
        outcome = item(1)
        state = {'opta:opta-1': jobs.opta_state_entry(None, outcome)}
        self.assertFalse(jobs.opta_source_due(outcome, state, NOW))
        changed = deepcopy(outcome)
        changed['source']['signature'][-1] = '19:00:00Z'
        self.assertTrue(jobs.opta_source_due(changed, state, NOW))
        state['1'] = jobs.opta_state_entry(self.rows[0], outcome)
        self.path.write_text(json.dumps(state))
        self.rows[0]['home_score'] = 2
        def collect(task, rows, *, should_retry, **kwargs):
            self.assertTrue(should_retry(outcome))
            return set(), set()
        with patch.object(jobs, '_provider_refresh', side_effect=collect):
            self.run_job(15)

    def test_source_candidates_also_prioritize_recent_and_limit_old_captures(self):
        old = item(90)
        old['source']['starting_at'] = '2026-07-07T17:15:00Z'
        another_old = deepcopy(old) | {'external_fixture_id':'opta-91'}
        recent = item(1)
        def collect(task, rows, *, should_retry, source_order, **kwargs):
            ordered = sorted([old, recent, another_old], key=source_order)
            self.assertEqual(ordered[0], recent)
            self.assertTrue(should_retry(recent))
            self.assertTrue(should_retry(old))
            self.assertFalse(should_retry(another_old))
            return set(), set()
        with patch.object(jobs, '_provider_refresh', side_effect=collect):
            self.run_job()


class ReportReconciliationTests(unittest.TestCase):
    def setUp(self):
        directory=TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root=Path(directory.name)
        self.rows=[fixture()]
        self.known={'team':{'home':10,'away':20},'fixture':{},'player':{}}
        self.match={'external_fixture_id':'opta-1','home_external_team_id':'home',
                    'away_external_team_id':'away','date':'2026-09-22','time':'18:00:00Z'}
        self.state={'1':{'signature':jobs.fingerprint(jobs.fixture_result(self.rows[0])),
                         'status':'pending','attempted_at':NOW.timestamp()}}

    def report(self, folder='old', seconds=-3600, **changes):
        root=self.root/folder
        root.mkdir()
        (root/'schedule-8.json').write_text(json.dumps({'competition_id':8,'season_name':'2026/2027','matches':[self.match]}))
        raw={'match_id':'opta-1','finished':True,'available':False,
             'checked_at_utc':(NOW+timedelta(seconds=seconds)).isoformat(),
             'evidence':{'commentary_message':'There is no data available for this fixture.',
                         'passmap_message':'No data found'}} | changes
        (root/'opta-1.raw.json').write_text(json.dumps(raw))

    def plan(self):
        return plan_reconciliation(self.root,self.rows,self.known,self.state)

    def test_restores_latest_verified_no_data_without_network_or_state_write(self):
        self.report('a',-3600)
        self.report('b',-1800)
        original=deepcopy(self.state)
        report=self.plan()
        self.assertEqual(report['changes']['1']['after']['attempted_at'],(NOW-timedelta(seconds=1800)).timestamp())
        self.assertEqual(self.state,original)
        self.state.update({k:v['after'] for k,v in report['changes'].items()})
        self.assertEqual(self.plan()['changes'],{})

    def test_missing_evidence_is_not_no_data(self):
        self.report(evidence={})
        self.assertEqual(self.plan()['changes'],{})

    def test_wrong_match_identity_and_changed_result_are_not_restored(self):
        self.report()
        self.known['team']['home']=99
        self.assertNotIn('1',self.plan()['changes'])
        self.assertIn('opta:opta-1',self.plan()['changes'])
        self.known['team']['home']=10
        self.rows[0]['home_score']=2
        self.assertNotIn('1',self.plan()['changes'])

    def test_saved_data_and_newer_failure_are_preserved(self):
        self.report()
        self.rows[0]['has_opta']=True
        self.assertNotIn('1',self.plan()['changes'])
        self.rows[0]['has_opta']=False
        self.state['1']['status']='failed'
        self.assertNotIn('1',self.plan()['changes'])

    def test_cli_preview_is_read_only_and_apply_backs_up_original_state(self):
        self.report('opta')
        path = self.root/'opta.json'
        original = json.dumps(self.state)
        path.write_text(original)
        with patch.object(jobs, 'read_current_fixtures', return_value=self.rows), \
             patch.object(recovery, 'load_known_ids', return_value=self.known), patch('builtins.print'):
            recovery.main(['--state-dir', str(self.root), '--check'])
            self.assertEqual(path.read_text(), original)
            self.assertEqual(list(self.root.glob('opta.before-reconcile-*')), [])
            recovery.main(['--state-dir', str(self.root), '--apply'])
        self.assertEqual(json.loads(path.read_text())['1']['status'], 'unavailable')
        backups = list(self.root.glob('opta.before-reconcile-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), original)

    def test_identity_requires_known_link_or_both_teams_and_unique_date(self):
        self.assertEqual(scheduled_fixture(self.match,self.rows,self.known),self.rows[0])
        self.known['team'].pop('away')
        self.assertIsNone(scheduled_fixture(self.match,self.rows,self.known))
        self.known['fixture']['opta-1']=1
        self.assertEqual(scheduled_fixture(self.match,self.rows,self.known),self.rows[0])
        self.match['date']='2026-09-21'
        self.assertIsNone(scheduled_fixture(self.match,self.rows,self.known))


if __name__ == '__main__':
    unittest.main()
