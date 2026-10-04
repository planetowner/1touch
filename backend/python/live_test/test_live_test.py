"""운영 DB·실제 발송 없이 임시 리그의 공통 베팅·알림 연결을 확인해요."""
from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path
import sqlite3
import unittest
from unittest.mock import patch

from . import COMPETITION_ID, SEASON_ID, SEASON_NAME, require_test_database
from .predictions import model_report, prepare_run

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.api.repos import betting_repo
    from one_touch_loader.loaders.notification_schedule import scheduled_events

NOW = datetime(2026, 10, 4, 1, tzinfo=timezone.utc)


def fixture(**changes):
    return dict(fixture_id=19745048, competition_id=COMPETITION_ID,
                season_id=SEASON_ID, season_name=SEASON_NAME, stage_type_id=223,
                stage_name='Regular Season', leg='1/1', aggregate_id=None,
                home_team_id=2921, away_team_id=361, home_team_name='Las Palmas',
                away_team_name='Real Valladolid', starting_at=NOW.replace(tzinfo=None) + timedelta(hours=15),
                state_id=1) | changes


class PredictionsTest(unittest.TestCase):
    def setUp(self):
        self.report = model_report()
        self.histories = {2921: [{'date': '2026-10-04', 'elo': 1664}],
                          361: [{'date': '2026-10-04', 'elo': 1550}]}

    def test_real_strength_drives_odds_and_missing_inputs_do_not_get_invented(self):
        run, excluded = prepare_run([fixture()], self.histories, self.report, NOW)
        options = run['fixture_markets']['19745048']['options']
        self.assertEqual(excluded, [])
        self.assertAlmostEqual(sum(float(o['probability']) for o in options), 1)
        self.assertGreater(float(options[0]['probability']), float(options[2]['probability']))
        changed, _ = prepare_run([fixture()], {**self.histories, 361: [{'date': '2026-10-04', 'elo': 1800}]}, self.report, NOW)
        self.assertNotEqual(run['input_sha256'], changed['input_sha256'])
        empty, excluded = prepare_run([fixture()], {}, self.report, NOW)
        self.assertEqual(empty['fixture_markets'], {})
        self.assertEqual(excluded, [19745048])

    def test_future_elo_and_started_or_playoff_matches_are_excluded(self):
        future = {key: [{'date': '2026-10-05', 'elo': 1600}] for key in self.histories}
        run, excluded = prepare_run([fixture()], future, self.report, NOW)
        self.assertEqual(excluded, [19745048])
        for changes in ({'state_id': 2}, {'stage_type_id': 224}, {'starting_at': NOW}, {'starting_at': None}):
            run, _ = prepare_run([fixture(**changes)], self.histories, self.report, NOW)
            self.assertEqual(run['fixture_markets'], {})

    def test_wrong_season_and_future_training_fail(self):
        with self.assertRaises(ValueError):
            prepare_run([fixture(competition_id=564)], self.histories, self.report, NOW)
        report = {**self.report, 'forecast_model': {**self.report['forecast_model'], 'last_training_fixture_at': NOW.isoformat()}}
        with self.assertRaises(ValueError):
            prepare_run([fixture()], self.histories, report, NOW)

    def test_saved_quote_uses_existing_market_and_notification_rules(self):
        run, _ = prepare_run([fixture()], self.histories, self.report, NOW)
        conn = sqlite3.connect(':memory:')
        self.addCleanup(conn.close)
        conn.row_factory = sqlite3.Row
        conn.create_function('JSON_UNQUOTE', 1, lambda value: value)
        conn.execute('CREATE TABLE probability_runs(run_id TEXT,season_id INTEGER,as_of TEXT,payload TEXT,created_at TEXT)')
        conn.execute('INSERT INTO probability_runs VALUES (?,?,?,?,?)',
                     ('a' * 64, SEASON_ID, str(NOW.replace(tzinfo=None)), json.dumps(run), str(NOW)))
        def read(sql, params):
            row = conn.execute(sql.replace('%s', '?'), params).fetchone()
            return dict(row) if row else None
        now = NOW.replace(tzinfo=None)
        prediction = betting_repo._prediction(read, fixture(), now)
        self.assertEqual(prediction['options'], run['fixture_markets']['19745048']['options'])
        self.assertIsNone(betting_repo.market_unavailable_reason(fixture(), now, prediction))
        events = scheduled_events(fixture(), now, prediction)
        self.assertEqual([e.kind for e in events], ['team_new_bets'])
        kickoff = fixture()['starting_at']
        self.assertEqual(betting_repo.market_unavailable_reason(fixture(), kickoff, prediction), 'betting_closed')
        self.assertIsNone(betting_repo._prediction(read, fixture(starting_at=kickoff + timedelta(hours=1)), now))
        self.assertIsNone(betting_repo._prediction(read, fixture(home_team_id=999), now))
        self.assertFalse(betting_repo._supported(fixture(stage_type_id=224)))

    def test_identical_inputs_do_not_create_new_quotes_and_model_provenance_is_retained(self):
        first, _ = prepare_run([fixture()], self.histories, self.report, NOW)
        second, _ = prepare_run([fixture()], self.histories, self.report, NOW + timedelta(minutes=15))
        self.assertEqual(first['input_sha256'], second['input_sha256'])
        self.assertEqual(self.report['forecast_model']['training_fixtures'], 5069)
        self.assertIn('La Liga 2 accuracy is not validated', self.report['limitations'][-1])


class IsolationTest(unittest.TestCase):
    def test_production_database_is_rejected_before_connecting(self):
        with patch.dict(os.environ, {'DB_NAME': '1touch'}):
            with self.assertRaisesRegex(RuntimeError, 'DB_NAME=onetouch_live_test'):
                require_test_database()

    def test_proxy_removal_preserves_unrelated_configuration(self):
        path = Path(__file__).parents[2] / 'deploy/live-test/proxy_route.py'
        spec = importlib.util.spec_from_file_location('live_test_proxy_route', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original = (path.parents[1] / 'vultr/Caddyfile').read_text()
        added = module.update(original, True)
        self.assertEqual(added.count(module.BEGIN), 1)
        self.assertEqual(module.update(added, True), added)
        self.assertEqual(module.update(added + '\n# unrelated edit\n', False), original + '\n# unrelated edit\n')


if __name__ == '__main__':
    unittest.main()
