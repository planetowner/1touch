from __future__ import annotations

import copy
from datetime import date, datetime, timezone
from itertools import permutations
import unittest

from one_touch_loader.core.probability_forecast import forecast_day, select_cards, league_events
from one_touch_loader.loaders.probability_training import build_dataset, train_and_validate, BIG5_IDS


def model_report():
    return {"model_id": "a" * 64, "dataset_sha256": "b" * 64, "forecast_model": {
        "coefficients": [0.4, 1.6, 0.0, -1.6], "last_training_fixture_at": "2026-05-24 19:45:00"}}


def league_input():
    teams = [{"team_id": i, "name": f"Team {i}", "short_code": f"T{i}"} for i in range(1, 19)]
    fixtures = [{"fixture_id": i, "home_team_id": h, "away_team_id": a, "starting_at": "2026-09-20 14:00:00",
                 "state_id": 1, "home_score": None, "away_score": None,
                 "season_id": 1, "competition_id": 82, "season_name": "2026/2027", "round_name": "4"}
                for i, (h, a) in enumerate(permutations(range(1, 19), 2), 1)]
    histories = {i: [{"date": "2026-08-01", "elo": 1500 + i * 10, "segment_id": 0},
                     {"date": "2026-09-10", "elo": 3000, "segment_id": 0}] for i in range(1, 19)}
    return dict(competition_id=82, season_id=1, teams=teams, fixtures=fixtures, histories=histories,
                model_report=model_report(), as_of=date(2026, 9, 10), simulations=100, seed=23, include_what_if=False)


class ForecastPipelineTests(unittest.TestCase):
    def test_cutoff_ignores_future_results_and_same_day_elo(self):
        args = league_input()
        before = forecast_day(**args)
        for fixture in args["fixtures"]:
            fixture.update(state_id=5, home_score=9, away_score=0)
        after = forecast_day(**args)
        self.assertEqual(before, after)
        self.assertEqual(after["teams"]["1"]["elo"], 1510)
        self.assertEqual(after["teams"]["1"]["current_points"], 0)

    def test_finished_yesterday_counts_but_today_does_not(self):
        args = league_input()
        yesterday, today = args["fixtures"][:2]
        yesterday.update(starting_at="2026-09-09 20:00:00", state_id=5, home_score=2, away_score=0)
        today.update(starting_at="2026-09-10 14:00:00", state_id=5, home_score=1, away_score=0)
        run = forecast_day(**args)
        self.assertEqual(run["finished_fixtures"], 1)
        self.assertEqual(run["teams"]["1"]["current_points"], 3)
        self.assertEqual(run["teams"]["1"]["played"], 1)
        self.assertEqual(run["teams"]["1"]["previous_fixture_date"], "2026-09-09")
        self.assertEqual(run['teams']['1']['previous_fixture_at'], '2026-09-09T20:00:00Z')
        self.assertEqual(run["teams"]["1"]["maximum_points"], 102)

    def test_observed_snapshot_includes_completed_today_and_known_today_elo(self):
        args = league_input()
        args["fixtures"][0].update(starting_at="2026-09-10 14:00:00", state_id=5, home_score=1, away_score=0)
        args["observed_at"] = datetime(2026, 9, 10, 17, tzinfo=timezone.utc)
        args["include_what_if"] = True
        run = forecast_day(**args)
        self.assertEqual(run["teams"]["1"]["current_points"], 3)
        self.assertEqual(run["teams"]["1"]["elo"], 3000)
        self.assertEqual(run["cutoff"], "observed_state")
        self.assertEqual(run['teams']['1']['previous_fixture_at'], '2026-09-10T14:00:00Z')
        self.assertNotEqual(run["teams"]["1"]["what_if"]["fixture"]["fixture_id"], 1)
        args["fixtures"][0]["state_id"] = 2
        live = forecast_day(**args)
        self.assertEqual(live["teams"]["1"]["current_points"], 0)
        self.assertEqual(live["finished_fixtures"], 0)

    def test_incomplete_membership_schedule_and_missing_elo_rejected(self):
        for edit, error in ((lambda a: a["teams"].pop(), "membership"),
                            (lambda a: a["fixtures"].pop(), "schedule"),
                            (lambda a: a["histories"].pop(1), "Missing Elo")):
            args = league_input()
            edit(args)
            with self.assertRaisesRegex(ValueError, error):
                forecast_day(**args)

    def test_cannot_backcast_before_model_training(self):
        args = league_input()
        args["as_of"] = date(2026, 5, 24)
        with self.assertRaisesRegex(ValueError, "model contains"):
            forecast_day(**args)

    def test_winner_totals_and_playoff_is_not_final_relegation(self):
        result = forecast_day(**league_input())
        total = sum(next(e["probability"] for e in t["events"] if e["event"] == "league_winner") for t in result["teams"].values())
        self.assertAlmostEqual(total, 1)
        for event, expected in (("direct_relegation", 2), ("relegation_playoff", 1), ("top_4", 4)):
            total = sum(next(e["probability"] for e in t["events"] if e["event"] == event) for t in result["teams"].values())
            self.assertAlmostEqual(total, expected)
        self.assertNotIn("ucl_qualification", [e["event"] for e in result["teams"]["1"]["events"]])

    def test_away_what_if_uses_away_win_not_home_win(self):
        args = league_input()
        args["include_what_if"] = True
        result = forecast_day(**args)
        what_if = result["teams"]["2"]["what_if"]
        self.assertEqual(what_if["fixture"]["away_team_id"], 2)
        scenarios = {s["outcome"]: s for s in what_if["scenarios"]}
        self.assertAlmostEqual(scenarios["win"]["projected_points"]["mean"] - scenarios["loss"]["projected_points"]["mean"], 3)

    def test_postponed_fixture_stays_in_simulation_but_is_not_next_known_fixture(self):
        args = league_input()
        args["fixtures"][0].update(state_id=10, starting_at="2026-09-01 14:00:00")
        args["include_what_if"] = True
        result = forecast_day(**args)
        self.assertEqual(result["remaining_fixtures"], 306)
        self.assertNotEqual(result["teams"]["1"]["what_if"]["fixture"]["fixture_id"], 1)

    def test_entropy_selection_diversifies_competitions_and_categories(self):
        events = [{"event": name, "competition_id": competition, "category": category, "probability": p}
                  for name, competition, category, p in [("title", 8, "TITLE", .5), ("top4", 8, "FINISH", .49),
                     ("top6", 8, "FINISH", .48), ("ucl", 2, "TITLE", .15), ("cup", 24, "TITLE", .2),
                     ("relegation", 8, "RELEGATION", 0)]]
        cards = select_cards(events)
        self.assertEqual({e["event"] for e in cards}, {"title", "top4", "ucl", "cup"})
        self.assertEqual(select_cards([events[-1]]), [])


