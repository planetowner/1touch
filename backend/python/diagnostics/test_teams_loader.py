from __future__ import annotations

import unittest
import sys
from pathlib import Path
from unittest.mock import patch


BACKEND_ROOT = Path(__file__).resolve().parents[2]
PYTHON_ROOT = BACKEND_ROOT / "python"
sys.path.insert(0, str(PYTHON_ROOT))

from one_touch_loader.loaders import teams_loader


def _team(team_id: int, name: str, placeholder: bool = False) -> dict:
    return {
        "id": team_id,
        "name": name,
        "short_code": name[:3].upper(),
        "image_path": f"https://example.test/{team_id}.png",
        "placeholder": placeholder,
    }


class FakeSportmonksClient:
    def __init__(self, seasons_by_competition, teams_by_season, fixtures_by_season):
        self.seasons_by_competition = seasons_by_competition
        self.teams_by_season = teams_by_season
        self.fixtures_by_season = fixtures_by_season

    def get_league_with_seasons(self, competition_id: int) -> dict:
        return {
            "id": competition_id,
            "seasons": self.seasons_by_competition[competition_id],
        }

    def iter_teams_by_season(self, season_id: int):
        yield from self.teams_by_season[season_id]

    def iter_fixtures_by_season(self, season_id: int, include: str):
        if include != "participants":
            raise AssertionError(f"Unexpected include: {include!r}")
        yield from self.fixtures_by_season[season_id]


class TeamsLoaderTests(unittest.TestCase):
    def test_general_competition_upserts_all_actual_season_participants(self):
        client = FakeSportmonksClient(
            seasons_by_competition={
                8: [{"id": 100, "name": "2025/2026"}],
            },
            teams_by_season={
                100: [
                    _team(1, "Actual"),
                    _team(999, "TBD", placeholder=True),
                ]
            },
            fixtures_by_season={},
        )

        with patch.object(teams_loader, "upsert_many") as upsert_many:
            result = teams_loader._collect_and_upsert(
                sm=client,
                cache={},
                season_name="2025/2026",
                competition_id=8,
            )

        self.assertEqual(result["collection_strategy"], "season_participants")
        self.assertEqual(result["upserted_team_count"], 1)
        self.assertEqual(result["skipped_placeholders"], 1)
        upsert_many.assert_called_once_with(
            teams_loader.SQL_UPSERT_TEAM,
            [(1, "Actual", "ACT", "https://example.test/1.png")],
        )

    def test_domestic_cup_only_upserts_base_league_teams_and_their_opponents(self):
        client = FakeSportmonksClient(
            seasons_by_competition={
                564: [{"id": 100, "name": "2024/2025"}],
                570: [{"id": 200, "name": "2024/2025"}],
            },
            teams_by_season={
                100: [_team(10, "League A"), _team(20, "League B")],
            },
            fixtures_by_season={
                200: [
                    {
                        "id": 1,
                        "participants": [_team(10, "League A"), _team(30, "Cup A")],
                    },
                    {
                        "id": 2,
                        "participants": [_team(40, "Cup B"), _team(50, "Cup C")],
                    },
                    {
                        "id": 3,
                        "participants": [
                            _team(20, "League B"),
                            _team(999, "TBD", placeholder=True),
                        ],
                    },
                    {
                        "id": 4,
                        "participants": [_team(10, "League A"), _team(20, "League B")],
                    },
                ]
            },
        )

        with patch.object(teams_loader, "upsert_many") as upsert_many:
            result = teams_loader._collect_and_upsert(
                sm=client,
                cache={},
                season_name="2024/2025",
                competition_id=570,
            )

        self.assertEqual(
            result["collection_strategy"],
            "domestic_cup_fixtures_related_to_base_league",
        )
        self.assertEqual(result["provider_fixture_rows"], 4)
        self.assertEqual(result["matched_fixture_rows"], 3)
        self.assertEqual(result["selected_base_league_team_count"], 2)
        self.assertEqual(result["opponent_team_count"], 1)
        self.assertEqual(result["skipped_placeholder_participant_rows"], 1)
        self.assertEqual(result["upserted_team_count"], 3)
        upsert_many.assert_called_once_with(
            teams_loader.SQL_UPSERT_TEAM,
            [
                (10, "League A", "LEA", "https://example.test/10.png"),
                (20, "League B", "LEA", "https://example.test/20.png"),
                (30, "Cup A", "CUP", "https://example.test/30.png"),
            ],
        )

    def test_selected_season_name_must_exist_for_the_competition(self):
        client = FakeSportmonksClient(
            seasons_by_competition={
                8: [{"id": 100, "name": "2025/2026"}],
            },
            teams_by_season={},
            fixtures_by_season={},
        )

        with self.assertRaisesRegex(ValueError, "was not found"):
            teams_loader._collect_and_upsert(
                sm=client,
                cache={},
                season_name="2024/2025",
                competition_id=8,
            )

    def test_selected_season_before_supported_minimum_is_rejected(self):
        client = FakeSportmonksClient(
            seasons_by_competition={},
            teams_by_season={},
            fixtures_by_season={},
        )

        with self.assertRaisesRegex(ValueError, "supported minimum 2017/2018"):
            teams_loader._collect_and_upsert(
                sm=client,
                cache={},
                season_name="2016/2017",
                competition_id=8,
            )

    def test_all_mode_season_names_require_consecutive_years(self):
        self.assertEqual(teams_loader._season_start_year("2017/2018"), 2017)

        with self.assertRaisesRegex(ValueError, "Unsupported season name"):
            teams_loader._season_start_year("2024/2026")


if __name__ == "__main__":
    unittest.main()
