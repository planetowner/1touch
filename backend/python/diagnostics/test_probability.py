from __future__ import annotations

import json
import unittest
from datetime import date
from pathlib import Path
from unittest.mock import Mock, patch

import numpy as np

from one_touch_loader.core.clubelo import ClubEloClient, parse_directory, parse_history, parse_calculation_results, rating_before
from one_touch_loader.core.probability import WDLModel, fit_wdl, evaluate_wdl, simulate_league, summarize_points


SAMPLE = json.loads((Path(__file__).parent / "fixtures/clubelo-history-sample.json").read_text(encoding="utf-8"))


class ClubEloHistoryTests(unittest.TestCase):
    def test_directory_does_not_duplicate_clubs_under_unclosed_level_row(self):
        html = '<div class="accordion-header"><a href="ENG">England</a></div><table>'
        html += '<tr><td>Level 1<td>Average<tr><td><a href="/Arsenal"><span class="NonAst">ARS</span>'
        html += '<span class="Ast">Arsenal</span></a></td><td>2045</td></tr></table>'
        club, = parse_directory(html, ("ENG",))
        self.assertEqual((club["external_team_id"], club["country"], club["elo"]), ("Arsenal", "ENG", 2045))

    @patch("one_touch_loader.core.clubelo.requests.Session")
    def test_homepage_redirect_is_not_mistaken_for_a_team_history(self, session):
        session.return_value.get.return_value = Mock(url="https://clubelo.com/", text="Homepage")
        client = ClubEloClient()
        with self.assertRaisesRegex(ValueError, "redirected"):
            client.get_html("Barcelona")
        client.close()

    def test_actual_prior_difference_excludes_same_day_post_match_rating(self):
        day = date(2026, 9, 6)
        barca = rating_before(SAMPLE["Barcelona"]["history"], day)
        valencia = rating_before(SAMPLE["Valencia"]["history"], day)
        self.assertAlmostEqual(barca - valencia, 259.4366268736398)
        self.assertNotEqual(barca, SAMPLE["Barcelona"]["history"][-1]["elo"])
        self.assertIsNone(rating_before(SAMPLE["Barcelona"]["history"], date(2018, 7, 1)))

    def test_actual_away_result_is_from_profile_team_perspective(self):
        barca = parse_calculation_results(SAMPLE["Barcelona"]["calculation_html"])[0]
        self.assertEqual((barca["side"], barca["opponent"], barca["goals_for"], barca["goals_against"]),
                         ("A", "Valencia", 5, 0))

    def test_opponent_without_link_remains_unmapped(self):
        row, = parse_calculation_results(SAMPLE["Sunderland"]["calculation_html"])
        self.assertIsNone(row["opponent"])
        self.assertEqual((row["goals_for"], row["goals_against"]), (0, 1))

    def test_calculation_row_without_ft_is_not_used_as_a_result(self):
        html = '<table><tr><th>Prior Δ</th><th>New Elo</th></tr><tr>'
        html += '<td><a href="/2026-05-15">15/5</a></td><td>H</td><td>Rodez</td>'
        html += '<td>8</td><td>33</td><td>55.9%</td></tr></table>'
        self.assertEqual(parse_calculation_results(html), [])

    def test_history_reads_json_without_executing_trailing_javascript(self):
        history = SAMPLE["Barcelona"]["history"]
        data = [{"Date": row["date"] + "T00:00:00", "Elo": row["elo"], "segment_id": 0} for row in history]
        spec = json.dumps({"datasets": {"sample": data}})
        parsed = parse_history('<script>var vegaJson = ' + spec + '; throw new Error("do not execute");</script>')
        self.assertEqual(parsed, history)
        with self.assertRaisesRegex(ValueError, "Expected one"):
            parse_history("<html>Homepage without a history</html>")

    def test_conflicting_same_day_history_is_rejected(self):
        rows = [{"Date": "2026-09-01", "Elo": elo, "segment_id": 0} for elo in (1500, 1600)]
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            parse_history('<script>var vegaJson = ' + json.dumps({"datasets": {"d": rows}}) + ';</script>')


