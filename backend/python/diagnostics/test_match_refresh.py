from copy import deepcopy
from datetime import datetime, timedelta, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
import sqlite3
import unittest
from unittest.mock import Mock, patch

from one_touch_loader.loaders import match_refresh as jobs
from one_touch_loader.loaders import live_fixtures_loader as live
from one_touch_loader.loaders import standings_loader as standings
from one_touch_loader.loaders import understat_common as understat
from one_touch_loader.loaders import understat_loader, understat_ids_loader
from one_touch_loader.api.repos import standings_repo
from diagnostics.test_standings import _details
from diagnostics.test_understat import SAMPLE


NOW = datetime(2026, 9, 22, 21, tzinfo=timezone.utc)


def fixture(**changes):
    return dict(fixture_id=1, home_team_id=10, away_team_id=20, starting_at='2026-09-22 18:00:00',
                state_id=5, home_score=1, away_score=0, season_id=100, competition_id=8,
                season_name='2026/2027', has_xg=False, has_opta=False) | changes


class MatchRefreshTests(unittest.TestCase):
    def setUp(self):
        folder = TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.path = Path(folder.name) / 'state.json'
        self.rows = [fixture()]
        mock = patch.object(jobs, 'read_current_fixtures', side_effect=lambda: deepcopy(self.rows))
        mock.start()
        self.addCleanup(mock.stop)

    def run_job(self, task='understat', *, seconds=0, apply=True):
        return jobs.refresh(task, state_path=self.path, apply=apply, now=NOW+timedelta(seconds=seconds))

    def test_unpublished_retries_after_five_minutes_and_new_match_does_not_wait(self):
        with patch.object(jobs, '_provider_refresh', return_value=(set(), set())) as collect:
            self.assertEqual(self.run_job()['pending'], 1)
            self.run_job(seconds=299)
            self.assertEqual(collect.call_count, 1)
            self.rows.append(fixture(fixture_id=2))
            self.run_job(seconds=299)
            self.assertEqual([f['fixture_id'] for f in collect.call_args.args[1]], [2])
            self.run_job(seconds=300)
            self.assertEqual([f['fixture_id'] for f in collect.call_args.args[1]], [1])

    def test_restart_preserves_backoff_and_success_stops_source_reads(self):
        with patch.object(jobs, '_provider_refresh', return_value=({1}, set())) as collect:
            self.run_job()
            self.run_job(seconds=301)
        collect.assert_called_once()

    def test_many_existing_matches_write_one_checkpoint_and_idle_scan_writes_none(self):
        self.rows = [fixture(fixture_id=i, has_xg=True) for i in range(101)]
        with patch.object(jobs, 'save_state', wraps=jobs.save_state) as save, \
             patch.object(jobs, '_provider_refresh') as collect:
            self.run_job()
            self.run_job(seconds=15)
        save.assert_called_once()
        collect.assert_not_called()

    def test_initial_verified_data_and_known_withheld_are_not_reloaded(self):
        self.rows[0]['has_xg'] = True
        with patch.object(jobs, '_provider_refresh', return_value=(set(), {2})) as collect:
            self.run_job()
            collect.assert_not_called()
            self.rows.append(fixture(fixture_id=2))
            self.run_job(seconds=15)
            self.run_job(seconds=3600)
            collect.assert_called_once()

    def test_result_correction_reopens_completed_job(self):
        with patch.object(jobs, '_provider_refresh', return_value=({1}, set())) as collect:
            self.run_job()
            self.rows[0]['home_score'] = 2
            self.run_job(seconds=15)
        self.assertEqual(collect.call_count, 2)

    def test_failure_remains_pending_even_if_xg_was_written_before_standings_failed(self):
        with patch.object(jobs, '_provider_refresh', side_effect=[RuntimeError('standings failed'), ({1}, set())]) as collect:
            self.assertEqual(len(self.run_job()['failures']), 1)
            self.rows[0]['has_xg'] = True
            self.run_job(seconds=299)
            self.assertEqual(collect.call_count, 1)
            self.assertEqual(self.run_job(seconds=300)['completed'], 1)

    def test_preview_does_not_write_checkpoint(self):
        with patch.object(jobs, '_provider_refresh', return_value=(set(), set())):
            self.run_job(apply=False)
        self.assertFalse(self.path.exists())

    def test_completed_details_then_xg_then_expected_standings(self):
        events = []
        with patch.object(live, 'refresh_completed_details', side_effect=lambda *a, **k: events.append('details') or [{'id':1}]), \
             patch.object(jobs, 'refresh_understat', side_effect=lambda *a, **k: events.append('xg') or
                          {'processed_fixture_ids':[1], 'withheld_fixture_ids':[]}) as xg, \
             patch.object(jobs, 'build_xg_standings', side_effect=lambda *a: events.append('standings') or {'unavailable':[]}):
            self.assertEqual(jobs._provider_refresh('understat', self.rows, apply=True, output_dir=self.path), ({1}, set()))
        self.assertEqual(events, ['details','xg','standings'])
        self.assertEqual(xg.call_args.kwargs['fixture_ids'], {1})

    def test_details_failure_does_not_call_either_provider(self):
        with patch.object(live, 'refresh_completed_details', side_effect=RuntimeError('details failed')), \
             patch.object(jobs, 'refresh_understat') as xg, patch.object(jobs.opta_shots_loader,'sync_matches') as opta:
            for task in ('understat','opta'):
                with self.assertRaisesRegex(RuntimeError, 'details failed'):
                    jobs._provider_refresh(task, self.rows, apply=True, output_dir=self.path)
        xg.assert_not_called()
        opta.assert_not_called()

    def test_live_standings_every_thirty_seconds_and_official_on_completed_result(self):
        self.rows[0]['state_id'] = 2
        with patch.object(standings, 'refresh_current_table') as collect:
            self.run_job('standings')
            self.assertEqual([c.kwargs['live'] for c in collect.call_args_list], [False, True])
            self.rows[0]['home_score'] = 2
            self.run_job('standings', seconds=15)
            self.assertEqual(collect.call_count, 2)
            self.run_job('standings', seconds=30)
            self.assertTrue(collect.call_args.kwargs['live'])
            self.assertFalse(collect.call_args.kwargs['clear_live'])
            self.rows[0]['state_id'] = 5
            self.run_job('standings', seconds=45)
            self.assertFalse(collect.call_args.kwargs['live'])
            self.assertTrue(collect.call_args.kwargs['clear_live'])

    def test_probabilities_on_completion_then_fifteen_minute_external_check(self):
        with patch.object(jobs.probability_refresh, 'refresh', return_value={'europe': {'competitions': []}}) as calculate:
            self.run_job('probability')
            self.run_job('probability', seconds=899)
            calculate.assert_called_once()
            self.rows[0]['home_score'] = 3
            self.run_job('probability', seconds=899)
            self.assertEqual(calculate.call_count, 2)
            self.run_job('probability', seconds=1799)
            self.assertEqual(calculate.call_count, 3)

    def test_live_goal_does_not_trigger_final_result_probability_recalculation(self):
        self.rows[0]['state_id'] = 2
        with patch.object(jobs.probability_refresh, 'refresh', return_value={'europe': {'competitions': []}}) as calculate:
            self.run_job('probability')
            self.rows[0]['home_score'] = 9
            self.run_job('probability', seconds=30)
        calculate.assert_called_once()

    def test_missing_verified_bracket_remains_pending_and_retries(self):
        report = {'europe': {'competitions': [{'season_id': 100, 'status': 'verified_knockout_path_required'}]}}
        with patch.object(jobs.probability_refresh, 'refresh', return_value=report) as calculate:
            first = self.run_job('probability')
            self.assertEqual((first['completed'], first['pending']), (0, 1))
            self.run_job('probability', seconds=299)
            calculate.assert_called_once()
            self.run_job('probability', seconds=300)
        self.assertEqual(calculate.call_count, 2)

    def test_probability_failure_retries_without_hiding_failure(self):
        with patch.object(jobs.probability_refresh, 'refresh', side_effect=RuntimeError('source failed')) as calculate:
            self.assertEqual(len(self.run_job('probability')['failures']), 1)
            self.run_job('probability', seconds=299)
            calculate.assert_called_once()
            self.run_job('probability', seconds=300)
        self.assertEqual(calculate.call_count, 2)


