from __future__ import annotations

import unittest
from unittest.mock import Mock, patch

from one_touch_loader.api.repos import standings_repo
from one_touch_loader.loaders.standings_loader import (
    _previous_positions,
    _standing_rows,
)


def _details() -> list[dict]:
    values = {
        "overall-won": 3,
        "overall-draw": 2,
        "overall-lost": 1,
        "overall-goals-for": 10,
        "overall-goals-against": 4,
    }
    return [
        {"type": {"code": code}, "value": value}
        for code, value in values.items()
    ]


class StandingsLoaderTests(unittest.TestCase):
    def test_builds_only_stored_columns_from_observed_fields(self) -> None:
        client = Mock()
        client.get_rounds_for_season.return_value = [
            {"id": 101, "name": "1", "finished": True},
            {"id": 102, "name": "2", "finished": True},
        ]
        client.get_standings_for_round.return_value = [
            {"participant_id": 10, "position": 4}
        ]
        client.get_standings_for_season.return_value = [
            {
                "participant_id": 10,
                "position": 2,
                "points": 11,
                "details": _details(),
            }
        ]

        self.assertEqual(
            _standing_rows(client, 28083),
            [(28083, 10, 2, 4, 3, 2, 1, 10, 4, 11)],
        )
        client.get_standings_for_round.assert_called_once_with(101)

    def test_one_finished_round_has_no_previous_position(self) -> None:
        client = Mock()
        client.get_rounds_for_season.return_value = [
            {"id": 101, "name": "1", "finished": True}
        ]

        self.assertEqual(_previous_positions(client, 28321), {})
        client.get_standings_for_round.assert_not_called()


class StandingsRepositoryTests(unittest.TestCase):
    @patch("one_touch_loader.api.repos.standings_repo.fetch_all_dict")
    def test_derives_display_values_from_stored_rows_and_fixtures(
        self,
        fetch_all_dict: Mock,
    ) -> None:
        fetch_all_dict.side_effect = [
            [
                {
                    "position": 2,
                    "previous_position": 4,
                    "team_id": 10,
                    "team_name": "Home",
                    "team_logo": None,
                    "won": 3,
                    "draw": 2,
                    "lost": 1,
                    "goals_for": 10,
                    "goals_against": 4,
                    "points": 11,
                },
                {
                    "position": 3,
                    "previous_position": None,
                    "team_id": 20,
                    "team_name": "Away",
                    "team_logo": None,
                    "won": 2,
                    "draw": 2,
                    "lost": 2,
                    "goals_for": 8,
                    "goals_against": 7,
                    "points": 8,
                },
                {
                    "position": 4,
                    "previous_position": 4,
                    "team_id": 30,
                    "team_name": "No completed fixtures",
                    "team_logo": None,
                    "won": 0,
                    "draw": 0,
                    "lost": 0,
                    "goals_for": 0,
                    "goals_against": 0,
                    "points": 0,
                },
            ],
            [
                {
                    "home_team_id": 10,
                    "away_team_id": 20,
                    "home_score": 2,
                    "away_score": 1,
                },
                {
                    "home_team_id": 20,
                    "away_team_id": 10,
                    "home_score": 0,
                    "away_score": 0,
                },
            ],
        ]

        rows = standings_repo.list_standings(8, 28083)

        self.assertEqual(rows[0]["matches_played"], 6)
        self.assertEqual(rows[0]["goal_diff"], 6)
        self.assertEqual(rows[0]["rank_delta"], 2)
        self.assertEqual(rows[0]["last5_form"], ["D", "W"])
        self.assertNotIn("previous_position", rows[0])
        self.assertIsNone(rows[1]["rank_delta"])
        self.assertEqual(rows[1]["last5_form"], ["D", "L"])
        self.assertEqual(rows[2]["last5_form"], [])
        fixture_query = fetch_all_dict.call_args_list[1].args[0]
        self.assertIn("r.name REGEXP '^[0-9]+$'", fixture_query)


if __name__ == "__main__":
    unittest.main()
