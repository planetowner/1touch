from __future__ import annotations

import copy
from collections import Counter
from datetime import date, datetime, timezone
from itertools import permutations
import unittest

from one_touch_loader.core.probability_forecast import forecast_day, select_cards, league_events, resolve_league_events
from one_touch_loader.core.probability import position_bounds
from one_touch_loader.loaders.probability_training import build_dataset, train_and_validate, BIG5_IDS
from one_touch_loader.loaders.probability_loader import reconstruct_betting_runs


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

    def test_european_title_is_not_mandatory_and_top_six_is_not_a_card_candidate(self):
        events = [{"event": name, "competition_id": competition, "category": category, "probability": p}
                  for name, competition, category, p in [("ucl_winner", 2, "TITLE", 0),
                     ("league_winner", 8, "TITLE", .2), ("top_4", 8, "LEAGUE_FINISH", .9),
                     ("top_6", 8, "LEAGUE_FINISH", .5),
                     ("direct_relegation", 8, "RELEGATION", .01)]]
        for probability in (0, .01):
            with self.subTest(european_probability=probability):
                events[0]["probability"] = probability
                self.assertEqual([e["event"] for e in select_cards(events)],
                                 ["top_4", "league_winner"])

    def test_non_european_team_gets_top_four_and_relegation(self):
        events = [{"event": name, "competition_id": 8, "category": category, "probability": p}
                  for name, category, p in [("league_winner", "TITLE", .01),
                     ("top_4", "LEAGUE_FINISH", .4),
                     ("direct_relegation", "RELEGATION", .3)]]
        self.assertEqual([e["event"] for e in select_cards(events)],
                         ["top_4", "direct_relegation"])

    def test_domestic_cards_are_displayed_by_probability_after_entropy_selection(self):
        events = [{"event": name, "competition_id": 8, "category": category, "probability": p}
                  for name, category, p in [("league_winner", "TITLE", .35),
                     ("top_4", "LEAGUE_FINISH", .75),
                     ("direct_relegation", "RELEGATION", .01)]]
        self.assertEqual([e["event"] for e in select_cards(events)],
                         ["top_4", "league_winner"])

    def test_card_selection_matches_spreadsheet_examples(self):
        # 엑셀의 실제 확률에 새 0% 보완·표시 순서 규칙을 적용해요.
        cases = [
            ("Aston Villa", 8, {"league_winner": .00036, "top_4": .15165,
                               "direct_relegation": .00101, "ucl_winner": .01639},
             ["top_4", "ucl_winner"]),
            ("Elversberg", 82, {"league_winner": .00001, "top_4": .0065,
                               "direct_relegation": .07451, "relegation_playoff": .06184},
             ["direct_relegation", "relegation_playoff"]),
            ("Frankfurt", 82, {"league_winner": .00002, "top_4": .03514,
                              "direct_relegation": .01695, "relegation_playoff": .01958},
             ["top_4", "relegation_playoff"]),
            ("Coventry", 8, {"league_winner": 0, "top_4": 0, "direct_relegation": .79937},
             ["direct_relegation", "top_4"]),
        ]
        for team, competition, probabilities, expected in cases:
            with self.subTest(team=team):
                events = [{"event": name, "competition_id": 2 if name == "ucl_winner" else competition,
                           "probability": probability} for name, probability in probabilities.items()]
                self.assertEqual([e["event"] for e in select_cards(events)], expected)

    def test_sample_endpoints_remain_candidates_and_event_metadata_is_preserved(self):
        events = [{"event": "league_winner", "competition_id": 8, "probability": 0},
                  {"event": "top_4", "competition_id": 8, "probability": 1},
                  {"event": "direct_relegation", "competition_id": 8, "probability": .000001,
                   "category": "RELEGATION", "change_pp": -.01}]
        original = copy.deepcopy(events)
        cards = select_cards(events)
        self.assertEqual([e['event'] for e in cards], ['top_4', 'direct_relegation'])
        self.assertGreater(cards[1]["entropy"], 0)
        self.assertEqual({k: v for k, v in cards[1].items() if k != "entropy"}, events[2])
        self.assertEqual(events, original)
        self.assertEqual([e['event'] for e in select_cards(events[:2])], ['top_4', 'league_winner'])
        self.assertEqual(select_cards([]), [])

    def test_equal_entropy_keeps_deterministic_order_and_respects_limit(self):
        events = [{"event": "top_4", "competition_id": 8, "probability": .5},
                  {"event": "league_winner", "competition_id": 8, "probability": .5},
                  {"event": "ucl_winner", "competition_id": 2, "probability": .5}]
        for ordered in permutations(events):
            self.assertEqual([e["event"] for e in select_cards(list(ordered))],
                             ["league_winner", "ucl_winner"])
        self.assertEqual(select_cards(events, limit=1), [{**events[2], "entropy": 1}])
        self.assertEqual(select_cards(events, limit=0), [])

    def test_zero_probability_companion_uses_nearest_domestic_rank_only_after_entropy(self):
        for competition, expected in ((8, 'top_4'), (82, 'relegation_playoff'), (301, 'relegation_playoff')):
            events = league_events(competition, [])
            next(e for e in events if e['event'] == 'direct_relegation')['probability'] = .61424
            self.assertEqual([e['event'] for e in select_cards(events)], ['direct_relegation', expected])
            next(e for e in events if e['event'] == 'league_winner')['probability'] = .000001
            self.assertEqual([e['event'] for e in select_cards(events)], ['direct_relegation', 'league_winner'])

    def test_european_card_stays_right_even_with_higher_probability(self):
        for event, competition in (('ucl_winner', 2), ('uel_winner', 5), ('uecl_winner', 2286)):
            events = [{'event': 'top_4', 'competition_id': 8, 'probability': .1},
                      {'event': event, 'competition_id': competition, 'probability': .4}]
            self.assertEqual([e['event'] for e in select_cards(events)], ['top_4', event])

    def test_mathematical_resolution_does_not_use_simulation_frequency(self):
        points = {t: 100 - 4 * t for t in range(1, 19)}
        bounds = position_bounds(points, {t: p + 3 for t, p in points.items()})
        for team, expected in ((1, 'league_winner'), (4, 'top_4'), (16, 'relegation_playoff'),
                               (17, 'direct_relegation')):
            with self.subTest(team=team):
                events = resolve_league_events(league_events(82, []), 82, bounds[team])
                event = next(e for e in events if e['event'] == expected)
                self.assertEqual((event['resolution'], event['probability']), ('certain', 1))
        top_four = next(e for e in resolve_league_events(league_events(82, []), 82, bounds[5])
                        if e['event'] == 'top_4')
        self.assertEqual(top_four['resolution'], 'impossible')
        ties = position_bounds(dict.fromkeys(range(18), 50), dict.fromkeys(range(18), 50))
        self.assertEqual(ties[0], (1, 18))
        unresolved = resolve_league_events(league_events(82, [{'position': 1, 'probability': 1}]), 82, ties[0])
        self.assertTrue(all(e['resolution'] == 'unresolved' for e in unresolved))

    def test_point_bounds_contain_every_actual_result_of_remaining_fixtures(self):
        # 같은 경기가 양 팀 승점에 영향을 줘도, 증명한 범위 밖의 결과가 나오면 안 돼요.
        from itertools import product
        points = {1: 8, 2: 6, 3: 3, 4: 0}
        fixtures = [(1, 2), (2, 3), (3, 4)]
        remaining = Counter(t for pair in fixtures for t in pair)
        bounds = position_bounds(points, {t: p + 3 * remaining[t] for t, p in points.items()})
        for outcomes in product(((3, 0), (1, 1), (0, 3)), repeat=len(fixtures)):
            final = points.copy()
            for (home, away), (h, a) in zip(fixtures, outcomes):
                final[home] += h
                final[away] += a
            for order in permutations(final):
                if [final[t] for t in order] != sorted(final.values(), reverse=True):
                    continue
                for rank, team in enumerate(order, 1):
                    self.assertLessEqual(bounds[team][0], rank)
                    self.assertGreaterEqual(bounds[team][1], rank)


