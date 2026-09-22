from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import io
from decimal import Decimal
import json
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from uuid import uuid4

import mysql.connector
from fastapi import HTTPException
from fastapi.testclient import TestClient

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.core import db
    from one_touch_loader.api.main import create_app
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.repos import betting_repo as repo

from one_touch_loader.core.betting import SETTLEMENT_RULE, prediction_options, settlement, total_return
from one_touch_loader.core.cup_betting import fixture_context


class BettingRuleTests(unittest.TestCase):
    def test_worker_selects_all_completed_states_without_applying_by_default(self):
        from one_touch_loader.loaders import betting_loader
        with patch.object(betting_loader, 'fetch_all_dict', return_value=[{'bet_id': 1}]) as fetch, \
                patch.object(betting_loader, 'settle_bet', return_value=None) as settle, \
                patch('sys.stdout', new=io.StringIO()):
            betting_loader.run_cli([])
        self.assertTrue({5, 7, 8} <= set(fetch.call_args.args[1]))
        settle.assert_called_once_with(1, apply=False)

    def test_probability_return_and_floor(self):
        self.assertEqual(total_return(100, Decimal('0.6')), 166)
        self.assertEqual(total_return(100, Decimal('0.1')), 1000)
        self.assertEqual(total_return(100, Decimal('0.3')), 333)
        self.assertEqual(total_return(999999999999999990, Decimal('0.999999999999999999')),
                         999999999999999990)
        options = prediction_options((.4297, 1.671888, .04225, -1.545221), 1800, 1800)
        self.assertGreater(float(options[0]['probability']), float(options[2]['probability']))

    def test_settlement_uses_accepted_return_and_waits_for_complete_score(self):
        bet = {'outcome': 'draw', 'stake': 100, 'potential_return': 400}
        fixture = {'state_id': 5, 'state_code': 'FT', 'home_score': 1, 'away_score': 1}
        self.assertEqual(settlement(fixture, bet)['payout'], 400)
        for state in (11, 18, 2, 8):
            self.assertIsNone(settlement({**fixture, 'state_id': state}, bet))
        self.assertIsNone(settlement({**fixture, 'away_score': None}, bet))
        self.assertEqual(settlement({**fixture, 'state_id': 10, 'state_code': 'POSTPONED'}, bet)['payout'], 100)
        self.assertEqual(settlement({**fixture, 'home_penalty_score': 0, 'away_penalty_score': 0}, bet)['payout'], 400)

    def test_final_score_precedes_shootout_and_aggregate_winner(self):
        bet = {'outcome': 'home_win', 'stake': 100, 'potential_return': 240}
        fixture = {'state_id': 8, 'state_code': 'FT_PEN', 'home_score': 1, 'away_score': 0,
                   'home_penalty_score': 3, 'away_penalty_score': 4, 'aggregate_winner_team_id': 20}
        self.assertEqual(settlement(fixture, bet)['payout'], 240)
        self.assertEqual(settlement({**fixture, 'home_score': 0}, bet)['status'], 'lost')
        self.assertEqual(settlement({**fixture, 'home_score': 0, 'home_penalty_score': 5}, bet)['status'], 'won')

    def test_extra_time_and_missing_or_incomplete_shootout(self):
        bet = {'outcome': 'away_win', 'stake': 100, 'potential_return': 300}
        fixture = {'state_id': 7, 'state_code': 'AET', 'home_score': 1, 'away_score': 2}
        self.assertEqual(settlement(fixture, bet)['payout'], 300)
        tied = {**fixture, 'home_score': 2}
        self.assertIsNone(settlement(tied, bet, draw_allowed=False))
        for penalties in ({}, {'home_penalty_score': 3}, {'home_penalty_score': 3, 'away_penalty_score': 3}):
            self.assertIsNone(settlement({**tied, 'state_id': 8, **penalties}, bet))
        # 공급사가 종료 상태를 FT로 보내도 완료된 승부차기 점수는 반영해요.
        self.assertEqual(settlement({**tied, 'state_id': 5, 'home_penalty_score': 3,
                                    'away_penalty_score': 4}, bet)['payout'], 300)

    def test_authenticated_routes_and_request_validation(self):
        app = create_app()
        with TestClient(app) as client:
            self.assertEqual(client.get('/v1/fixtures/1/betting').status_code, 401)
            app.dependency_overrides[get_user_id] = lambda: 1
            for amount in (0, 11, 10.0, True):
                response = client.put('/v1/fixtures/1/bet', json={
                    'request_id': str(uuid4()), 'expected_revision': 0, 'outcome': 'home_win',
                    'stake': amount, 'prediction_run_id': 'a' * 64})
                self.assertEqual(response.status_code, 422, response.text)


