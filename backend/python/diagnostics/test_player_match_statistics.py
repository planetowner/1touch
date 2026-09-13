from __future__ import annotations

from copy import deepcopy
from decimal import Decimal
import json
from pathlib import Path
import sqlite3
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from diagnostics import test_fixture_details as existing
from one_touch_loader.api.deps import get_user_id
from one_touch_loader.api.routes import fixtures as routes
from one_touch_loader.core.player_match_metrics import (
    CATEGORIES, METRICS, STORED_STAT_TYPE_IDS, build_player_statistics,
)
from one_touch_loader.loaders import fixture_details_loader as loader


SAMPLE = json.loads((Path(__file__).parent / "fixtures/player_match_statistics.json").read_text(encoding="utf-8"))


def output_for(case):
    rows = loader.normalize_fixture_lineups({"lineups": case["lineups"], "formations": []}, case["fixture_id"])
    lineups = [dict(zip(("fixture_id", "team_id", "player_id", "lineup_type_id", "formation_field",
                        "jersey_number", "minutes_played", "rating", "match_position_id"), row))
               for row in rows["lineups"]]
    stats = [dict(zip(("fixture_id", "team_id", "player_id", "stat_type_id", "value"), row))
             for row in rows["player_stats"]]
    xg_rows = [{**row, "xg": Decimal(row["xg"])} for row in SAMPLE["xg_rows"]
               if row["fixture_id"] == case["fixture_id"]]
    return build_player_statistics(lineups, stats, xg_rows)


def metrics(player):
    return {metric["code"]: metric for category in player["categories"] for metric in category["metrics"]}


class PlayerMetricTests(unittest.TestCase):
    def test_actual_response_maps_positions_counts_ratios_and_understat_xg(self):
        gk, df, mf, fw = output_for(SAMPLE["cases"][0])
        self.assertEqual([p["position_group"] for p in (gk, df, mf, fw)], ["GK", "DF", "MF", "FW"])
        self.assertEqual([len(p["categories"]) for p in (gk, df, mf, fw)], [4, 4, 5, 5])
        self.assertEqual(metrics(gk)["saves"]["value"], 4)
        self.assertEqual(metrics(gk)["passes"]["numerator"], 19)
        self.assertEqual(metrics(gk)["passes"]["denominator"], 34)
        self.assertEqual(metrics(gk)["long_ball_success_rate"]["value"], 34.8)
        self.assertEqual(metrics(df)["long_ball_success_rate"]["value"], 40.0)
        self.assertEqual(metrics(mf)["shots"]["value"], 4)
        self.assertEqual(metrics(mf)["xg"]["value"], Decimal("0.172853"))
        self.assertEqual(metrics(fw)["xg"]["value"], Decimal("1.212923"))
        self.assertEqual(metrics(fw)["goals"]["value"], 1)
        self.assertEqual(metrics(fw)["xg"]["source"], "understat")
        self.assertIsNone(gk["is_man_of_match"])
        self.assertTrue(output_for(SAMPLE["cases"][1])[0]["is_man_of_match"])

    def test_approved_categories_have_no_removed_or_duplicate_metrics(self):
        for position, categories in CATEGORIES.items():
            codes = [code for _, _, codes in categories for code in codes]
            self.assertEqual(len(codes), len(set(codes)))
            self.assertTrue(all(2 <= len(codes) <= 3 for _, _, codes in categories))
            if position in (24, 25):
                self.assertNotIn("high_claim", [code for code, _, _ in categories])
                self.assertNotIn("dribbling", [code for code, _, _ in categories])
                self.assertNotIn("dribble", [code for code, _, _ in categories])
        self.assertNotIn(584, STORED_STAT_TYPE_IDS)
        self.assertNotIn(103, STORED_STAT_TYPE_IDS)
        self.assertNotIn(27267, STORED_STAT_TYPE_IDS)
        self.assertNotIn(5304, STORED_STAT_TYPE_IDS)
        self.assertEqual(set(METRICS), {code for cats in CATEGORIES.values() for _, _, codes in cats for code in codes})

    def test_absence_zero_and_invalid_percentage_remain_distinct(self):
        case = deepcopy(SAMPLE["cases"][0])
        fw = case["lineups"][-1]
        case["lineups"] = [fw]
        for details, expected in (
            ([], None),
            ([(108, 3)], None),
            ([(109, 0), (108, 3)], 0.0),
            ([(109, 0), (108, 0)], None),
            ([(109, 4), (108, 3)], None),
            ([(109, 1), (108, 3)], 33.3),
        ):
            with self.subTest(details=details):
                fw["details"] = [{"type_id": key, "data": {"value": value}} for key, value in details]
                result = output_for(case)[0]
                self.assertEqual(metrics(result)["dribble_success_rate"]["value"], expected)
                self.assertIsNone(metrics(result)["goals"]["value"])
                self.assertIsNone(result["rating"])
        fw["details"] = [{"type_id": 52, "data": {"value": 0}}, {"type_id": 79, "data": {"value": None}}]
        result = output_for(case)[0]
        self.assertEqual(metrics(result)["goals"]["value"], 0)
        self.assertIsNone(metrics(result)["assists"]["value"])

    def test_unknown_match_position_does_not_use_profile_position(self):
        lineup = {"team_id": 10, "player_id": 100, "position_id": 24,
                  "match_position_id": None, "minutes_played": None, "rating": None}
        player = build_player_statistics([lineup], [], [])[0]
        self.assertIsNone(player["position_group"])
        self.assertEqual(player["categories"], [])

    def test_same_player_in_different_team_slots_does_not_share_sportmonks_values(self):
        lineup = {"team_id": 10, "player_id": 100, "match_position_id": 27,
                  "minutes_played": 90, "rating": 7}
        stats = [{"team_id": 10, "player_id": 100, "stat_type_id": 52, "value": 2}]
        players = build_player_statistics([lineup, {**lineup, "team_id": 20}], stats, [{"player_id": 100, "xg": 0}])
        self.assertEqual(metrics(players[0])["goals"]["value"], 2)
        self.assertIsNone(metrics(players[1])["goals"]["value"])
        self.assertEqual(metrics(players[0])["xg"]["value"], 0)
        self.assertIsNone(metrics(build_player_statistics([lineup], [], [])[0])["xg"]["value"])

    def test_unidentified_player_is_not_assigned_stats_and_duplicate_id_is_canonical(self):
        payload = existing._payload()
        lineup = payload["lineups"][0]
        lineup["details"].append({"type_id": 120, "data": {"value": 15}})
        lineup["player_id"] = 73643
        self.assertEqual(loader.normalize_fixture_lineups(payload, 500)["player_stats"], [(500, 10, 74062, 120, 15)])
        lineup["player_id"] = None
        self.assertEqual(loader.normalize_fixture_lineups(payload, 500)["player_stats"], [])

    def test_existing_http_route_serializes_categories_and_requires_member(self):
        app = FastAPI()
        app.include_router(routes.router, prefix="/v1")
        client = TestClient(app)
        with patch.object(routes, "get_fixture_detail", return_value={
            "fixture_id": 19427163, "player_statistics": output_for(SAMPLE["cases"][0]),
        }) as query:
            self.assertIn(client.get("/v1/fixtures/19427163").status_code, (401, 403))
            query.assert_not_called()
            app.dependency_overrides[get_user_id] = lambda: 1
            response = client.get("/v1/fixtures/19427163")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(metrics(response.json()["player_statistics"][2])["xg"]["value"], 0.172853)