class TrainingPipelineTests(unittest.TestCase):
    def test_previous_season_uses_only_its_three_prior_seasons(self):
        fixtures = []
        for year in (2022, 2023, 2024, 2025):
            for league in BIG5_IDS:
                for home, away in ((2, 0), (1, 1), (0, 2)):
                    fixtures.append({"fixture_id": len(fixtures) + 1, "season_name": f"{year}/{year+1}",
                                     "competition_id": league, "starting_at": f"{year}-09-20 15:00:00",
                                     "state_id": 5, "home_team_id": 1, "away_team_id": 2,
                                     "home_score": home, "away_score": away})
        histories = {team: [{"date": "2022-09-17", "elo": 1500}] for team in (1, 2)}
        dataset = build_dataset(fixtures, histories, predict_from_season="2025/2026")
        report = train_and_validate(dataset, predict_from_season="2025/2026")
        self.assertEqual(report["validation"]["training_seasons"], ["2022/2023", "2023/2024"])
        self.assertEqual(report["validation"]["season"], "2024/2025")
        self.assertEqual(report["forecast_model"]["training_seasons"], ["2022/2023", "2023/2024", "2024/2025"])
        self.assertEqual(report["forecast_model"]["training_fixtures"], 45)
        self.assertEqual(report["forecast_model"]["predict_from_season"], "2025/2026")
        self.assertEqual({row["starting_at"][:4] for row in report["training_rows"]}, {"2022", "2023", "2024"})
        with self.assertRaisesRegex(ValueError, "Unsupported"):
            build_dataset(fixtures, histories, predict_from_season="2024/2025")

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


