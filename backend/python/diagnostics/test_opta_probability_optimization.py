"""수집 범위 축소와 확률 재사용이 입력 정정·선행 실패를 놓치지 않는지 확인해요."""
from contextlib import ExitStack, nullcontext
from copy import deepcopy
from datetime import date, datetime, timedelta, timezone
import json
from pathlib import Path
import sqlite3
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

from diagnostics.test_opta_bulk import CASES, empty_ids
from diagnostics.test_cup_betting import fixture, NOW
from diagnostics.test_european_probability import inputs, card
from diagnostics.test_tournament_bracket import build, fixture as bracket_fixture
from one_touch_loader.core import db
from one_touch_loader.api import db as api_db
from one_touch_loader.loaders import opta_shots_loader as opta, opta_shots_store as store
from one_touch_loader.loaders import probability_loader as common, cup_betting_loader as cup
from one_touch_loader.loaders import european_probability_loader as europe
from one_touch_loader.loaders import probability_refresh as pipeline


class OptaWorkSelectionTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        root = Path(self.stack.enter_context(TemporaryDirectory()))
        self.args = SimpleNamespace(dataset='shots', apply=False, output_dir=root/'new',
            competition_ids=[564], season='2026/2027', from_date=None, to_date=date(2026,9,6),
            refresh=False, limit=None, retry_report=None, refresh_details=False)
        self.root = root
        self.db = self.stack.enter_context(patch.object(db, 'fetch_all', side_effect=[[(1,)], []]))
        self.stack.enter_context(patch.object(opta, 'load_known_ids', return_value=empty_ids()))
        self.schedule = self.stack.enter_context(patch.object(opta, 'fetch_schedule', return_value={
            'season_name':'2026/2027', 'matches':[deepcopy(c['match']) for c in CASES[:2]]}))
        self.scope = self.stack.enter_context(patch.object(opta, 'load_scope',
            return_value=(CASES[1]['fixtures'], CASES[1]['lineups'])))
        self.browser = self.stack.enter_context(patch.object(opta, 'open_browser', return_value=nullcontext(object())))
        self.collect = self.stack.enter_context(patch.object(opta, 'collect_snapshot', return_value={'finished':False}))
        self.save = self.stack.enter_context(patch.object(opta, 'save_match'))

    def test_all_saved_or_outside_dates_do_not_read_lineups_or_start_browser(self):
        self.db.side_effect = [[(1,)], [(c['raw']['match_id'], c['fixtures'][0]['fixture_id']) for c in CASES[:2]]]
        result = opta.sync_matches(self.args)
        self.assertEqual(result['skipped'], 2)
        self.scope.assert_not_called()
        self.browser.assert_not_called()
        self.save.assert_not_called()

    def test_limit_is_applied_before_scope_and_sportmonks_refresh(self):
        self.args.limit = 1
        self.args.refresh_details = True
        self.args.from_date = date(2026,9,1)
        with patch.object(opta, 'refresh_recent_rosters', return_value=[]) as refresh:
            result = opta.sync_matches(self.args)
        self.scope.assert_called_once_with(564, '2026/2027', match_dates=[CASES[0]['match']['date']])
        refresh.assert_called_once()
        self.assertEqual(result['not_finished'], 1)
        self.browser.assert_called_once()

    def test_cached_retry_does_not_start_browser_and_keeps_verified_mapping(self):
        case = CASES[1]
        eid = case['raw']['match_id']
        self.args.retry_report = self.root/'retry.json'
        self.args.retry_report.write_text(json.dumps({'matches':[{'external_fixture_id':eid, 'status':'failed'}]}))
        (self.root/f'{eid}.raw.json').write_text(json.dumps(case['raw']))
        result = opta.sync_matches(self.args)
        self.assertEqual((result['ready'], result['failed']), (1,0))
        self.scope.assert_called_once_with(564, '2026/2027', match_dates=[case['match']['date']])
        self.browser.assert_not_called()
        self.collect.assert_not_called()
        self.save.assert_not_called()

    def test_multiple_new_matches_share_one_browser(self):
        result = opta.sync_matches(self.args)
        self.assertEqual(result['not_finished'], 2)
        self.assertEqual(self.collect.call_count, 2)
        self.browser.assert_called_once()

    def test_reports_each_unavailable_or_failed_match_with_verified_fixture_id(self):
        first, second = CASES[:2]
        fixtures = {f['fixture_id']: f for c in (first, second) for f in c['fixtures']}
        self.scope.return_value = (list(fixtures.values()), first['lineups'] + second['lineups'])
        known = empty_ids()
        for case in (first, second):
            plan = opta.plan_match_ids(case['raw'], case['match'], case['fixtures'], case['lineups'], empty_ids())
            known['fixture'].update(plan['mappings']['fixture'])
        self.collect.side_effect = [dict(finished=True, available=False), TimeoutError('capture failed')]
        observed = []
        with patch.object(opta, 'load_known_ids', return_value=known):
            result = opta.sync_matches(self.args, on_result=lambda row: observed.append(dict(row)))
        self.assertEqual([row['status'] for row in observed], ['unavailable','failed'])
        self.assertEqual([row['fixture_id'] for row in observed], [known['fixture'][c['match']['external_fixture_id']] for c in (first,second)])
        self.assertTrue(all(row['checked_at_utc'] for row in observed))
        self.assertEqual((result['unavailable'],result['failed']), (1,1))

    def test_already_stored_match_reports_completion_without_browser(self):
        pairs = [(c['raw']['match_id'], c['fixtures'][0]['fixture_id']) for c in CASES[:2]]
        self.db.side_effect = [[(1,)], pairs]
        observed = []
        result = opta.sync_matches(self.args, on_result=observed.append)
        self.assertEqual(result['skipped'],2)
        self.assertEqual([row['fixture_id'] for row in observed], [fid for _,fid in pairs])
        self.browser.assert_not_called()

    def test_interrupted_capture_does_not_report_an_unfinished_result(self):
        self.collect.side_effect = [dict(finished=True, available=False), KeyboardInterrupt()]
        observed = []
        with self.assertRaises(KeyboardInterrupt):
            opta.sync_matches(self.args, on_result=observed.append)
        self.assertEqual([row['status'] for row in observed], ['unavailable'])

    def test_unavailable_source_is_skipped_before_limit_without_known_team_ids(self):
        self.args.limit = 1
        first = CASES[0]['match']['external_fixture_id']
        report = opta.sync_matches(self.args, should_retry=lambda row: row['external_fixture_id'] != first)
        self.assertEqual(report['skipped'], 1)
        self.assertEqual(report['matches'][0]['external_fixture_id'], CASES[1]['match']['external_fixture_id'])
        self.assertEqual(self.collect.call_count, 1)

    def test_all_sources_waiting_do_not_start_browser_or_read_rosters(self):
        opta.sync_matches(self.args, should_retry=lambda row: False)
        self.scope.assert_not_called()
        self.browser.assert_not_called()

    def test_least_recent_source_attempt_is_ordered_before_applying_limit(self):
        from one_touch_loader.loaders import match_refresh as jobs
        self.args.limit = 1
        first = CASES[0]['match']['external_fixture_id']
        def order(row):
            previous = {'attempted_at':1 if row['external_fixture_id']==first else 0}
            return jobs.opta_priority(row['source'], previous, datetime(2026,9,23,tzinfo=timezone.utc))
        result = opta.sync_matches(self.args, source_order=order)
        self.assertEqual(result['matches'][0]['external_fixture_id'], CASES[1]['match']['external_fixture_id'])
        self.assertEqual(self.collect.call_count, 1)

    def test_upstream_roster_failure_prevents_browser_and_event_storage(self):
        self.args.refresh_details = True
        self.args.from_date = date(2026,9,1)
        with patch.object(opta, 'refresh_recent_rosters', side_effect=RuntimeError('roster failed')):
            result = opta.sync_matches(self.args)
        self.assertEqual(result['failed'], 1)
        self.browser.assert_not_called()
        self.save.assert_not_called()

    def test_forced_event_refresh_also_refreshes_completed_rosters_when_requested(self):
        self.args.refresh = self.args.refresh_details = True
        self.args.from_date = date(2026,9,1)
        self.db.side_effect = [[(1,)], [(c['raw']['match_id'], c['fixtures'][0]['fixture_id']) for c in CASES[:2]]]
        with patch.object(opta, 'refresh_recent_rosters', return_value=[]) as refresh:
            opta.sync_matches(self.args)
        self.assertEqual(refresh.call_args.kwargs['stored_ids'], set())

    def test_scope_reads_only_candidate_dates_and_their_player_rows(self):
        with sqlite3.connect(':memory:') as conn:
            conn.executescript('''
                CREATE TABLE seasons(season_id INT,competition_id INT,name TEXT);
                CREATE TABLE stages(stage_id INT,season_id INT);
                CREATE TABLE fixtures(fixture_id INT,home_team_id INT,away_team_id INT,starting_at TEXT,state_id INT,stage_id INT);
                CREATE TABLE players(player_id INT,display_name TEXT,full_name TEXT);
                CREATE TABLE fixture_lineups(fixture_id INT,team_id INT,player_id INT,jersey_number INT);
                CREATE TABLE fixture_events(event_id INT,event_type_id INT,fixture_id INT,team_id INT,player_id INT);
                INSERT INTO seasons VALUES(1,564,'2026/2027');
                INSERT INTO stages VALUES(1,1);
                INSERT INTO fixtures VALUES(1,10,20,'2026-09-01 20:00:00',5,1),(2,10,20,'2026-09-02 20:00:00',5,1);
                INSERT INTO players VALUES(101,'One','One'),(102,'Two','Two');
                INSERT INTO fixture_lineups VALUES(1,10,101,1),(2,10,102,2);
            ''')
            def fetch(sql, args):
                cursor = conn.execute(sql.replace('%s','?'), args)
                return [dict(zip([c[0] for c in cursor.description], row)) for row in cursor.fetchall()]
            with patch.object(api_db, 'fetch_all_dict', side_effect=fetch):
                fixtures, players = store.load_scope(564, '2026/2027', match_dates=['2026-09-02'])
            self.assertEqual([f['fixture_id'] for f in fixtures], [2])
            self.assertEqual([p['player_id'] for p in players], [102])