class PlayerMetricStorageTests(unittest.TestCase):
    setUp = existing.FixtureDetailsStorageTests.setUp
    tearDown = existing.FixtureDetailsStorageTests.tearDown

    def test_replace_drops_removed_values_and_keeps_explicit_zero(self):
        payload = existing._payload()
        payload["lineups"][0]["details"].extend([
            {"type_id": 120, "data": {"value": 12}}, {"type_id": 78, "data": {"value": 0}},
        ])
        for _ in range(2):
            loader.replace_fixture_detail_rows(500, loader.normalize_fixture_lineups(payload, 500), payload["lineups"])
        self.assertEqual(self.connection.execute(
            "SELECT stat_type_id,stat_value FROM fixture_player_stats ORDER BY stat_type_id"
        ).fetchall(), [(78, 0), (120, 12)])
        loader.replace_fixture_detail_rows(500, {"stat_types": [], "team_stats": []})
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_player_stats").fetchone(), (2,))
        payload["lineups"][0]["details"] = []
        loader.replace_fixture_detail_rows(500, loader.normalize_fixture_lineups(payload, 500), payload["lineups"])
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_player_stats").fetchone(), (0,))

    def test_child_fk_failure_rolls_back_lineup_and_previous_stats(self):
        payload = existing._payload()
        payload["lineups"][0]["details"].append({"type_id": 120, "data": {"value": 12}})
        rows = loader.normalize_fixture_lineups(payload, 500)
        loader.replace_fixture_detail_rows(500, rows, payload["lineups"])
        before = self.connection.execute("SELECT * FROM fixture_player_stats").fetchall()
        rows["player_stats"] = [(500, 10, 999, 120, 2)]
        with self.assertRaises(sqlite3.IntegrityError):
            loader.replace_fixture_detail_rows(500, rows, payload["lineups"])
        self.assertEqual(self.connection.execute("SELECT * FROM fixture_player_stats").fetchall(), before)
        self.assertEqual(self.connection.execute("SELECT match_position_id FROM fixture_lineups").fetchone(), (25,))

    def test_real_provider_rows_round_trip_without_losing_values(self):
        for case in SAMPLE["cases"]:
            self.connection.execute("INSERT INTO fixtures VALUES (?)", (case["fixture_id"],))
            for lineup in case["lineups"]:
                self.connection.execute("INSERT OR IGNORE INTO teams VALUES (?)", (lineup["team_id"],))
                self.connection.execute("INSERT OR IGNORE INTO positions VALUES (?)", (lineup["player"]["detailed_position_id"],))
            self.connection.commit()
            rows = loader.normalize_fixture_lineups({**case, "formations": []}, case["fixture_id"])
            loader.replace_fixture_detail_rows(case["fixture_id"], rows, case["lineups"])
            actual = self.connection.execute(
                "SELECT fixture_id,team_id,player_id,stat_type_id,stat_value FROM fixture_player_stats WHERE fixture_id=?",
                (case["fixture_id"],),
            ).fetchall()
            self.assertEqual(sorted(actual), sorted(rows["player_stats"]))


if __name__ == "__main__":
    unittest.main()
