from __future__ import annotations

from datetime import datetime
import unittest
from unittest.mock import Mock, patch

from one_touch_loader.api.repos import points_pace_repo


class PointsPaceRepositoryTests(unittest.TestCase):
    @patch("one_touch_loader.api.repos.points_pace_repo.fetch_all_dict")
    @patch("one_touch_loader.api.repos.points_pace_repo.fetch_one_dict")
    def test_builds_cumulative_points_from_fixture_results(
        self,
        fetch_one_dict: Mock,
        fetch_all_dict: Mock,
    ) -> None:
        fetch_one_dict.return_value = {
            "team_id": 10,
            "team_name": "Test Team",
            "team_short_code": "TST",
            "team_logo": None,
            "competition_id": 8,
            "season_id": 100,
            "season_name": "2025/2026",
            "is_current": 1,
        }
        fetch_all_dict.return_value = [
            {
                "fixture_id": 1,
                "round_no": 1,
                "match_date": datetime(2025, 8, 1, 15, 0),
                "home_team_id": 10,
                "away_team_id": 20,
                "home_score": 2,
                "away_score": 0,
            },
            {
                "fixture_id": 2,
                "round_no": 2,
                "match_date": datetime(2025, 8, 8, 15, 0),
                "home_team_id": 20,
                "away_team_id": 10,
                "home_score": 1,
                "away_score": 1,
            },
            {
                "fixture_id": 3,
                "round_no": 3,
                "match_date": datetime(2025, 8, 15, 15, 0),
                "home_team_id": 20,
                "away_team_id": 10,
                "home_score": 3,
                "away_score": 1,
            },
        ]

        result = points_pace_repo.get_points_pace_series(10, 100)

        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(
            result["points"],
            [
                {"round_no": 0, "match_date": None, "cumulative_points": 0},
                {
                    "round_no": 1,
                    "match_date": "2025-08-01T15:00:00",
                    "cumulative_points": 3,
                },
                {
                    "round_no": 2,
                    "match_date": "2025-08-08T15:00:00",
                    "cumulative_points": 4,
                },
                {
                    "round_no": 3,
                    "match_date": "2025-08-15T15:00:00",
                    "cumulative_points": 4,
                },
            ],
        )
        fixture_query = fetch_all_dict.call_args.args[0]
        self.assertIn("FROM fixtures f", fixture_query)
        self.assertNotIn("points_pace", fixture_query)

    @patch("one_touch_loader.api.repos.points_pace_repo.fetch_all_dict")
    @patch("one_touch_loader.api.repos.points_pace_repo.fetch_one_dict")
    def test_returns_round_zero_for_team_season_without_results(
        self,
        fetch_one_dict: Mock,
        fetch_all_dict: Mock,
    ) -> None:
        fetch_one_dict.return_value = {
            "team_id": 10,
            "team_name": "Test Team",
            "team_short_code": None,
            "team_logo": None,
            "competition_id": 8,
            "season_id": 100,
            "season_name": "2025/2026",
            "is_current": 1,
        }
        fetch_all_dict.return_value = []

        result = points_pace_repo.get_points_pace_series(10, 100)

        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(
            result["points"],
            [{"round_no": 0, "match_date": None, "cumulative_points": 0}],
        )

    @patch("one_touch_loader.api.repos.points_pace_repo.fetch_all_dict")
    def test_lists_fixture_backed_options(
        self,
        fetch_all_dict: Mock,
    ) -> None:
        fetch_all_dict.return_value = [
            {
                "team_id": 10,
                "team_name": "Test Team",
                "team_short_code": "TST",
                "team_logo": None,
                "competition_id": 8,
                "season_id": 100,
                "season_name": "2025/2026",
                "rounds_available": 3,
                "latest_round": 3,
            }
        ]

        result = points_pace_repo.list_current_form_options(
            search=" Test ",
            limit=5,
        )

        self.assertEqual(result[0]["rounds_available"], 3)
        self.assertEqual(result[0]["latest_round"], 3)
        query = fetch_all_dict.call_args.args[0]
        self.assertIn("JOIN fixtures f", query)
        self.assertNotIn("points_pace", query)
        self.assertEqual(
            fetch_all_dict.call_args.args[1],
            ("Test", "Test", "Test", 5),
        )


if __name__ == "__main__":
    unittest.main()