class CalculationStorageTests(unittest.TestCase):
    def test_cup_source_failure_stops_dependent_jobs_after_independent_league_refresh(self):
        with patch.object(common,'read_clubelo_mapping',return_value={}), \
             patch.object(common,'refresh_histories',return_value={}), \
             patch.object(pipeline.tournament_bracket_loader,'refresh',return_value=[]), \
             patch.object(common,'refresh',return_value={}) as league, \
             patch.object(cup,'read_fixtures',side_effect=RuntimeError('cup source failed')), \
             patch.object(cup,'refresh') as cup_refresh, patch.object(europe,'refresh') as europe_refresh:
            with self.assertRaisesRegex(RuntimeError,'cup source failed'):
                pipeline.refresh()
        league.assert_called_once()
        cup_refresh.assert_not_called()
        europe_refresh.assert_not_called()

    def test_latest_metadata_is_separated_by_model_method_in_same_season(self):
        with sqlite3.connect(':memory:') as conn:
            conn.create_function('JSON_UNQUOTE',1,lambda value:value)
            conn.executescript('''CREATE TABLE probability_models(model_id TEXT,payload TEXT);
                CREATE TABLE probability_runs(run_id TEXT,model_id TEXT,season_id INT,as_of TEXT,created_at TEXT,payload TEXT);
                INSERT INTO probability_models VALUES('cup','{"method":"cup"}'),('europe','{"method":"europe"}');
                INSERT INTO probability_runs VALUES('1','cup',1,'2026-09-20','2026-09-20','{"input_sha256":"c"}'),
                    ('2','europe',1,'2026-09-21','2026-09-21','{"input_sha256":"e"}');''')
            def fetch(sql, args):
                cur = conn.execute(sql.replace('%s','?'),args)
                return [dict(zip([c[0] for c in cur.description], row)) for row in cur.fetchall()]
            with patch.object(common,'_fetch',side_effect=fetch):
                self.assertEqual(common.latest_calculation_inputs(1,'cup')['model_id'],'cup')
                self.assertEqual(common.latest_calculation_inputs(1,'europe')['input_sha256'],'e')
                self.assertIsNone(common.latest_calculation_inputs(1,'missing'))

    def test_elo_mapping_is_one_batch_without_dropping_source_provenance(self):
        connection = MagicMock()
        cursor = connection.cursor.return_value.__enter__.return_value
        with patch.object(db,'transaction',return_value=nullcontext(connection)):
            common.save_elo({'Arsenal':19,'Barcelona':83},[(19,'2026-09-21',2033,'a',NOW),
                                                        (83,'2026-09-21',1900,'a',NOW)])
        cursor.execute.assert_not_called()
        self.assertEqual(cursor.executemany.call_count,3)
        self.assertEqual(cursor.executemany.call_args_list[0].args[1],[(19,'Arsenal'),(83,'Barcelona')])
        self.assertEqual(cursor.executemany.call_args_list[2].args[1],[(19,'a',NOW),(83,'a',NOW)])


