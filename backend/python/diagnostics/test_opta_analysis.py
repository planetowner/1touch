from __future__ import annotations

import copy
import json
import sqlite3
import unittest
from datetime import datetime
from datetime import date
from contextlib import nullcontext
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import patch

from diagnostics.test_opta_bulk import CASES, SqliteCursor, empty_ids
from one_touch_loader.core.opta_analysis import (
    ANALYSIS_EVENTS, attacking_point, normalize_analysis, passing_metrics, team_analysis,
)
from one_touch_loader.core.opta_ids import plan_match_ids
from one_touch_loader.loaders.opta_shots_store import bind_events, replace_match


ROOT = Path(__file__).parent / "fixtures"
RAW = json.loads((ROOT / "opta-valencia-analysis.json").read_text(encoding="utf-8"))


def event(start, end=None, *, kinds=("completed_pass",), key="sample"):
    return {"external_event_id": key, "kinds": list(kinds),
            "start": {"x": start[0], "y": start[1]},
            "end": {"x": end[0], "y": end[1]} if end else None}


class AnalysisNormalizationTests(unittest.TestCase):
    def test_real_defensive_assists_merge_known_endpoint_in_either_order(self):
        cases = json.loads((ROOT / "opta-defensive-assists.json").read_text(encoding="utf-8"))
        for case in cases:
            raw = case["raw"]
            with self.subTest(match=raw["match_id"]):
                result = normalize_analysis(raw)
                reversed_raw = {**raw, "events": list(reversed(raw["events"]))}
                self.assertEqual(result, normalize_analysis(reversed_raw))
                self.assertEqual(len(result["events"]), case["expected_count"])
                combined = [e for e in result["events"] if "assist" in e["kinds"]
                            and ({"clearance", "tackle_won"} & set(e["kinds"]))]
                self.assertEqual(len(combined), 1)
                self.assertIsNotNone(combined[0]["end"])
                self.assertNotIn("completed_pass", combined[0]["kinds"])
                metrics = passing_metrics(combined, combined[0]["side"])
                self.assertEqual(metrics["progression"]["progressive_passes"], 0)
                self.assertEqual(metrics["attack"]["key_passes"], 0)

    def test_actual_two_leagues_map_every_event_and_keep_point_only_defence(self):
        cases = [(RAW, CASES[1], 1111, (1, 11), (15, 57)),
                 (json.loads((ROOT / "opta-german-analysis.json").read_text(encoding="utf-8")),
                  CASES[2], 949, (14, 11), None)]
        for raw, case, expected, key_passes, progressive in cases:
            with self.subTest(fixture=raw["match_id"]):
                result = normalize_analysis(raw)
                plan = plan_match_ids(raw, case["match"], case["fixtures"], case["lineups"], empty_ids())
                self.assertEqual(len(bind_events(result, plan, dataset="analysis")), expected)
                self.assertEqual(len({e["external_event_id"] for e in result["events"]}), expected)
                for i, side in enumerate(("home", "away")):
                    rows = [e for e in result["events"] if e["side"] == side]
                    metrics = team_analysis(rows, side)
                    self.assertEqual(metrics["attack"]["key_passes"], key_passes[i])
                    if progressive:
                        self.assertEqual(metrics["progression"]["progressive_passes"], progressive[i])
                defence = [e for e in result["events"] if "recovery" in e["kinds"]]
                self.assertTrue(defence)
                self.assertTrue(all(e["end"] is None for e in defence))

    def test_duplicate_classification_does_not_duplicate_passes_or_invent_completion(self):
        rows = normalize_analysis(RAW)["events"]
        self.assertEqual(sum("completed_pass" in e["kinds"] for e in rows), 925)
        self.assertEqual(sum("key_pass" in e["kinds"] for e in rows), 12)
        self.assertEqual(sum("assist" in e["kinds"] for e in rows), 5)
        key_only = [e for e in rows if "key_pass" in e["kinds"] and "completed_pass" not in e["kinds"]]
        self.assertEqual(len(key_only), 1)
        m = passing_metrics(key_only, key_only[0]["side"])
        self.assertEqual(m["attack"]["key_passes"], 1)
        self.assertEqual(m["progression"]["completed_passes"], 0)

    def test_actual_defensive_point_is_normalized_from_its_own_position(self):
        result = normalize_analysis(RAW)
        recovery = next(e for e in result["events"]
                        if e["external_event_id"] == RAW["match_id"] + "-ba5e91hjacvma2sjvixn00pjo-21")
        self.assertEqual(recovery["start"], {"x": 40.0, "y": 70.1})
        self.assertEqual(recovery["minute"], 3)
        self.assertIsNone(recovery["end"])

    def test_missing_filter_roster_summary_and_conflicting_duplicates_rejected(self):
        for field, value in [("all_players_selected", False), ("full_game", False),
                             ("selected_events", ["Successful passes"]), ("match_id", "wrong")]:
            raw = copy.deepcopy(RAW)
            raw[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                normalize_analysis(raw)
        raw = copy.deepcopy(RAW)
        raw["summary"]["Shots on target"]["home"] += 1
        with self.assertRaisesRegex(ValueError, "유효슈팅 수"):
            normalize_analysis(raw)
        raw = copy.deepcopy(RAW)
        first = next(e for e in raw["events"] if e["event_type"] == "Successful passes")
        raw["events"].append({**first, "coords": [*first["coords"][:2], "100", "100"]})
        with self.assertRaisesRegex(ValueError, "같은 이벤트 ID"):
            normalize_analysis(raw)


class MetricTests(unittest.TestCase):
    def test_30_15_10_metre_thresholds_accept_boundary_and_reject_shorter_pass(self):
        for start_m, gain_m in [(0, 30), (45, 15), (65, 10), (52.5, 10)]:
            for delta, expected in [(-0.001, 0), (0, 1), (0.001, 1)]:
                e = event((start_m / 105 * 100, 50), ((start_m + gain_m + delta) / 105 * 100, 50))
                with self.subTest(start_m=start_m, delta=delta):
                    self.assertEqual(passing_metrics([e], "home")["progression"]["progressive_passes"], expected)

    def test_euclidean_goal_distance_and_successful_pass_scope(self):
        # 수평 이동만으로 판정하면 골문에서 멀어지는 대각선 패스까지 전진으로 오인해요.
        wide = event((70, 50), (80, 0))
        failed = event((0, 50), (50, 50), kinds=("unsuccessful_pass",))
        key = event((0, 50), (50, 50), kinds=("key_pass",))
        metric = passing_metrics([wide, failed, key], "home")
        self.assertEqual(metric["progression"]["progressive_passes"], 0)
        self.assertEqual(metric["progression"]["completed_passes"], 1)
        self.assertEqual(metric["attack"]["key_passes"], 1)

    def test_final_third_counts_entries_not_passes_already_inside_and_excludes_assists(self):
        passes = [event((60, 50), (200 / 3, 50), key="entry"),
                  event((80, 50), (90, 50), key="inside"),
                  event((70, 50), (60, 50), key="backwards"),
                  event((60, 50), (80, 50), kinds=("key_pass", "assist"), key="assist"),
                  event((60, 50), (80, 50), kinds=("key_pass",), key="key")]
        metric = passing_metrics(passes, "home")["attack"]
        self.assertEqual(metric["final_third_entry_event_ids"], ["entry"])
        self.assertEqual(metric["key_pass_event_ids"], ["key"])

    def test_both_attack_directions_keep_same_counts_channels_and_recovery_height(self):
        home = [event((30, y), (75, y), key=str(y)) for y in (10, 50, 90)]
        home += [event((x, 20), kinds=("recovery",), key=f"r{x}") for x in (20, 50, 80)]
        home += [event((90, 90), kinds=("clearance",), key="clearance")]
        away = copy.deepcopy(home)
        for e in away:
            for key in ("start", "end"):
                if e[key] is not None:
                    e[key] = attacking_point(e[key], "away")
        h, a = team_analysis(home, "home"), team_analysis(away, "away")
        self.assertEqual(h, a)
        self.assertEqual([c["count"] for c in h["progression"]["channels"]], [1, 1, 1])
        d = h["defensive_activity"]
        self.assertEqual((d["action_count"], d["recoveries"], d["high_regains"]), (4, 3, 2))
        self.assertEqual((d["average_regain_x"], d["average_regain_height_m"]), (50, 52.5))

    def test_no_actions_means_zero_counts_but_undefined_percentages_and_averages(self):
        result = team_analysis([], "home")
        self.assertEqual(result["attack"]["key_passes"], 0)
        self.assertTrue(all(c["count"] == 0 and c["percentage"] is None for c in result["progression"]["channels"]))
        self.assertEqual(result["defensive_activity"]["high_regains"], 0)
        self.assertIsNone(result["defensive_activity"]["average_regain_x"])


class AnalysisStorageTests(unittest.TestCase):
    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.execute("PRAGMA foreign_keys=ON")
        self.conn.executescript("""
            CREATE TABLE fixtures(fixture_id INTEGER PRIMARY KEY,home_team_id INTEGER,away_team_id INTEGER);
            CREATE TABLE teams(team_id INTEGER PRIMARY KEY);
            CREATE TABLE players(player_id INTEGER PRIMARY KEY,display_name TEXT);
            CREATE TABLE fixture_opta_analyses(fixture_id INTEGER PRIMARY KEY REFERENCES fixtures,
              external_fixture_id TEXT UNIQUE,external_competition_id TEXT,external_season_id TEXT,
              source_url TEXT,home_count INTEGER,away_count INTEGER,collected_at TEXT);
            CREATE TABLE fixture_opta_events(external_event_id TEXT PRIMARY KEY,
              fixture_id INTEGER REFERENCES fixture_opta_analyses,team_id INTEGER REFERENCES teams,
              player_id INTEGER REFERENCES players,minute INTEGER,extra_minute INTEGER,kinds TEXT,
              start_x REAL,start_y REAL,end_x REAL,end_y REAL);
        """)
        for kind in ("fixture", "team", "player"):
            self.conn.execute(f"CREATE TABLE {kind}_external_ids({kind}_id INTEGER,provider TEXT,external_{kind}_id TEXT,"
                              f"PRIMARY KEY(provider,external_{kind}_id),UNIQUE(provider,{kind}_id))")
        case = CASES[1]
        self.plan = plan_match_ids(RAW, case["match"], case["fixtures"], case["lineups"], empty_ids())
        self.result = normalize_analysis(RAW)
        self.fixture_id = self.plan["fixture"]["fixture_id"]
        f = self.plan["fixture"]
        self.conn.execute("INSERT INTO fixtures VALUES (?,?,?)", (self.fixture_id, f["home_team_id"], f["away_team_id"]))
        for kind in ("team", "player"):
            for internal in set(self.plan["mappings"][kind].values()):
                sql = "INSERT INTO teams VALUES (?)" if kind == "team" else "INSERT INTO players(player_id) VALUES (?)"
                self.conn.execute(sql, (internal,))
        self.conn.commit()
        self.known = empty_ids()

    def tearDown(self):
        self.conn.close()

    def save(self, result=None):
        with self.conn:
            replace_match(SqliteCursor(self.conn), result or self.result, self.plan, self.known,
                          "2026-09-14T16:00:00+00:00", dataset="analysis")
        self.known = self.plan["mappings"]

    def test_idempotence_json_classification_nullable_endpoint_and_failed_refresh_rollback(self):
        self.save()
        self.save()
        before = self.conn.execute("SELECT * FROM fixture_opta_events ORDER BY external_event_id").fetchall()
        self.assertEqual(len(before), 1111)
        self.assertEqual(sum(row[-1] is None for row in before), 185)
        self.assertEqual(sum('"assist"' in row[6] for row in before), 5)
        self.conn.execute("""CREATE TRIGGER simulated_write_failure BEFORE INSERT ON fixture_opta_events
            BEGIN SELECT RAISE(FAIL,'simulated storage failure'); END""")
        with self.assertRaises(sqlite3.IntegrityError):
            self.save()
        self.assertEqual(self.conn.execute("SELECT * FROM fixture_opta_events ORDER BY external_event_id").fetchall(), before)

    def test_unknown_event_player_fails_without_writing_partial_match(self):
        p = self.result["events"][0]["external_player_id"]
        del self.plan["mappings"]["player"][p]
        with self.assertRaisesRegex(ValueError, "이벤트 선수를"):
            self.save()
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM fixture_opta_analyses").fetchone()[0], 0)

    def test_api_metrics_round_trip_and_uncollected_vs_zero(self):
        from one_touch_loader.api.repos import opta_analysis_repo as repo

        def query(sql, params):
            cursor = self.conn.execute(sql.replace("%s", "?"), params)
            rows = [dict(zip([d[0] for d in cursor.description], row)) for row in cursor.fetchall()]
            for row in rows:
                row["collected_at"] = datetime.fromisoformat(row["collected_at"])
            return rows

        with patch.object(repo, "fetch_all_dict", side_effect=query):
            response = repo.get_analysis(self.fixture_id)
            self.assertFalse(response["available"])
            self.assertIsNone(response["teams"])
            self.save()
            response = repo.get_analysis(self.fixture_id)
            self.assertTrue(response["available"])
            for side in ("home", "away"):
                expected = team_analysis([e for e in self.result["events"] if e["side"] == side], side)
                for section in ("attack", "progression", "defensive_activity"):
                    self.assertEqual(response["teams"][side][section], expected[section])
            self.save({**self.result, "events": [], "counts": {"home": 0, "away": 0}})
            response = repo.get_analysis(self.fixture_id)
            self.assertTrue(response["available"])
            self.assertEqual(response["teams"]["home"]["attack"]["key_passes"], 0)

    def test_route_requires_member_and_existing_fixture(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        from one_touch_loader.api.deps import get_user_id
        from one_touch_loader.api.routes import fixtures

        app = FastAPI()
        app.include_router(fixtures.router, prefix="/v1")
        with TestClient(app) as client:
            path = "/v1/fixtures/19732704/analysis"
            self.assertIn(client.get(path).status_code, (401, 403))
            app.dependency_overrides[get_user_id] = lambda: 1
            with patch.object(fixtures, "get_fixture", return_value=None):
                self.assertEqual(client.get(path).status_code, 404)
            with patch.object(fixtures, "get_fixture", return_value={"fixture_id": 19732704}), \
                 patch.object(fixtures, "get_analysis", return_value={"available": False}):
                response = client.get(path)
                self.assertEqual(response.status_code, 200)
                self.assertFalse(response.json()["available"])


class AnalysisBatchTests(unittest.TestCase):
    def test_analysis_check_uses_own_dataset_and_never_saves(self):
        from one_touch_loader.core import db
        from one_touch_loader.loaders import opta_shots_loader as loader

        case = CASES[1]
        with TemporaryDirectory() as folder:
            args = SimpleNamespace(apply=False, dataset="analysis", output_dir=Path(folder),
                competition_ids=[564], season="2026/2027", from_date=None, to_date=date(2026, 9, 6),
                refresh=False, limit=None)
            with patch.object(db, "fetch_all", return_value=[(0,)]), \
                 patch.object(loader, "load_known_ids", return_value=empty_ids()), \
                 patch.object(loader, "fetch_schedule", return_value={"season_name":"2026/2027", "matches":[case["match"]]}), \
                 patch.object(loader, "load_scope", return_value=(case["fixtures"],case["lineups"])), \
                 patch.object(loader, "open_browser", return_value=nullcontext(object())), \
                 patch.object(loader, "collect_snapshot", return_value=RAW) as collect, \
                 patch.object(loader, "save_match") as save:
                report = loader.sync_matches(args)
            save.assert_not_called()
            self.assertEqual(collect.call_args.kwargs, {"finished_only": True, "dataset": "analysis"})
            self.assertEqual((report["ready"], report["stored"], report["failed"]), (1, 0, 0))
            self.assertEqual(report["matches"][0]["events"], 1111)
            self.assertEqual(report["dataset"], "analysis")

    def test_analysis_cannot_reuse_a_shots_retry_report(self):
        from one_touch_loader.core import db
        from one_touch_loader.loaders import opta_shots_loader as loader

        with TemporaryDirectory() as folder:
            report = Path(folder) / "report.json"
            report.write_text(json.dumps({"dataset":"shots", "matches":[]}), encoding="utf-8")
            args = SimpleNamespace(apply=False, dataset="analysis", output_dir=Path(folder), retry_report=report)
            with patch.object(db, "fetch_all", return_value=[(0,)]), \
                 patch.object(loader, "load_known_ids", return_value=empty_ids()), \
                 patch.object(loader, "collect_snapshot") as collect, \
                 patch.object(loader, "save_match") as save:
                with self.assertRaisesRegex(ValueError, "수집의 종류"):
                    loader.sync_matches(args)
            collect.assert_not_called()
            save.assert_not_called()


if __name__ == "__main__":
    unittest.main()
