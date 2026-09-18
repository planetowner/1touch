from decimal import Decimal
from fractions import Fraction
import unittest

from one_touch_loader.core.player_rating_percentile import HistoricalPercentile, average_rating, display_score, rank_players


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
        self.assertEqual(display_score(before), 66.7)

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


if __name__ == "__main__":
    unittest.main()