class CupReuseTests(unittest.TestCase):
    def setUp(self):
        self.report = dict(model_id='cup', method=cup.MODEL_METHOD, settlement_rule=cup.SETTLEMENT_RULE,
            forecast_model=dict(coefficients=[.5,1.3,.2,-1.2],last_training_fixture_at='2026-05-30 12:00:00'))
        self.histories = {10:[dict(date='2026-09-20',elo=1800)],20:[dict(date='2026-09-20',elo=1700)]}
        self.fixtures = [fixture(stage_name='Round of 16',leg='2/2',aggregate_id=7),
            fixture(fixture_id=2,home_team_id=20,away_team_id=10,leg='1/2',aggregate_id=7,
                    state_id=5,starting_at='2026-09-14 12:00:00',home_score=1,away_score=0),
            fixture(fixture_id=3,starting_at='2026-09-23 12:00:00')]
        self.previous = cup.prepare_runs(self.fixtures,self.histories,self.report,observed_at=NOW)[0][0]

    def run_calculation(self, **kwargs):
        return cup.prepare_runs(self.fixtures,self.histories,self.report,
            observed_at=kwargs.pop('observed_at',NOW),previous_by_season={100:self.previous},**kwargs)

    def test_unchanged_skips_probability_calculation(self):
        with patch.object(cup,'prediction_options') as calculate:
            runs, excluded = self.run_calculation(observed_at=NOW+timedelta(hours=1))
        self.assertEqual((runs,excluded),([],[]))
        calculate.assert_not_called()

    def test_elo_result_schedule_and_model_each_invalidate(self):
        for change in ('elo','first_leg_result','kickoff','model','stage','legacy'):
            with self.subTest(change=change):
                self.setUp()
                if change=='elo': self.histories[10][0]['elo']+=1
                if change=='first_leg_result': self.fixtures[1]['away_score']=1
                if change=='kickoff': self.fixtures[0]['starting_at']='2026-09-23 15:00:00'
                if change=='model': self.report['model_id']='new'
                if change=='stage': self.fixtures[2]['stage_name']='Unknown'
                if change=='legacy': self.previous.pop('refresh_input_version')
                runs, _ = self.run_calculation()
                self.assertEqual(len(runs),1)

    def test_kickoff_closes_one_market_even_when_db_state_and_elo_are_unchanged(self):
        runs,_ = self.run_calculation(observed_at=datetime(2026,9,22,13,tzinfo=timezone.utc))
        self.assertEqual(set(runs[0]['fixture_markets']),{'3'})

    def test_missing_elo_does_not_reuse_old_market(self):
        self.histories.pop(20)
        runs, excluded = self.run_calculation()
        self.assertEqual(runs[0]['fixture_markets'],{})
        self.assertEqual({r['reason'] for r in excluded},{'missing_pre_match_elo'})

    def test_refresh_uses_saved_metadata_and_does_not_store_unchanged(self):
        with patch.object(cup,'latest_model',return_value=self.report), \
             patch.object(cup,'latest_calculation_inputs',return_value=self.previous) as previous, \
             patch.object(cup,'read_clubelo_mapping',return_value={}), \
             patch.object(cup,'datetime') as clock, patch.object(cup,'store_runs') as save:
            clock.now.return_value=NOW
            result=cup.refresh(apply=True,histories=self.histories,fixtures=self.fixtures)
        self.assertEqual(result['markets'],0)
        previous.assert_called_once_with(100,cup.MODEL_METHOD)
        save.assert_not_called()