class ReconstructedBettingTests(unittest.TestCase):
    def setUp(self):
        self.model = {"model_id": "historical", "forecast_model": {
            "predict_from_season": "2025/2026", "last_training_fixture_at": "2025-05-25 19:00:00"}}
        base = {"fixture_id": 1, "competition_id": 384, "season_id": 12, "season_name": "2025/2026",
                "starting_at": "2025-08-15 17:00:00", "state_id": 5,
                "home_team_id": 1, "away_team_id": 2, "home_score": 2, "away_score": 0}
        self.fixtures = [base, dict(base, fixture_id=2, away_team_id=3),
                         dict(base, fixture_id=3, starting_at="2025-08-16 00:00:00")]
        self.histories = {team: [{"date": "2025-08-14", "elo": 1500 + team * 100},
                                {"date": "2025-08-15", "elo": 2000 + team * 100}]
                          for team in (1, 2)}

    def test_uses_pre_day_elo_and_missing_team_does_not_block_league(self):
        runs, coverage = reconstruct_betting_runs(self.fixtures, self.histories, self.model)
        self.assertEqual(len(runs), 2)
        self.assertEqual(runs[0]["teams"], {"1": {"elo": 1600}, "2": {"elo": 1700}})
        self.assertEqual(runs[1]["teams"]["1"]["elo"], 2100)
        self.assertEqual(runs[0]["as_of"], "2025-08-15T00:00:00Z")
        self.assertEqual(runs[0]["history_kind"], "reconstructed")
        self.assertEqual(runs[0]["market_kind"], "single_match_final_v1")
        self.assertEqual(coverage["available"], 2)
        self.assertEqual(coverage["excluded"][0]["missing_team_ids"], [3])
        changed = [dict(f, home_score=0, away_score=9) for f in self.fixtures]
        self.assertEqual(reconstruct_betting_runs(changed, self.histories, self.model), (runs, coverage))

    def test_ignores_other_seasons_and_unfinished_matches(self):
        fixtures = [dict(self.fixtures[0], season_name="2024/2025"),
                    dict(self.fixtures[0], state_id=1), dict(self.fixtures[0], competition_id=2)]
        runs, coverage = reconstruct_betting_runs(fixtures, self.histories, self.model)
        self.assertEqual(runs, [])
        self.assertEqual(coverage, {"available": 0, "excluded": []})

    def test_rejects_training_that_reaches_target_day(self):
        self.model["forecast_model"]["last_training_fixture_at"] = "2025-08-15 12:00:00"
        with self.assertRaisesRegex(ValueError, "model contains"):
            reconstruct_betting_runs(self.fixtures, self.histories, self.model)


if __name__ == "__main__":
    unittest.main()
