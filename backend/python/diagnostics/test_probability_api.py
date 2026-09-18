from __future__ import annotations

from datetime import date, datetime
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
        self.db.create_function("UNIX_TIMESTAMP", 1, lambda value: datetime.fromisoformat(value).timestamp())
        self.db.executescript("""
            CREATE TABLE teams (team_id INTEGER PRIMARY KEY,name TEXT);
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY,competition_id INTEGER,name TEXT);
            CREATE TABLE rounds (round_id INTEGER PRIMARY KEY,name TEXT);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY,home_team_id INTEGER,away_team_id INTEGER,starting_at TEXT,round_id INTEGER);
            CREATE TABLE probability_team_results (run_id TEXT,team_id INTEGER,next_fixture_id INTEGER,payload TEXT,PRIMARY KEY(run_id,team_id));
            CREATE TABLE probability_models (model_id TEXT PRIMARY KEY,payload TEXT);
            CREATE TABLE probability_runs (run_id TEXT PRIMARY KEY,model_id TEXT,season_id INTEGER,as_of TEXT,payload TEXT,created_at TEXT);
        """)
        self.model_id = "a" * 64
        self.db.execute("INSERT INTO probability_models VALUES (?,?)", (self.model_id, json.dumps({"method": "multinomial_logistic_elo_difference_v1", "validation": {"metrics": {"fixtures": 1713, "log_loss": 0.9997}}})))
        args = league_input()
        self.db.execute("INSERT INTO seasons VALUES (1,82,'2026/2027')")
        self.db.executemany('INSERT INTO teams VALUES (?,?)', [(t['team_id'],t['name']) for t in args['teams']])
        self.db.executemany('INSERT INTO fixtures VALUES (?,?,?,?,NULL)', [(f['fixture_id'],f['home_team_id'],f['away_team_id'],f['starting_at']) for f in args['fixtures']])
        args["fixtures"][0].update(starting_at="2026-09-09 14:00:00", state_id=5, home_score=1, away_score=0)
        args["as_of"] = date(2026, 9, 9)
        self.previous = forecast_day(**args)
        self.add_run("first", self.previous)
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

    def add_run(self, run_id, run):
        metadata, rows = split_run(run)
        self.db.execute("INSERT INTO probability_runs VALUES (?,?,?,?,?,?)", (
            run_id, run["model_id"], 1, run["as_of"].replace('T',' ').removesuffix('Z'), json.dumps(metadata), "2026-09-17T12:00:00+00:00"))
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
        self.assertEqual(body["comparison"], {"available": True, "basis": "previous_league_fixture_utc_day_start", "as_of": "2026-09-09T00:00:00Z"})
        self.assertEqual(body["current_points"], 3)
        self.assertEqual(len(body["positions"]), 18)
        self.assertEqual(len(body["history"]), 2)
        self.assertEqual(body["history"][0]["kind"], "reconstructed")
        self.assertEqual(body["projected_points"]["likely_range"]["target_coverage"], .8)
        previous = {e["event"]: e["probability"] for e in self.previous["teams"]["1"]["events"]}
        for event in body["events"]:
            self.assertAlmostEqual(event["change_pp"], (event["probability"] - previous[event["event"]]) * 100)
        self.assertEqual([s["outcome"] for s in body["what_if"]["scenarios"]], ["win", "draw", "loss"])
        self.assertIn("ucl_qualification", body["pending_outcomes"])
        self.assertNotIn("training_rows", body)

    def test_missing_comparison_is_null_not_zero(self):
        self.db.execute("DELETE FROM probability_runs WHERE run_id='first'")
        body = self.client.get("/v1/teams/1/probability?season_id=1").json()
        self.assertFalse(body["comparison"]["available"])
        self.assertTrue(all(e["change_pp"] is None for e in body["events"]))
        self.assertIsNone(body["projected_points"]["change_points"])
        self.context.assert_not_called()

    def test_observed_run_compares_to_daily_baseline_not_itself(self):
        self.latest["as_of"] = "2026-09-10T17:00:00Z"
        self.latest["history_kind"] = "observed_calculation"
        self.latest["cutoff"] = "observed_state"
        self.latest["teams"]["1"]["previous_fixture_date"] = "2026-09-10"
        self.add_run('observed', self.latest)
        body = self.client.get("/v1/teams/1/probability").json()
        self.assertEqual(body["cutoff"], "observed_state")
        self.assertEqual(body["comparison"]["as_of"], "2026-09-10T00:00:00Z")
        self.assertTrue(body["comparison"]["available"])
        self.assertEqual([row["kind"] for row in body["history"]], ["reconstructed", "reconstructed", "observed_calculation"])

    def test_different_models_are_not_mixed_into_history(self):
        self.db.execute("UPDATE probability_runs SET model_id='different' WHERE run_id='first'")
        body = self.client.get("/v1/teams/1/probability").json()
        self.assertEqual(len(body["history"]), 1)
        self.assertFalse(body["comparison"]["available"])

    def test_unknown_team_uncomputed_season_and_bad_parameter(self):
        for url, status in (("/v1/teams/999/probability", 404),
                            ("/v1/teams/1/probability?season_id=2", 404),
                            ("/v1/teams/1/probability?season_id=0", 422)):
            self.assertEqual(self.client.get(url).status_code, status)

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


if __name__ == "__main__":
    unittest.main()
