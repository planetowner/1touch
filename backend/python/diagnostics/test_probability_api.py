from __future__ import annotations

from copy import deepcopy
from datetime import date, datetime, timezone
import json
import sqlite3
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

with patch("mysql.connector.pooling.MySQLConnectionPool") as pool:
    pool.return_value.get_connection.side_effect = AssertionError("Operational DB access in isolated tests")
    from one_touch_loader.api.main import create_app
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.repos import probability_repo as repo
    from one_touch_loader.api.routes import teams as routes

from diagnostics.test_probability_pipeline import league_input
from one_touch_loader.core.probability_forecast import forecast_day
from one_touch_loader.core.probability_storage import split_run


class ProbabilityApiTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:", check_same_thread=False)
        self.addCleanup(self.db.close)
        self.db.row_factory = sqlite3.Row
        self.db.create_function("UNIX_TIMESTAMP", 1,
                                lambda value: datetime.fromisoformat(value).replace(tzinfo=timezone.utc).timestamp())
        self.db.create_function('JSON_UNQUOTE', 1, lambda value: value)
        self.db.create_function('JSON_LENGTH', 1, lambda value: len(json.loads(value)) if value else None)
        self.db.executescript("""
            CREATE TABLE teams (team_id INTEGER PRIMARY KEY,name TEXT);
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY,competition_id INTEGER,name TEXT,is_current INTEGER DEFAULT 1);
            CREATE TABLE stages (stage_id INTEGER PRIMARY KEY,season_id INTEGER,stage_type_id INTEGER);
            CREATE TABLE tournament_brackets (season_id INTEGER PRIMARY KEY,input_sha256 TEXT,payload TEXT,fetched_at TEXT);
            CREATE TABLE rounds (round_id INTEGER PRIMARY KEY,name TEXT);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY,home_team_id INTEGER,away_team_id INTEGER,starting_at TEXT,round_id INTEGER,stage_id INTEGER);
            CREATE TABLE probability_team_results (run_id TEXT,team_id INTEGER,next_fixture_id INTEGER,payload TEXT,PRIMARY KEY(run_id,team_id));
            CREATE TABLE probability_models (model_id TEXT PRIMARY KEY,payload TEXT);
            CREATE TABLE probability_runs (run_id TEXT PRIMARY KEY,model_id TEXT,season_id INTEGER,as_of TEXT,payload TEXT,created_at TEXT);
        """)
        self.model_id = "a" * 64
        self.db.execute("INSERT INTO probability_models VALUES (?,?)", (self.model_id, json.dumps({"method": "multinomial_logistic_elo_difference_v1", "validation": {"metrics": {"fixtures": 1713, "log_loss": 0.9997}}})))
        args = league_input()
        self.db.execute("INSERT INTO seasons VALUES (1,82,'2026/2027',1)")
        self.db.executemany('INSERT INTO teams VALUES (?,?)', [(t['team_id'],t['name']) for t in args['teams']])
        self.db.executemany('INSERT INTO fixtures VALUES (?,?,?,?,NULL,NULL)', [(f['fixture_id'],f['home_team_id'],f['away_team_id'],f['starting_at']) for f in args['fixtures']])
        args["fixtures"][0].update(starting_at="2026-09-09 14:00:00", state_id=5, home_score=1, away_score=0)
        args["as_of"] = date(2026, 9, 9)
        self.previous = forecast_day(**args)
        self.add_run("first", self.previous)
        self.pre_match = deepcopy(self.previous)
        self.pre_match.update(as_of='2026-09-09T13:30:00Z', cutoff='observed_state', history_kind='observed_calculation')
        self.add_run('pre-match', self.pre_match)
        args["as_of"] = date(2026, 9, 10)
        args["include_what_if"] = True
        self.latest = forecast_day(**args)
        self.add_run("latest", self.latest)
        for name, replacement in (("fetch_all_dict", self.fetch_all), ("fetch_one_dict", self.fetch_one)):
            p = patch.object(repo, name, side_effect=replacement)
            p.start()
            self.addCleanup(p.stop)
        p = patch.object(routes, "find_team_current_context", return_value=(82, 1))
        self.context = p.start()
        self.addCleanup(p.stop)
        self.app = create_app()
        self.app.dependency_overrides[get_user_id] = lambda: 42
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)

    def add_run(self, run_id, run, *, created_at=None):
        metadata, rows = split_run(run)
        self.db.execute("INSERT INTO probability_runs VALUES (?,?,?,?,?,?)", (
            run_id, run["model_id"], 1, run["as_of"].replace('T',' ').removesuffix('Z'), json.dumps(metadata),
            created_at or run['as_of'].replace('Z', '+00:00')))
        self.db.executemany('INSERT INTO probability_team_results VALUES (?,?,?,?)', [(run_id,t,f,json.dumps(p)) for t,f,p in rows])

    def fetch_all(self, sql, params=()):
        return [dict(r) for r in self.db.execute(sql.replace("%s", "?"), params)]

    def fetch_one(self, sql, params=()):
        rows = self.fetch_all(sql, params)
        return rows[0] if rows else None

    def test_full_contract_history_comparison_units_and_what_if(self):
        response = self.client.get("/v1/teams/1/probability")
        self.assertEqual(response.status_code, 200, response.text)
        body = response.json()
        self.assertEqual(body['comparison'], {'available': True, 'basis': 'previous_league_fixture_pre_match_snapshot',
                         'as_of': '2026-09-09T13:30:00Z', 'fixture_at': '2026-09-09T14:00:00Z'})
        self.assertEqual(body["current_points"], 3)
        self.assertEqual(len(body["positions"]), 18)
        self.assertEqual(len(body["history"]), 2)
        self.assertEqual(body["history"][0]["kind"], "reconstructed")
        self.assertEqual(body["projected_points"]["likely_range"]["target_coverage"], .8)
        previous = {e["event"]: e["probability"] for e in self.pre_match["teams"]["1"]["events"]}
        for event in body["events"]:
            self.assertAlmostEqual(event["change_pp"], (event["probability"] - previous[event["event"]]) * 100)
        self.assertEqual([s["outcome"] for s in body["what_if"]["scenarios"]], ["win", "draw", "loss"])
        self.assertIn("ucl_qualification", body["pending_outcomes"])
        self.assertNotIn("training_rows", body)

    def test_missing_comparison_is_null_not_zero(self):
        self.db.execute("DELETE FROM probability_runs WHERE run_id='pre-match'")
        body = self.client.get("/v1/teams/1/probability?season_id=1").json()
        self.assertFalse(body["comparison"]["available"])
        self.assertTrue(all(e["change_pp"] is None for e in body["events"]))
        self.assertIsNone(body["projected_points"]["change_points"])
        self.context.assert_not_called()

    def test_observed_run_compares_to_pre_match_snapshot_not_daily_history_or_post_match(self):
        post_match = deepcopy(self.latest)
        post_match.update(as_of='2026-09-09T16:00:00Z', cutoff='observed_state', history_kind='observed_calculation')
        self.add_run('post-match', post_match)
        self.latest["as_of"] = "2026-09-10T17:00:00Z"
        self.latest["history_kind"] = "observed_calculation"
        self.latest["cutoff"] = "observed_state"
        self.add_run('observed', self.latest)
        body = self.client.get("/v1/teams/1/probability").json()
        self.assertEqual(body["cutoff"], "observed_state")
        self.assertEqual(body["comparison"]["as_of"], "2026-09-09T13:30:00Z")
        self.assertTrue(body["comparison"]["available"])
        self.assertEqual([row["kind"] for row in body["history"]], ["reconstructed", "reconstructed", "observed_calculation"])

    def test_different_models_are_not_mixed_into_history(self):
        self.db.execute("UPDATE probability_runs SET model_id='different' WHERE run_id IN ('first','pre-match')")
        body = self.client.get("/v1/teams/1/probability").json()
        self.assertEqual(len(body["history"]), 1)
        self.assertFalse(body["comparison"]["available"])

    def test_unknown_team_uncomputed_season_and_bad_parameter(self):
        for url, status in (("/v1/teams/999/probability", 404),
                            ("/v1/teams/1/probability?season_id=2", 404),
                            ("/v1/teams/1/probability?season_id=0", 422)):
            self.assertEqual(self.client.get(url).status_code, status)

    def test_league_latest_pre_match_snapshot_drives_both_event_and_points_changes(self):
        closer = deepcopy(self.pre_match)
        closer['as_of'] = '2026-09-09T13:59:00Z'
        team = closer['teams']['1']
        team['events'][0]['probability'] = .20
        team['projected_points']['mean'] = 70
        self.add_run('closest', closer)
        response = self.client.get('/v1/teams/1/probability')
        self.assertEqual(response.status_code, 200, response.text)
        body = response.json()
        self.assertEqual(body['comparison']['as_of'], '2026-09-09T13:59:00Z')
        title = next(e for e in body['events'] if e['event'] == 'league_winner')
        self.assertAlmostEqual(title['change_pp'], (title['probability'] - .20) * 100)
        self.assertAlmostEqual(body['projected_points']['change_points'], body['projected_points']['mean'] - 70)
        self.assertEqual(len(body['history']), 2)

    def test_league_rejects_kickoff_late_storage_reconstructed_and_wrong_match_records(self):
        for sql in (
            "UPDATE probability_runs SET as_of='2026-09-09 14:00:00' WHERE run_id='pre-match'",
            "UPDATE probability_runs SET created_at='2026-09-09T14:00:00+00:00' WHERE run_id='pre-match'",
            "UPDATE probability_runs SET payload=json_set(payload,'$.cutoff','utc_day_start') WHERE run_id='pre-match'",
            "UPDATE probability_runs SET payload=json_set(payload,'$.outcome_kind','european_title_v1') WHERE run_id='pre-match'",
            "UPDATE probability_runs SET payload=json_set(payload,'$.market_kind','cup') WHERE run_id='pre-match'",
            "UPDATE probability_team_results SET payload=json_set(payload,'$.played',1) WHERE run_id='pre-match' AND team_id=1",
            "UPDATE probability_runs SET season_id=3 WHERE run_id='pre-match'",
        ):
            with self.subTest(sql=sql):
                self.db.execute('SAVEPOINT candidate')
                self.db.execute(sql)
                body = self.client.get('/v1/teams/1/probability').json()
                self.assertFalse(body['comparison']['available'])
                self.assertIsNone(body['comparison']['as_of'])
                self.assertTrue(all(e['change_pp'] is None for e in body['events']))
                self.assertIsNone(body['projected_points']['change_points'])
                self.db.execute('ROLLBACK TO candidate')
                self.db.execute('RELEASE candidate')

    def test_league_old_payload_or_no_completed_match_is_unavailable(self):
        for expression in ("json_remove(payload,'$.previous_fixture_at')",
                           "json_set(payload,'$.previous_fixture_at',NULL,'$.played',0)"):
            with self.subTest(expression=expression):
                self.db.execute('SAVEPOINT current_team')
                self.db.execute(f"UPDATE probability_team_results SET payload={expression} WHERE run_id='latest' AND team_id=1")
                body = self.client.get('/v1/teams/1/probability').json()
                self.assertFalse(body['comparison']['available'])
                self.assertIsNone(body['comparison']['fixture_at'])
                self.assertTrue(all(e['change_pp'] is None for e in body['events']))
                self.db.execute('ROLLBACK TO current_team')
                self.db.execute('RELEASE current_team')

    def test_requires_member_token(self):
        self.app.dependency_overrides.clear()
        response = self.client.get("/v1/teams/1/probability")
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.headers["WWW-Authenticate"], "Bearer")

    def test_openapi_exposes_nullable_change_and_named_response(self):
        schema = self.client.get("/openapi.json").json()
        route = schema["paths"]["/v1/teams/{team_id}/probability"]["get"]
        self.assertEqual(route["security"], [{"HTTPBearer": []}])
        self.assertIn("TeamProbabilityResponse", schema["components"]["schemas"])

    def add_european_run(self, competition_id=5, event='uel_winner', *, run_id='europe',
                         model_id='europe-model', as_of='2026-09-21 12:00:00',
                         probability=.13, played=None, previous_fixture_at=None):
        self.db.execute("INSERT OR IGNORE INTO seasons VALUES (2,?,'2026/2027',1)", (competition_id,))
        payload = {'outcome_kind': 'european_title_v1', 'simulations': 100000,
            'probability_method': 'european_title_poisson_elo_v1',
            'strength_source_url': 'https://clubelo.com/Ranking',
            'coefficient_source_url': 'https://www.uefa.com/nationalassociations/uefarankings/club/?year=2026',
            'validation': {'score_log_loss': 2.92}, 'limitations': ['Undrawn knockout paths']}
        self.db.execute('INSERT INTO probability_runs VALUES (?,?,?,?,?,?)', (
            run_id, model_id, 2, as_of, json.dumps(payload), as_of))
        team = {'event': event, 'probability': probability, 'sampling_standard_error_pp': .1}
        if played is not None:
            team.update(played=played, previous_fixture_at=previous_fixture_at)
        self.db.execute('INSERT INTO probability_team_results VALUES (?,?,NULL,?)', (
            run_id, 1, json.dumps(team)))

    def test_european_changes_use_latest_snapshot_before_own_match_for_all_competitions(self):
        for competition, event, probability in ((2, 'ucl_winner', .10), (5, 'uel_winner', .25),
                                                 (2286, 'uecl_winner', .20)):
            with self.subTest(competition=competition):
                self.add_european_run(competition, event, run_id='early', as_of='2026-09-18 12:00:00',
                                     probability=.18, played=0)
                self.add_european_run(competition, event, run_id='before', as_of='2026-09-19 18:00:00',
                                     probability=.20, played=0)
                self.add_european_run(competition, event, run_id='after', as_of='2026-09-19 22:00:00',
                                     probability=.22, played=1, previous_fixture_at='2026-09-19T19:00:00Z')
                self.add_european_run(competition, event, probability=probability, played=1,
                                     previous_fixture_at='2026-09-19T19:00:00Z')
                response = self.client.get('/v1/teams/1/probability')
                self.assertEqual(response.status_code, 200, response.text)
                body = response.json()
                euro = body['european_title']
                self.assertAlmostEqual(euro['change_pp'], (probability - .20) * 100)
                self.assertEqual(euro['comparison'], {
                    'basis': 'previous_european_fixture_pre_match_snapshot', 'available': True,
                    'as_of': '2026-09-19T18:00:00Z', 'fixture_at': '2026-09-19T19:00:00Z'})
                self.assertEqual(body['comparison']['as_of'], '2026-09-09T13:30:00Z')
                self.assertEqual(len(body['history']), 2)
                for key in ('cards', 'events'):
                    title = next(e for e in body[key] if e['event'] == event)
                    self.assertEqual(title['change_pp'], euro['change_pp'])
                self.db.execute('DELETE FROM probability_team_results WHERE run_id IN '
                                "(SELECT run_id FROM probability_runs WHERE season_id=2)")
                self.db.execute('DELETE FROM probability_runs WHERE season_id=2')
                self.db.execute('DELETE FROM seasons WHERE season_id=2')

    def test_european_comparison_rejects_other_model_season_and_stale_match_state(self):
        self.add_european_run(played=2, previous_fixture_at='2026-09-19T19:00:00Z')
        self.add_european_run(run_id='before', as_of='2026-09-19 18:00:00', probability=.20, played=1,
                             previous_fixture_at='2026-09-10T19:00:00Z')
        self.assertTrue(self.client.get('/v1/teams/1/probability').json()['european_title']['comparison']['available'])
        for sql in ("UPDATE probability_runs SET model_id='different' WHERE run_id='before'",
                    "UPDATE probability_runs SET season_id=3 WHERE run_id='before'",
                    "UPDATE probability_runs SET as_of='2026-09-19 19:00:00' WHERE run_id='before'",
                    "UPDATE probability_runs SET created_at='2026-09-19 19:00:00' WHERE run_id='before'",
                    "UPDATE probability_team_results SET payload=json_set(payload,'$.played',0) WHERE run_id='before'",
                    "UPDATE probability_team_results SET payload=json_remove(payload,'$.played') WHERE run_id='before'",
                    "UPDATE probability_runs SET payload=json_set(payload,'$.outcome_kind','other') WHERE run_id='before'"):
            with self.subTest(sql=sql):
                self.db.execute('SAVEPOINT candidate')
                self.db.execute(sql)
                euro = self.client.get('/v1/teams/1/probability').json()['european_title']
                self.assertIsNone(euro['change_pp'])
                self.assertFalse(euro['comparison']['available'])
                self.assertIsNone(euro['comparison']['as_of'])
                self.db.execute('ROLLBACK TO candidate')
                self.db.execute('RELEASE candidate')

    def test_european_missing_history_or_first_match_is_null_not_zero(self):
        for played in (None, 0, 1):
            with self.subTest(played=played):
                self.add_european_run(played=played,
                    previous_fixture_at='2026-09-19T19:00:00Z' if played else None)
                euro = self.client.get('/v1/teams/1/probability').json()['european_title']
                self.assertEqual(euro['probability'], .13)
                self.assertIsNone(euro['change_pp'])
                self.assertFalse(euro['comparison']['available'])
                self.db.execute("DELETE FROM probability_runs WHERE run_id='europe'")
                self.db.execute("DELETE FROM probability_team_results WHERE run_id='europe'")

    def test_european_competition_card_uses_own_model_and_does_not_mix_history(self):
        for competition, event in ((2, 'ucl_winner'), (5, 'uel_winner'), (2286, 'uecl_winner')):
            with self.subTest(competition=competition):
                self.add_european_run(competition, event)
                response = self.client.get('/v1/teams/1/probability')
                self.assertEqual(response.status_code, 200, response.text)
                body = response.json()
                euro = body['european_title']
                self.assertEqual(euro['competition_id'], competition)
                self.assertEqual(euro['model_id'], 'europe-model')
                self.assertEqual(body['model_id'], self.model_id)
                self.assertEqual(len(body['history']), 2)
                card = next(c for c in body['cards'] if c['event'] == event)
                self.assertEqual(card['probability'], .13)
                self.assertIsNone(card['change_pp'])
                self.assertNotIn('european_title', body['pending_outcomes'])
                self.db.execute("DELETE FROM seasons WHERE season_id=2")
                self.db.execute("DELETE FROM probability_runs WHERE run_id='europe'")
                self.db.execute("DELETE FROM probability_team_results WHERE run_id='europe'")

    def test_missing_inactive_other_season_or_drawn_europe_is_not_a_zero_card(self):
        self.assertIsNone(self.client.get('/v1/teams/1/probability').json()['european_title'])
        self.add_european_run()
        for change in ("UPDATE seasons SET is_current=0 WHERE season_id=2",
                       "UPDATE seasons SET name='2025/2026' WHERE season_id=2"):
            self.db.execute(change)
            self.assertIsNone(self.client.get('/v1/teams/1/probability').json()['european_title'])
            self.db.execute("UPDATE seasons SET is_current=1,name='2026/2027' WHERE season_id=2")
        self.db.execute('INSERT INTO stages VALUES (200,2,224)')
        self.db.execute("INSERT INTO fixtures VALUES (999,1,2,'2027-02-01',NULL,200)")
        body = self.client.get('/v1/teams/1/probability').json()
        self.assertIsNone(body['european_title'])
        self.assertFalse(any(c['event']=='uel_winner' for c in body['cards']))

    def test_drawn_title_requires_current_bracket_fingerprint(self):
        self.add_european_run()
        self.db.execute('INSERT INTO stages VALUES (200,2,224)')
        self.db.execute("INSERT INTO fixtures VALUES (999,1,2,'2027-02-01',NULL,200)")
        self.db.execute('INSERT INTO tournament_brackets VALUES (?,?,?,?)',
                        (2, 'confirmed', json.dumps({'stages': [{'key': 'final'}]}), '2027-05-01'))
        payload = json.loads(self.db.execute("SELECT payload FROM probability_runs WHERE run_id='europe'").fetchone()[0])
        payload['bracket_input_sha256'] = 'confirmed'
        self.db.execute("UPDATE probability_runs SET payload=? WHERE run_id='europe'", (json.dumps(payload),))
        self.assertIsNotNone(self.client.get('/v1/teams/1/probability').json()['european_title'])
        self.db.execute("UPDATE tournament_brackets SET input_sha256='new-result'")
        self.assertIsNone(self.client.get('/v1/teams/1/probability').json()['european_title'])
        # 전체 대진에 새 추첨이 있고 기존 fixtures에는 아직 없어도 예전 추첨 전 확률을 숨겨요.
        self.db.execute('DELETE FROM fixtures WHERE fixture_id=999')
        self.assertIsNone(self.client.get('/v1/teams/1/probability').json()['european_title'])


if __name__ == "__main__":
    unittest.main()
