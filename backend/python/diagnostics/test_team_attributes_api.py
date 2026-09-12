from __future__ import annotations

from datetime import datetime
from pathlib import Path
import sqlite3
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

# API와 실제 조회용 뷰를 검사하되 운영 DB 연결은 열지 않아요.
with patch("mysql.connector.pooling.MySQLConnectionPool") as pool:
    pool.return_value.get_connection.side_effect = AssertionError("Operational DB access in isolated tests")
    from one_touch_loader.api.main import create_app
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.repos import team_attributes_repo as repo
    from one_touch_loader.api.routes import teams as routes


GROUPS = ("possession_build_up", "attacking_threat", "chance_creation", "finishing", "defending")


class TeamAttributesApiTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:", check_same_thread=False)
        self.addCleanup(self.db.close)
        self.db.row_factory = sqlite3.Row
        self.db.create_function("UNIX_TIMESTAMP", 1, lambda value: datetime.fromisoformat(value).timestamp())
        self.db.executescript("""
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY, competition_id INTEGER, name TEXT, is_current INTEGER);
            CREATE TABLE teams (team_id INTEGER PRIMARY KEY, name TEXT);
            CREATE TABLE team_attribute_regression_models (id INTEGER PRIMARY KEY, is_active INTEGER);
            CREATE TABLE team_attribute_group_scores (
                model_id INTEGER, season_id INTEGER, team_id INTEGER,
                attribute_group TEXT, display_score_0_100 REAL, updated_at TEXT
            );
            INSERT INTO teams VALUES (83, 'FC Barcelona'), (84, 'Unscored Team'), (85, 'Historical Team');
            INSERT INTO seasons VALUES
                (100, 564, '2026/2027', 1), (200, 564, '2025/2026', 0),
                (300, 564, '2021/2022', 0), (400, 564, '2027/2028', 0),
                (500, 999, '2026/2027', 1);
            INSERT INTO team_attribute_regression_models VALUES (1, 0), (2, 1);
        """)
        view = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/create_team_attribute_display_scores_view.sql"
        self.db.executescript(view.read_text(encoding="utf-8").replace("SET NAMES utf8mb4;", ""))
        for group, score in zip(GROUPS, (60.126, 70, 80, 90, 50)):
            self.add_score(83, 100, group, score)
            self.add_score(83, 200, group, 55)
        self.add_score(83, 300, "possession_build_up", 72.345)
        self.add_score(83, 300, "finishing", 65)
        self.add_score(83, 100, "possession_build_up", 95, model_id=1)
        self.add_score(84, 100, "finishing", 95, model_id=1)
        self.add_score(85, 300, "finishing", 70)
        self.add_score(83, 500, "finishing", 70)
        for name, replacement in (
            ("fetch_all_dict", self.fetch_all),
            ("fetch_one_dict", self.fetch_one),
        ):
            patcher = patch.object(repo, name, side_effect=replacement)
            patcher.start()
            self.addCleanup(patcher.stop)
        context_patcher = patch.object(routes, "find_team_current_context", return_value=(564, 100))
        self.context = context_patcher.start()
        self.addCleanup(context_patcher.stop)
        team_patcher = patch.object(routes, "get_team", side_effect=lambda team_id: self.fetch_one(
            "SELECT team_id, name FROM teams WHERE team_id=%s", (team_id,),
        ))
        team_patcher.start()
        self.addCleanup(team_patcher.stop)
        self.app = create_app()
        self.app.dependency_overrides[get_user_id] = lambda: 1
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)

    def add_score(self, team_id, season_id, group, score, model_id=2):
        self.db.execute("INSERT INTO team_attribute_group_scores VALUES (?, ?, ?, ?, ?, ?)", (
            model_id, season_id, team_id, group, score, "2026-09-12T14:02:20+00:00",
        ))

    def fetch_all(self, sql, params=()):
        return [dict(row) for row in self.db.execute(sql.replace("%s", "?"), params)]

    def fetch_one(self, sql, params=()):
        rows = self.fetch_all(sql, params)
        return rows[0] if rows else None

    def test_current_season_uses_context_and_serializes_saved_values(self):
        response = self.client.get("/v1/teams/83/attributes")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.context.assert_called_once_with(83)
        self.assertEqual(body["season_id"], 100)
        self.assertTrue(body["is_current"])
        self.assertEqual(body["model_id"], 2)
        self.assertEqual(body["team_name"], "FC Barcelona")
        self.assertEqual([body[group] for group in GROUPS], [60.13, 70, 80, 90, 50])
        self.assertEqual(body["attributes_updated_at"], "2026-09-12T14:02:20Z")
        self.assertNotIn("pressure", body)

    def test_historical_partial_scores_keep_null_fields(self):
        response = self.client.get("/v1/teams/83/attributes?season_id=300")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.context.assert_not_called()
        self.assertEqual(body["season_name"], "2021/2022")
        self.assertFalse(body["is_current"])
        self.assertEqual(body["possession_build_up"], 72.35)
        self.assertEqual(body["finishing"], 65)
        for group in ("attacking_threat", "chance_creation", "defending"):
            self.assertIn(group, body)
            self.assertIsNone(body[group])

    def test_options_only_include_this_teams_scored_big5_seasons(self):
        response = self.client.get("/v1/teams/83/attributes/options")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"team_id": 83, "items": [
            {"competition_id": 564, "season_id": 100, "season_name": "2026/2027", "is_current": True},
            {"competition_id": 564, "season_id": 200, "season_name": "2025/2026", "is_current": False},
            {"competition_id": 564, "season_id": 300, "season_name": "2021/2022", "is_current": False},
        ]})

    def test_unknown_unscored_and_other_competition_seasons_return_404(self):
        for path in ("/v1/teams/999/attributes?season_id=100",
                     "/v1/teams/84/attributes?season_id=100",
                     "/v1/teams/83/attributes?season_id=400",
                     "/v1/teams/83/attributes?season_id=500"):
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 404)

    def test_unscored_current_season_does_not_return_historical_scores(self):
        self.assertEqual(self.client.get("/v1/teams/85/attributes").status_code, 404)

    def test_team_without_current_big5_context_returns_404(self):
        self.context.return_value = None
        self.assertEqual(self.client.get("/v1/teams/83/attributes").status_code, 404)

    def test_options_distinguish_missing_team_and_no_active_scores(self):
        self.assertEqual(self.client.get("/v1/teams/999/attributes/options").status_code, 404)
        response = self.client.get("/v1/teams/84/attributes/options")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"team_id": 84, "items": []})

    def test_invalid_season_ids_return_422(self):
        for value in ("0", "-1", "invalid"):
            with self.subTest(value=value):
                self.assertEqual(self.client.get(f"/v1/teams/83/attributes?season_id={value}").status_code, 422)

    def test_both_routes_require_bearer_authentication(self):
        self.app.dependency_overrides.clear()
        for path in ("/v1/teams/83/attributes", "/v1/teams/83/attributes/options"):
            for headers in ({}, {"X-User-Id": "1"}):
                with self.subTest(path=path, headers=headers):
                    response = self.client.get(path, headers=headers)
                    self.assertEqual(response.status_code, 401)
                    self.assertEqual(response.headers["WWW-Authenticate"], "Bearer")

    def test_openapi_documents_authentication_and_nullable_scores(self):
        schema = self.client.get("/openapi.json").json()
        for path in ("/v1/teams/{team_id}/attributes", "/v1/teams/{team_id}/attributes/options"):
            self.assertEqual(schema["paths"][path]["get"]["security"], [{"HTTPBearer": []}])
        scores = schema["components"]["schemas"]["TeamAttributesResponse"]
        for group in GROUPS:
            self.assertIn(group, scores["required"])
            self.assertIn({"type": "null"}, scores["properties"][group]["anyOf"])


if __name__ == "__main__":
    unittest.main()