class TrainingPipelineTests(unittest.TestCase):
    def test_training_excludes_missing_elo_and_current_season(self):
        base = {"fixture_id": 1, "competition_id": 8, "season_name": "2023/2024", "state_id": 5,
                "starting_at": "2023-08-10 15:00:00", "home_team_id": 1, "away_team_id": 2,
                "home_score": 2, "away_score": 0}
        history = {1: [{"date": "2023-08-09", "elo": 1500, "segment_id": 0}],
                   2: [{"date": "2023-08-10", "elo": 1700, "segment_id": 0}]}
        fixtures = [base, dict(base, fixture_id=2, season_name="2026/2027")]
        dataset = build_dataset(fixtures, history)
        self.assertEqual(dataset["rows"], [])
        self.assertEqual(dataset["excluded"][0]["missing_team_ids"], [2])
        self.assertEqual(len(dataset["excluded"]), 1)
        with self.assertRaisesRegex(ValueError, "Duplicate training"):
            build_dataset([base, base], history)

    def test_validation_is_later_and_refit_keeps_validation_report_distinct(self):
        rows = []
        for year in (2023, 2024, 2025):
            for league in BIG5_IDS:
                for outcome in (0, 0, 0, 1, 1, 2):
                    rows.append({"fixture_id": len(rows) + 1, "season_name": f"{year}/{year+1}",
                                 "competition_id": league, "starting_at": f"{year}-09-01 15:00:00",
                                 "elo_difference": 0.0, "outcome": outcome})
        dataset = {"rows": rows, "coverage": [], "excluded": []}
        report = train_and_validate(dataset)
        self.assertEqual(report["validation"]["training_fixtures"], 60)
        self.assertEqual(report["validation"]["metrics"]["fixtures"], 30)
        self.assertEqual(report["forecast_model"]["training_fixtures"], 90)
        changed = copy.deepcopy(dataset)
        changed["rows"][0]["starting_at"] = "2026-01-01 00:00:00"
        with self.assertRaisesRegex(ValueError, "later season"):
            train_and_validate(changed)
        changed = copy.deepcopy(dataset)
        changed["rows"][0]["season_name"] = "2026/2027"
        with self.assertRaisesRegex(ValueError, "approved three"):
            train_and_validate(changed)


if __name__ == "__main__":
    unittest.main()
