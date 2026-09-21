from decimal import Decimal
from fractions import Fraction
import unittest

from one_touch_loader.core.player_rating_percentile import HistoricalPercentile, average_rating, display_score, rank_players, score_season_records


class HistoricalPercentileTests(unittest.TestCase):
    def test_ties_use_half_of_equal_reference_samples(self):
        distribution = HistoricalPercentile(map(Fraction, [6, 7, 7, 8]))
        self.assertEqual(distribution.score(Fraction(7)), Decimal(50))
        self.assertEqual(distribution.score(Fraction(6)), Decimal("12.5"))
        self.assertEqual(distribution.score(Fraction(8)), Decimal("87.5"))

    def test_outside_reference_range_and_single_reference(self):
        distribution = HistoricalPercentile([Fraction(7)])
        self.assertEqual([distribution.score(Fraction(value)) for value in (6, 7, 8)], [0, 50, 100])
        with self.assertRaises(ValueError):
            HistoricalPercentile([])

    def test_means_compare_exactly_across_different_match_counts(self):
        first = average_rating(Decimal("71.00"), 10)
        second = average_rating(Decimal("234.30"), 33)
        self.assertEqual(first, second)
        self.assertEqual(HistoricalPercentile([first, second]).score(first), 50)

    def test_new_season_leader_does_not_change_an_existing_score(self):
        distribution = HistoricalPercentile(map(Fraction, [6, 7, 8]))
        before = distribution.score(Fraction("7.5"))
        self.assertEqual(distribution.score(Fraction(9)), 100)
        self.assertEqual(before, distribution.score(Fraction("7.5")))
        self.assertEqual(display_score(before), 58.3)

    def test_display_score_keeps_fixed_anchors_and_interpolates_between_them(self):
        examples = {
            "0": 0, "25": 25, "50": 50, "75": 62.5,
            "90": 70, "95": 81.1, "99": 90, "99.5": 95, "100": 100,
        }
        for percentile, expected in examples.items():
            with self.subTest(percentile=percentile):
                self.assertEqual(display_score(Decimal(percentile)), expected)

    def test_display_score_reproduces_approved_previews_before_rounding(self):
        # 확정한 24/25·25/26 미리보기의 1위와 20위예요. 표시 백분위를 재사용하면 달라져요.
        examples = {
            "99.9529927922": 99.5,
            "98.6743967408": 89.3,
            "99.9193772588": 99.2,
            "97.0670002780": 85.7,
        }
        for percentile, expected in examples.items():
            with self.subTest(percentile=percentile):
                self.assertEqual(display_score(Decimal(percentile)), expected)

    def test_display_rounding_preserves_order_across_anchor_boundaries(self):
        percentiles = list(map(Decimal, (
            "0", "49.99", "50", "50.01", "89.99", "90", "90.01",
            "98.99", "99", "99.01", "99.994", "99.995", "100",
        )))
        scores = [display_score(value) for value in percentiles]
        self.assertEqual(scores, sorted(scores))
        self.assertEqual(scores[-3:], [99.9, 100.0, 100.0])

    def test_original_mean_orders_identical_percentiles_and_equal_means_share_rank(self):
        rows = [
            {"player_id": 1, "rating_sum": Decimal("70.01"), "rated_matches": 10},
            {"player_id": 2, "rating_sum": Decimal("70.02"), "rated_matches": 10},
            {"player_id": 3, "rating_sum": Decimal("140.04"), "rated_matches": 20},
        ]
        distribution = HistoricalPercentile(map(Fraction, [6, 8]))
        for row in rows:
            row["percentile_score"] = distribution.score(average_rating(row["rating_sum"], row["rated_matches"]))
        self.assertEqual({row["percentile_score"] for row in rows}, {50})
        result = rank_players(rows)
        self.assertEqual([row["player_id"] for row in result], [2, 3, 1])
        self.assertEqual([row["rank"] for row in result], [1, 1, 3])
        self.assertNotIn("rank", rows[0])

    def test_cumulative_scores_include_every_league_and_self_but_not_later_seasons(self):
        rows = [
            {"player_id": 1, "competition_id": 8, "season_name": "2017/2018", "rated_matches": 10, "rating_sum": Decimal(60)},
            {"player_id": 2, "competition_id": 564, "season_name": "2017/2018", "rated_matches": 10, "rating_sum": Decimal(80)},
            {"player_id": 3, "competition_id": 82, "season_name": "2025/2026", "rated_matches": 10, "rating_sum": Decimal(70)},
            {"player_id": 4, "competition_id": 301, "season_name": "2025/2026", "rated_matches": 10, "rating_sum": Decimal(70)},
            {"player_id": 5, "competition_id": 384, "season_name": "2026/2027", "rated_matches": 1, "rating_sum": Decimal(9)},
        ]
        scores = {row["player_id"]: row["percentile_score"] for row in score_season_records(list(reversed(rows)))}
        self.assertEqual(scores, {1: 25, 2: 75, 3: 50, 4: 50, 5: 90})
        self.assertEqual(score_season_records([]), [])


if __name__ == "__main__":
    unittest.main()
