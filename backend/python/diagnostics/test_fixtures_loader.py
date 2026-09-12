from __future__ import annotations

import unittest
from datetime import datetime

from one_touch_loader.core.fixture_states import (
    screen_status_for_state_id,
    state_ids_for_screen_status,
)
from one_touch_loader.loaders.fixtures_loader import _normalize_fixture


def _fixture_payload() -> dict:
    return {
        "id": 1001,
        "league_id": 8,
        "season_id": 2001,
        "stage_id": 3001,
        "round_id": 4001,
        "group_id": None,
        "aggregate_id": 6001,
        "venue_id": 5001,
        "state_id": 8,
        "starting_at": "2025-05-25 15:00:00",
        "leg": "1/2",
        "placeholder": False,
        "participants": [
            {
                "id": 10,
                "placeholder": False,
                "meta": {"location": "home"},
            },
            {
                "id": 20,
                "placeholder": False,
                "meta": {"location": "away"},
            },
        ],
        "state": {"id": 8, "state": "FT_PEN", "name": "Full Time After Penalties"},
        "stage": {
            "id": 3001,
            "league_id": 8,
            "season_id": 2001,
            "type_id": 224,
            "name": "Knockout Stage",
        },
        "round": {
            "id": 4001,
            "league_id": 8,
            "season_id": 2001,
            "stage_id": 3001,
            "name": "Final",
        },
        "group": None,
        "aggregate": {
            "id": 6001,
            "league_id": 8,
            "season_id": 2001,
            "stage_id": 3001,
            "winner_participant_id": 10,
        },
        "venue": {"id": 5001, "name": "Test Stadium"},
        "scores": [
            {
                "fixture_id": 1001,
                "participant_id": 10,
                "type_id": 1525,
                "description": "CURRENT",
                "score": {"goals": 1, "participant": "home"},
            },
            {
                "fixture_id": 1001,
                "participant_id": 20,
                "type_id": 1525,
                "description": "CURRENT",
                "score": {"goals": 1, "participant": "away"},
            },
            {
                "fixture_id": 1001,
                "participant_id": 10,
                "type_id": 5,
                "description": "PENALTY_SHOOTOUT",
                "score": {"goals": 5, "participant": "home"},
            },
            {
                "fixture_id": 1001,
                "participant_id": 20,
                "type_id": 5,
                "description": "PENALTY_SHOOTOUT",
                "score": {"goals": 4, "participant": "away"},
            },
        ],
    }


class FixtureStateTests(unittest.TestCase):
    def test_screen_status_mapping(self) -> None:
        self.assertEqual(screen_status_for_state_id(1), "upcoming")
        self.assertEqual(screen_status_for_state_id(3), "live")
        self.assertEqual(screen_status_for_state_id(8), "past")
        self.assertIsNone(screen_status_for_state_id(12))
        self.assertEqual(state_ids_for_screen_status("past"), (5, 7, 8, 14, 15, 17))


class FixtureNormalizationTests(unittest.TestCase):
    def test_normalizes_requested_fixture_columns(self) -> None:
        normalized = _normalize_fixture(_fixture_payload(), 2001, 8)
        self.assertIsNotNone(normalized)
        self.assertEqual(
            normalized["fixture"],
            (
                1001,
                3001,
                4001,
                None,
                6001,
                "1/2",
                10,
                20,
                datetime(2025, 5, 25, 15, 0),
                5001,
                8,
                1,
                1,
                5,
                4,
            ),
        )
        self.assertEqual(
            normalized["stage"],
            (3001, 2001, 224, "Knockout Stage"),
        )
        self.assertEqual(normalized["aggregate"], (6001, 3001, 10))

    def test_keeps_single_fixture_without_aggregate(self) -> None:
        fixture = _fixture_payload()
        fixture["aggregate_id"] = None
        fixture["aggregate"] = None
        fixture["leg"] = "1/1"

        normalized = _normalize_fixture(fixture, 2001, 8)

        self.assertIsNotNone(normalized)
        self.assertIsNone(normalized["aggregate"])
        self.assertIsNone(normalized["fixture"][4])
        self.assertEqual(normalized["fixture"][5], "1/1")

    def test_ignores_unverified_aggregate_winner_outside_fixture(self) -> None:
        fixture = _fixture_payload()
        fixture["aggregate"]["winner_participant_id"] = 30

        normalized = _normalize_fixture(fixture, 2001, 8)

        self.assertEqual(normalized["aggregate"], (6001, 3001, None))
        self.assertEqual(normalized["ignored_aggregate_winner_id"], 30)

    def test_skips_placeholder_fixture(self) -> None:
        fixture = _fixture_payload()
        fixture["placeholder"] = True
        self.assertIsNone(_normalize_fixture(fixture, 2001, 8))

if __name__ == "__main__":
    unittest.main()