class ProbabilityTests(unittest.TestCase):
    def test_fits_home_and_draw_effects_instead_of_fixed_percentages(self):
        # 같은 Elo인 경기를 정확한 빈도로 만들어 절편이 그 빈도를 되찾는지 확인해요.
        outcomes = np.repeat([0, 1, 2], [450, 300, 250])
        trained = fit_wdl(np.zeros(1000), outcomes)
        np.testing.assert_allclose(trained.predict([0])[0], [0.45, 0.30, 0.25], atol=0.0001)
        self.assertLess(evaluate_wdl(trained, np.zeros(1000), outcomes)["log_loss"], np.log(3))

    def test_learns_elo_effect_and_returns_normalized_probabilities(self):
        rng = np.random.default_rng(20260917)
        differences = rng.uniform(-350, 350, 30000)
        truth = WDLModel((0.45, 1.8, -0.15, -1.6))
        probs = truth.predict(differences)
        y = (rng.random(len(differences))[:, None] > np.cumsum(probs, axis=1)).sum(axis=1)
        trained = fit_wdl(differences, y)
        np.testing.assert_allclose(trained.predict([-200, 0, 200]), truth.predict([-200, 0, 200]), atol=0.02)
        np.testing.assert_allclose(trained.predict([-2000, 0, 2000]).sum(axis=1), 1)

    def test_points_interval_reports_discrete_actual_coverage(self):
        result = summarize_points(np.repeat([0, 1, 3], [20, 50, 30]))
        self.assertEqual(result["mean"], 1.4)
        self.assertEqual(result["likely_range"], {
            "lower": 0, "upper": 3, "target_coverage": 0.8,
            "included_probability": 1.0, "method": "equal_tail", "unit": "points",
        })

    def test_all_remaining_fixtures_contribute_points_and_rank(self):
        fixtures = [
            {"fixture_id": 10, "home_team_id": 1, "away_team_id": 2, "probabilities": [1, 0, 0]},
            {"fixture_id": 11, "home_team_id": 2, "away_team_id": 3, "probabilities": [0, 0, 1]},
        ]
        result = simulate_league([1, 2, 3], {1: 0, 2: 1, 3: 2}, fixtures, simulations=10, seed=1)
        self.assertEqual([result[t]["projected_points"]["mean"] for t in (1, 2, 3)], [3, 1, 5])
        self.assertEqual(result[3]["positions"][0]["probability"], 1)
        self.assertEqual(result[1]["positions"][1]["probability"], 1)
        self.assertEqual(result[2]["positions"][2]["probability"], 1)

    def test_point_ties_are_uniform_not_broken_by_team_id(self):
        result = simulate_league([1, 2, 3], {1: 30, 2: 30, 3: 30}, [], simulations=30000, seed=10)
        for team in result.values():
            np.testing.assert_allclose([row["probability"] for row in team["positions"]], [1 / 3] * 3, atol=0.015)
        np.testing.assert_allclose([sum(result[t]["positions"][rank]["probability"] for t in result) for rank in range(3)], 1)

    def test_away_what_if_changes_only_selected_fixture(self):
        fixtures = [
            {"fixture_id": 10, "home_team_id": 1, "away_team_id": 2, "probabilities": [0.4, 0.3, 0.3]},
            {"fixture_id": 11, "home_team_id": 1, "away_team_id": 3, "probabilities": [0.5, 0.25, 0.25]},
        ]
        arguments = dict(team_ids=[1, 2, 3], current_points={1: 0, 2: 0, 3: 0}, remaining_fixtures=fixtures,
                         simulations=1000, seed=10)
        win = simulate_league(**arguments, forced_outcome=(10, 2))
        lose = simulate_league(**arguments, forced_outcome=(10, 0))
        self.assertEqual(win[2]["projected_points"]["mean"], 3)
        self.assertEqual(lose[2]["projected_points"]["mean"], 0)
        self.assertEqual(win[3]["projected_points"], lose[3]["projected_points"])
        self.assertEqual(win, simulate_league(**arguments, forced_outcome=(10, 2)))

    def test_missing_team_or_invalid_probability_is_not_filled(self):
        with self.assertRaisesRegex(ValueError, "every league team"):
            simulate_league([1, 2], {1: 0}, [], simulations=1, seed=1)
        with self.assertRaisesRegex(ValueError, "Invalid remaining"):
            simulate_league([1, 2], {1: 0, 2: 0}, [{"fixture_id": 1, "home_team_id": 1, "away_team_id": 2,
                             "probabilities": [0.4, 0.4, 0.4]}], simulations=1, seed=1)


if __name__ == "__main__":
    unittest.main()