class EuropeReuseTests(unittest.TestCase):
    def setUp(self):
        args=inputs()
        self.fixtures=args['fixtures']
        self.fixtures[0].update(state_id=5,home_score=1,away_score=0,starting_at='2026-09-10 19:00:00')
        self.histories={t:[dict(date='2026-09-20',elo=1700)] for t in range(36)}
        self.coefficients=dict(season_name='2026/2027',teams=args['coefficients'],source_url='verified')
        self.report=dict(model_id='europe',method=europe.MODEL_METHOD,forecast_model=dict(
            coefficients=[.3,.2,.8],penalty_coefficient=0,card_samples=[[2,3]],
            last_training_fixture_at='2026-05-01 12:00:00'),limitations=[],validation=dict(metrics={}))
        self.raw=[dict(id=1,state_id=5,events=[])]
        with patch.object(common,'_read',return_value=self.coefficients):
            self.previous=europe.prepare_runs(self.fixtures,self.histories,self.report,self.raw,
                observed_at=NOW,simulations=100)[0][0]

    def run_calculation(self, **kwargs):
        with patch.object(common,'_read',return_value=self.coefficients):
            return europe.prepare_runs(self.fixtures,self.histories,self.report,self.raw,observed_at=NOW,
                simulations=kwargs.pop('simulations',100),previous_by_season={100:self.previous},**kwargs)

    def test_unchanged_skips_simulation(self):
        with patch.object(europe,'simulate_title') as simulate:
            runs,status=self.run_calculation()
        self.assertEqual(runs,[])
        self.assertEqual(status[0]['status'],'unchanged')
        simulate.assert_not_called()

    def test_elo_score_schedule_state_cards_coefficient_model_settings_each_invalidate(self):
        for change in ('elo','score','schedule','state','cards','coefficient','model','seed','simulations','legacy'):
            with self.subTest(change=change):
                self.setUp()
                kwargs={}
                if change=='elo': self.histories[0][0]['elo']+=1
                if change=='score': self.fixtures[0]['home_score']=2
                if change=='schedule': self.fixtures[1]['starting_at']='2026-10-02 20:00:00'
                if change=='state': self.fixtures[0].update(state_id=1,home_score=None,away_score=None)
                if change=='cards': self.raw[0]['events']=[card(999,19,team=0)]
                if change=='coefficient': self.coefficients['teams']['0']['coefficient']+=1
                if change=='model': self.report['model_id']='new'
                if change=='seed': kwargs['seed']=1
                if change=='simulations': kwargs['simulations']=101
                if change=='legacy': self.previous.pop('refresh_input_version')
                with patch.object(europe,'simulate_title',return_value={t:{'probability':0} for t in range(36)}) as simulate:
                    runs,status=self.run_calculation(**kwargs)
                simulate.assert_called_once()
                self.assertEqual(status[0]['status'],'updated')

    def test_missing_card_source_stops_before_reuse(self):
        self.raw=[]
        with self.assertRaises(KeyError): self.run_calculation()

    def test_refresh_still_reads_current_cards_before_deciding_to_skip(self):
        with patch.object(common,'latest_model',return_value=self.report), \
             patch.object(common,'latest_calculation_inputs',return_value=self.previous), \
             patch.object(common,'_read',return_value=self.coefficients), \
             patch.object(europe,'read_card_fixtures',return_value=self.raw) as cards, \
             patch.object(europe,'datetime') as clock, patch.object(common,'store_runs') as save:
            clock.now.return_value=NOW
            result=europe.refresh(apply=True,histories=self.histories,fixtures=self.fixtures,brackets=[],simulations=100)
        cards.assert_called_once_with(self.fixtures)
        self.assertEqual(result['competitions'][0]['status'],'unchanged')
        save.assert_not_called()

    def test_bracket_refresh_time_is_ignored_but_corrected_result_recalculates(self):
        now=datetime(2027,4,2,12,tzinfo=timezone.utc)
        for f in self.fixtures: f.update(state_id=5,home_score=0,away_score=0)
        bracket=build([bracket_fixture(1001,1,2,score=(2,1))])
        with patch.object(common,'_read',return_value=self.coefficients):
            first=europe.prepare_runs(self.fixtures,self.histories,self.report,[],observed_at=now,
                simulations=100,brackets=[bracket])[0][0]
            bracket['fetched_at']='2027-04-02T11:00:00Z'
            with patch.object(europe,'simulate_bracket_title') as simulate:
                runs,status=europe.prepare_runs(self.fixtures,self.histories,self.report,[],observed_at=now,
                    simulations=100,brackets=[bracket],previous_by_season={100:first})
            self.assertEqual(status[0]['status'],'unchanged')
            simulate.assert_not_called()
            corrected=build([bracket_fixture(1001,1,2,score=(1,2))])
            runs,_=europe.prepare_runs(self.fixtures,self.histories,self.report,[],observed_at=now,
                simulations=100,brackets=[corrected],previous_by_season={100:first})
            self.assertEqual(runs[0]['teams']['2']['probability'],1)


if __name__=='__main__':
    unittest.main()