@unittest.skipUnless(os.getenv('BETTING_TEST_MYSQL') == '1', 'Requires isolated local MySQL')
class BettingDatabaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = {'host': '127.0.0.1', 'port': 14876, 'user': 'root', 'password': '', 'connection_timeout': 5}
        with mysql.connector.connect(**cls.config) as conn, conn.cursor() as cur:
            cur.execute('SELECT @@datadir')
            expected = Path(__file__).resolve().parents[2] / 'logs/betting-mysql-test/data'
            if Path(cur.fetchone()[0]).resolve() != expected.resolve():
                raise AssertionError('Refusing non-test MySQL')

    def setUp(self):
        self.database = 'betting_test_' + uuid4().hex
        with mysql.connector.connect(**self.config) as conn, conn.cursor() as cur:
            cur.execute(f'CREATE DATABASE {self.database} CHARACTER SET utf8mb4')
        self.configured = {**self.config, 'database': self.database}
        self.pool = patch.object(db, '_pool', SimpleNamespace(get_connection=lambda: mysql.connector.connect(**self.configured)))
        self.pool.start()
        self.addCleanup(self.pool.stop)
        self.now = datetime(2026, 9, 18, 12)
        self.time_patch = patch.object(repo, 'utc_now', return_value=self.now)
        self.time_patch.start()
        self.addCleanup(self.time_patch.stop)
        sql = '''
            CREATE TABLE users (user_id BIGINT UNSIGNED PRIMARY KEY);
            CREATE TABLE fixture_states (state_id INT PRIMARY KEY,state_code VARCHAR(50));
            CREATE TABLE seasons (season_id BIGINT UNSIGNED PRIMARY KEY,competition_id INT,name VARCHAR(20));
            CREATE TABLE stages (stage_id INT PRIMARY KEY,season_id BIGINT UNSIGNED,stage_type_id INT,name VARCHAR(50));
            CREATE TABLE fixtures (fixture_id BIGINT UNSIGNED PRIMARY KEY,home_team_id BIGINT,away_team_id BIGINT,
                starting_at DATETIME,state_id INT,home_score INT,away_score INT,stage_id INT,
                home_penalty_score INT,away_penalty_score INT,leg VARCHAR(10),aggregate_id BIGINT);
            CREATE TABLE probability_models (model_id CHAR(64) CHARACTER SET ascii PRIMARY KEY,payload JSON);
            CREATE TABLE probability_runs (run_id CHAR(64) CHARACTER SET ascii PRIMARY KEY,model_id CHAR(64),
                season_id BIGINT,as_of DATETIME,payload JSON,created_at DATETIME);
            CREATE TABLE probability_team_results (run_id CHAR(64),team_id BIGINT,payload JSON,PRIMARY KEY(run_id,team_id));
        '''
        sql += (Path(__file__).resolve().parents[1] / 'one_touch_loader/sql/create_betting_tables.sql').read_text(encoding='utf-8')
        for statement in sql.split(';'):
            if statement.strip():
                self.execute(statement)
        self.execute('INSERT INTO users VALUES (1),(2)')
        self.execute("INSERT INTO fixture_states VALUES (1,'NS'),(5,'FT'),(7,'AET'),(8,'FT_PEN'),(10,'POSTPONED'),(11,'SUSPENDED'),(12,'CANCELLED'),(15,'ABANDONED')")
        self.execute("INSERT INTO seasons VALUES (1,564,'2026/2027'),(2,2,'2026/2027')")
        self.execute("INSERT INTO stages VALUES (1,1,223,'Regular Season'),(2,2,223,'League Stage')")
        for fixture_id in (1, 2):
            self.execute("INSERT INTO fixtures VALUES (%s,10,20,%s,1,NULL,NULL,1,NULL,NULL,'1/1',NULL)",
                         (fixture_id, self.now + timedelta(days=1)))
        self.execute('INSERT INTO probability_models VALUES (%s,%s)', ('b' * 64, json.dumps({
            'forecast_model': {'coefficients': [.4297, 1.671888, .04225, -1.545221]}})))
        self.add_prediction('a' * 64, self.now - timedelta(hours=1))

    def tearDown(self):
        with mysql.connector.connect(**self.config) as conn, conn.cursor() as cur:
            cur.execute(f'DROP DATABASE {self.database}')

    def execute(self, sql, params=()):
        with mysql.connector.connect(**self.configured) as conn, conn.cursor(dictionary=True) as cur:
            cur.execute(sql, params)
            result = cur.fetchall() if cur.with_rows else cur.lastrowid
            conn.commit()
            return result

    def add_prediction(self, run_id, as_of, kind='observed_calculation'):
        self.execute('INSERT INTO probability_runs VALUES (%s,%s,1,%s,%s,%s)',
                     (run_id, 'b' * 64, as_of, json.dumps({'history_kind': kind}), as_of))
        for team_id, elo in ((10, 2000), (20, 1750)):
            self.execute('INSERT INTO probability_team_results VALUES (%s,%s,%s)', (run_id, team_id, json.dumps({'elo': elo})))

    def body(self, stake=100, outcome='home_win', revision=0):
        return {'request_id': str(uuid4()), 'expected_revision': revision, 'outcome': outcome,
                'stake': stake, 'prediction_run_id': 'a' * 64}

    def test_welcome_is_once_for_existing_and_new_users(self):
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(repo.initialize_wallet, [1, 1]))
        self.assertEqual([r['balance'] for r in results], [1000, 1000])
        self.assertEqual(len(self.execute('SELECT * FROM user_point_entries')), 1)
        self.assertEqual(repo.get_wallet(2)['balance'], 0)

    def test_place_change_cancel_reopen_and_participant_counts(self):
        first = repo.mutate_bet(1, 1, self.body())
        self.assertEqual(first['wallet']['balance'], 900)
        changed = repo.mutate_bet(1, 1, self.body(300, 'draw', 1))
        self.assertEqual(changed['wallet']['balance'], 700)
        repo.mutate_bet(2, 1, self.body(10, 'away_win'))
        market = repo.get_market(1, 1)
        self.assertEqual(market['participation']['probabilities'], {'home_win': 0, 'draw': .5, 'away_win': .5})
        cancelled = repo.mutate_bet(1, 1, {'request_id': str(uuid4()), 'expected_revision': 2}, cancel=True)
        self.assertEqual(cancelled['wallet']['balance'], 1000)
        self.assertEqual(repo.get_market(1, 1)['participation']['total'], 1)
        self.assertEqual(repo.mutate_bet(1, 1, self.body(100, 'home_win', 3))['bet']['bet_id'], first['bet']['bet_id'])
        self.assertEqual(sum(r['amount'] for r in self.execute('SELECT amount FROM user_point_entries WHERE user_id=1')), 900)

    def test_duplicate_request_stale_revision_and_changed_payload(self):
        body = self.body()
        first = repo.mutate_bet(1, 1, body)
        self.assertEqual(repo.mutate_bet(1, 1, body), first)
        for invalid in (self.body(), {**body, 'stake': 200}):
            with self.assertRaises(HTTPException) as error:
                repo.mutate_bet(1, 1, invalid)
            self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(repo.get_wallet(1)['balance'], 900)

    def test_concurrent_different_fixtures_cannot_overspend(self):
        repo.initialize_wallet(1)
        def place(fixture_id):
            try:
                return repo.mutate_bet(1, fixture_id, self.body(800))
            except HTTPException as error:
                return error.status_code
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(place, [1, 2]))
        self.assertEqual(results.count(409), 1)
        self.assertEqual(repo.get_wallet(1)['balance'], 200)

    def test_kickoff_closes_placement_and_cancellation(self):
        first = repo.mutate_bet(1, 1, self.body())
        self.execute('UPDATE fixtures SET starting_at=%s WHERE fixture_id=1', (self.now,))
        with self.assertRaises(HTTPException):
            repo.mutate_bet(1, 1, {'request_id': str(uuid4()), 'expected_revision': 1}, cancel=True)
        self.assertFalse(repo.get_market(1, 1)['can_cancel'])
        self.assertEqual(repo.get_wallet(1)['balance'], first['wallet']['balance'])

    def test_new_prediction_requires_review_and_missing_prediction_does_not_create_wallet(self):
        self.add_prediction('c' * 64, self.now)
        with self.assertRaises(HTTPException) as error:
            repo.mutate_bet(1, 1, self.body())
        self.assertEqual(error.exception.detail['code'], 'prediction_changed')
        self.assertFalse(repo.get_wallet(1)['initialized'])
        self.execute('UPDATE fixtures SET stage_id=2 WHERE fixture_id=2')
        self.assertEqual(repo.get_market(1, 2)['unavailable_reason'], 'prediction_unavailable')

    def add_cup_prediction(self, *, draw_allowed=False, first_leg=None):
        self.execute('UPDATE fixtures SET stage_id=2 WHERE fixture_id=1')
        fixture = self.execute(repo.FIXTURE_SQL, (1,))[0]
        payload = {'history_kind': 'observed_calculation', 'market_kind': SETTLEMENT_RULE,
                   'fixture_markets': {'1': {'fixture': fixture_context(fixture),
                       'draw_allowed': draw_allowed, 'first_leg': first_leg,
                       'options': prediction_options([.5, 1.3, .2, -1.2], 2000, 1750, draw_allowed=draw_allowed)}}}
        self.execute('INSERT INTO probability_runs VALUES (%s,%s,2,%s,%s,%s)',
                     ('e' * 64, 'b' * 64, self.now, json.dumps(payload), self.now))

    def test_cup_quote_rejects_draw_and_settles_shootout_once(self):
        self.add_cup_prediction()
        market = repo.get_market(1, 1)
        self.assertEqual([o['outcome'] for o in market['options']], ['home_win', 'away_win'])
        self.assertEqual(market['settlement_rule'], SETTLEMENT_RULE)
        with self.assertRaises(HTTPException) as error:
            repo.mutate_bet(1, 1, {**self.body(outcome='draw'), 'prediction_run_id': 'e' * 64})
        self.assertEqual(error.exception.detail['code'], 'outcome_unavailable')
        self.assertFalse(repo.get_wallet(1)['initialized'])
        first = repo.mutate_bet(1, 1, {**self.body(), 'prediction_run_id': 'e' * 64})
        self.execute('UPDATE fixtures SET state_id=8,home_score=1,away_score=1 WHERE fixture_id=1')
        self.assertIsNone(repo.settle_bet(first['bet']['bet_id'], apply=True))
        self.assertEqual(repo.get_wallet(1)['balance'], 900)
        self.execute('UPDATE fixtures SET home_penalty_score=5,away_penalty_score=4 WHERE fixture_id=1')
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: repo.settle_bet(first['bet']['bet_id'], apply=True), [1, 2]))
        self.assertEqual(results.count(None), 1)
        self.assertEqual(repo.get_wallet(1)['balance'], 900 + first['bet']['potential_return'])

    def test_cup_different_league_teams_need_no_league_run_and_context_changes_close_quote(self):
        self.add_cup_prediction(draw_allowed=True)
        self.execute('DELETE FROM probability_team_results')
        self.assertTrue(repo.get_market(1, 1)['can_bet'])
        self.execute('UPDATE fixtures SET starting_at=starting_at+INTERVAL 1 DAY WHERE fixture_id=1')
        self.assertFalse(repo.get_market(1, 1)['available'])

    def test_cup_first_leg_correction_invalidates_quote(self):
        self.execute('UPDATE fixtures SET state_id=5,home_score=0,away_score=0 WHERE fixture_id=2')
        self.add_cup_prediction(first_leg={'fixture_id': 2, 'home_score': 0, 'away_score': 0})
        self.assertTrue(repo.get_market(1, 1)['can_bet'])
        self.execute('UPDATE fixtures SET home_score=1 WHERE fixture_id=2')
        self.assertFalse(repo.get_market(1, 1)['available'])

    def test_cup_final_score_wins_even_when_opponent_wins_shootout(self):
        self.add_cup_prediction(draw_allowed=True)
        first = repo.mutate_bet(1, 1, {**self.body(), 'prediction_run_id': 'e' * 64})
        self.execute('''UPDATE fixtures SET state_id=8,home_score=1,away_score=0,
            home_penalty_score=3,away_penalty_score=5 WHERE fixture_id=1''')
        self.assertEqual(repo.settle_bet(first['bet']['bet_id'], apply=True)['status'], 'won')

    def test_cup_quote_http_contract_and_no_post_kickoff_prediction(self):
        self.add_cup_prediction()
        app = create_app()
        app.dependency_overrides[get_user_id] = lambda: 1
        with TestClient(app) as client:
            response = client.get('/v1/fixtures/1/betting')
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual(len(response.json()['options']), 2)
        self.execute('UPDATE fixtures SET starting_at=%s,state_id=5 WHERE fixture_id=1', (self.now,))
        self.assertFalse(repo.get_market(1, 1)['available'])

    def test_cup_loader_saved_snapshot_is_accepted_by_market_and_bet(self):
        from one_touch_loader.core.cup_betting import MODEL_METHOD
        from one_touch_loader.loaders.cup_betting_loader import prepare_runs
        from one_touch_loader.loaders.probability_loader import store_model, store_runs
        self.execute("UPDATE stages SET stage_type_id=224,name='Final' WHERE stage_id=2")
        self.execute('UPDATE fixtures SET stage_id=2 WHERE fixture_id=1')
        fixture = self.execute(repo.FIXTURE_SQL, (1,))[0]
        report = {'model_id': 'f' * 64, 'method': MODEL_METHOD, 'settlement_rule': SETTLEMENT_RULE,
                  'forecast_model': {'coefficients': [.5, 1.3, .2, -1.2],
                                     'last_training_fixture_at': '2026-05-30 12:00:00'}}
        histories = {10: [{'date': '2026-09-17', 'elo': 1800}], 20: [{'date': '2026-09-17', 'elo': 1700}]}
        runs, excluded = prepare_runs([fixture], histories, report, observed_at=self.now.replace(tzinfo=timezone.utc))
        self.assertEqual(excluded, [])
        store_model(report)
        run_id = store_runs(runs)[0]
        market = repo.get_market(1, 1)
        self.assertEqual(market['prediction_run_id'], run_id)
        self.assertEqual(len(market['options']), 2)
        bet = repo.mutate_bet(1, 1, {**self.body(), 'prediction_run_id': run_id})
        self.assertEqual(bet['wallet']['balance'], 900)
        self.assertEqual(bet['bet']['prediction_run_id'], run_id)

    def test_win_loss_refund_and_repeated_worker_are_atomic(self):
        winner = repo.mutate_bet(1, 1, self.body())
        loser = repo.mutate_bet(2, 1, self.body(100, 'away_win'))
        self.execute('UPDATE fixtures SET state_id=5,home_score=2,away_score=0 WHERE fixture_id=1')
        self.assertEqual(repo.settle_bet(winner['bet']['bet_id'])['payout'], winner['bet']['potential_return'])
        self.assertEqual(repo.get_wallet(1)['balance'], 900)
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: repo.settle_bet(winner['bet']['bet_id'], apply=True), [1, 2]))
        self.assertEqual(results.count(None), 1)
        self.assertEqual(repo.get_wallet(1)['balance'], 900 + winner['bet']['potential_return'])
        self.assertEqual(repo.settle_bet(loser['bet']['bet_id'], apply=True)['payout'], 0)
        refund = repo.mutate_bet(2, 2, self.body())
        self.execute('UPDATE fixtures SET state_id=10 WHERE fixture_id=2')
        self.assertEqual(repo.settle_bet(refund['bet']['bet_id'], apply=True)['payout'], 100)
        self.assertEqual(repo.get_wallet(2)['balance'], 900)

    def test_failed_ledger_write_rolls_back_bet_and_balance(self):
        repo.initialize_wallet(1)
        with patch.object(repo, '_entry', side_effect=RuntimeError('test failure')):
            with self.assertRaises(RuntimeError):
                repo.mutate_bet(1, 1, self.body())
        self.assertEqual(repo.get_wallet(1)['balance'], 1000)
        self.assertEqual(self.execute('SELECT * FROM fixture_bets'), [])

    def test_past_match_excludes_post_match_and_reconstructed_predictions(self):
        self.execute('UPDATE fixtures SET starting_at=%s,state_id=5 WHERE fixture_id=1', (self.now - timedelta(days=1),))
        self.add_prediction('d' * 64, self.now - timedelta(days=2), kind='reconstructed')
        self.assertFalse(repo.get_market(1, 1)['available'])

    def test_http_contract_uses_session_user_and_preserves_decimal_probability(self):
        app = create_app()
        app.dependency_overrides[get_user_id] = lambda: 1
        with TestClient(app) as client:
            self.assertEqual(client.post('/v1/users/me/points/initialize').json()['balance'], 1000)
            body = client.get('/v1/fixtures/1/betting').json()
            self.assertEqual(body['prediction_run_id'], 'a' * 64)
            self.assertEqual(len(body['options'][0]['probability'].split('.')[1]), 18)
            response = client.put('/v1/fixtures/1/bet', json=self.body())
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual(response.json()['wallet']['balance'], 900)

    def test_account_deletion_cascades_points_and_bets_without_removing_match(self):
        repo.mutate_bet(1, 1, self.body())
        self.execute('DELETE FROM users WHERE user_id=1')
        for table in ('user_point_wallets', 'fixture_bets', 'user_point_entries'):
            self.assertEqual(self.execute(f'SELECT * FROM {table}'), [])
        self.assertEqual(len(self.execute('SELECT * FROM fixtures WHERE fixture_id=1')), 1)


if __name__ == '__main__':
    unittest.main()
