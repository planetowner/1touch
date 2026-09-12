import unittest
from unittest.mock import patch

from one_touch_loader.loaders.capology_common import (
    _capology_league_salary_url,
)
from one_touch_loader.loaders.capology_team_slugs_loader import (
    _extract_capology_team_slugs,
    _load_target_team_seasons,
    _reciprocal_team_matches,
)


class CapologyTeamSlugsLoaderTest(unittest.TestCase):
    def test_builds_league_salary_urls(self):
        self.assertEqual(
            _capology_league_salary_url(8, "2017/2018", False),
            "https://www.capology.com/uk/premier-league/salaries/2017-2018/",
        )
        self.assertEqual(
            _capology_league_salary_url(564, "2026/2027", True),
            "https://www.capology.com/es/la-liga/salaries/",
        )

    def test_extracts_same_league_team_slugs(self):
        html = """
        <a href='/club/test-fc/salaries/'>Test FC</a>
        <a href='https://www.capology.com/club/other-fc/salaries/2024-2025/'>
          Other FC
        </a>
        """

        self.assertEqual(
            _extract_capology_team_slugs(html),
            ["other-fc", "test-fc"],
        )

    def test_reciprocal_team_overlap_requires_unique_best_match(self):
        names = ["First Player", "Second Player", "Third Player"]
        observations = [
            {
                "team_id": 10,
                "team_name": "Test FC",
                "display_name": name,
                "full_name": name,
            }
            for name in names
        ]
        source_teams = {
            "test-fc": [
                {"normalized_name": name.lower()}
                for name in names
            ]
        }

        matches, evidence = _reciprocal_team_matches(
            observations,
            source_teams,
        )

        self.assertEqual(matches, {10: "test-fc"})
        self.assertEqual(evidence[0]["exact_player_name_overlap"], 3)

    @patch(
        "one_touch_loader.loaders.capology_team_slugs_loader.fetch_all"
    )
    def test_selected_scope_uses_team_seasons(self, fetch_all):
        fetch_all.return_value = [
            (8, 100, "2024/2025", 0, 10, "English Team"),
            (82, 200, "2024/2025", 0, 20, "German Team"),
            (8, 300, "2025/2026", 1, 30, "Current English Team"),
        ]

        targets = _load_target_team_seasons("2024/2025", 8)

        self.assertEqual(
            targets,
            [
                {
                    "competition_id": 8,
                    "season_id": 100,
                    "season_name": "2024/2025",
                    "is_current": False,
                    "team_id": 10,
                    "team_name": "English Team",
                }
            ],
        )

    @patch(
        "one_touch_loader.loaders.capology_team_slugs_loader.fetch_all"
    )
    def test_all_scope_keeps_every_big_five_team_season(self, fetch_all):
        fetch_all.return_value = [
            (8, 100, "2017/2018", 0, 10, "English Team"),
            (564, 200, "2026/2027", 1, 20, "Spanish Team"),
        ]

        targets = _load_target_team_seasons()

        self.assertEqual(len(targets), 2)
        self.assertEqual(
            {(item["season_name"], item["competition_id"]) for item in targets},
            {("2017/2018", 8), ("2026/2027", 564)},
        )


if __name__ == "__main__":
    unittest.main()