class ScopedSourceTests(unittest.TestCase):
    def test_understat_waits_for_both_rosters_without_saving_partial_match(self):
        source = {'dates': [deepcopy(SAMPLE['match'])], 'teams': {}}
        external = str(SAMPLE['match']['id'])
        known = {'fixture': {external: 1}, 'team': {}, 'player': {}}
        client = Mock()
        client.get_season.return_value = source
        client.get_match.return_value = {'rosters': {'h': {}, 'a': {}}, 'shots': {'h': [], 'a': []}}
        with patch.object(understat, 'load_mapping_fixtures', return_value=[]), \
             patch.object(understat_loader, 'replace_understat_rows') as save:
            result = understat_loader.collect_understat(client=client, known=known, fixture_ids={1},
                scope=[{'season_id': 100, 'competition_id': 8, 'name': '2026/2027'}])
        self.assertEqual(result['pending_fixture_ids'], [1])
        self.assertEqual(result['processed_fixture_ids'], [])
        save.assert_not_called()
        mapping_source, _ = understat_ids_loader.load_mapping_source(client, source, require_rosters=True)
        self.assertEqual(mapping_source['dates'], [])

    def test_api_uses_live_table_only_during_play_and_keeps_official_rows(self):
        with sqlite3.connect(':memory:') as connection:
            connection.row_factory = sqlite3.Row
            connection.executescript('''
                CREATE TABLE seasons(season_id,competition_id);
                CREATE TABLE stages(stage_id,season_id);
                CREATE TABLE fixtures(fixture_id,stage_id,state_id);
                CREATE TABLE teams(team_id,name,short_name,image_path);
                CREATE TABLE standings(season_id,team_id,position,previous_position,won,draw,lost,goals_for,goals_against,points);
                CREATE TABLE live_standings AS SELECT * FROM standings;
                INSERT INTO seasons VALUES(100,8);
                INSERT INTO stages VALUES(200,100);
                INSERT INTO fixtures VALUES(1,200,2);
                INSERT INTO teams VALUES(10,'Home','H',NULL);
                INSERT INTO standings VALUES(100,10,2,2,0,0,0,0,0,0);
                INSERT INTO live_standings VALUES(100,10,1,2,1,0,0,1,0,3);
            ''')
            def fetch(sql, params=()):
                return [dict(r) for r in connection.execute(sql.replace('%s', '?'), params)]
            with patch.object(standings_repo, 'fetch_all_dict', side_effect=fetch), \
                 patch.object(standings_repo, '_last_five_by_team', return_value={}):
                self.assertEqual(standings_repo.list_standings(8, 100)[0]['points'], 3)
                connection.execute('UPDATE fixtures SET state_id=5')
                self.assertEqual(standings_repo.list_standings(8, 100)[0]['points'], 0)
                connection.execute('UPDATE fixtures SET state_id=2')
                connection.execute('DELETE FROM live_standings')
                self.assertEqual(standings_repo.list_standings(8, 100)[0]['points'], 0)

    def test_live_confirmation_batches_one_hundred_and_one_matches(self):
        client = Mock()
        client.get_live_fixtures_batch.side_effect = lambda ids: [{'id': i} for i in ids]
        ids = list(range(101))
        self.assertEqual([r['id'] for r in live.read_live_fixture_batches(client, ids)], ids)
        self.assertEqual([len(c.args[0]) for c in client.get_live_fixtures_batch.call_args_list], [50, 50, 1])

    def test_understat_selects_new_verified_match_without_downloading_other_finished_matches(self):
        source = {'teams': {'11': {'title':'A'}, '22': {'title':'B'}}, 'dates':[
            {'id':'101','isResult':True,'h':{'id':'11'},'a':{'id':'22'},'datetime':'2026-09-22 18:00:00'},
            {'id':'102','isResult':True,'h':{'id':'22'},'a':{'id':'11'},'datetime':'2026-09-21 18:00:00'}]}
        known = {'team':{'11':10,'22':20},'fixture':{},'player':{}}
        with patch.object(understat,'load_mapping_fixtures',return_value=[fixture(),fixture(
            fixture_id=2, home_team_id=20,away_team_id=10,starting_at='2026-09-21 18:00:00')]):
            selected = understat.select_fixture_source(source, 100, {1}, known)
        self.assertEqual([r['id'] for r in selected['dates']], ['101'])
        self.assertEqual(len(source['dates']), 2)
        self.assertEqual(known['fixture'], {})

    def test_live_table_validates_season_and_complete_membership_before_writing(self):
        rows = [{'season_id':100,'participant_id':10,'position':1,'points':3,'details':_details()}]
        with patch.object(standings,'SportmonksClient') as cls, \
             patch.object(standings,'fetch_all',return_value=[(10,),(20,)]), \
             patch.object(standings,'_replace_season') as save:
            cls.return_value.get_live_standings.return_value = rows
            with self.assertRaisesRegex(ValueError,'every season participant'):
                standings.refresh_current_table(100, 8, live=True, apply=True)
            rows[0]['season_id'] = 101
            with self.assertRaisesRegex(ValueError,'season differs'):
                standings.refresh_current_table(100, 8, live=True, apply=True)
        save.assert_not_called()


if __name__ == '__main__':
    unittest.main()
