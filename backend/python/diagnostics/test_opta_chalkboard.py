import copy
import json
import unittest
from pathlib import Path

from one_touch_loader.core.opta_chalkboard import match_page_ids, normalize_chalkboard


class OptaChalkboardTests(unittest.TestCase):
    def setUp(self):
        self.raw = json.loads((Path(__file__).parent / "fixtures" /
                               "opta-valencia-barcelona-chalkboard.json").read_text(encoding="utf-8"))

    def test_real_match_counts_and_duplicate_goals(self):
        result = normalize_chalkboard(self.raw)
        self.assertEqual(len(self.raw["events"]), 33)
        self.assertEqual(len(result["shots"]), 12)
        self.assertEqual(result["counts"], {"home": 2, "away": 10})
        self.assertEqual(sum(s["result"] == "goal" for s in result["shots"]), 5)
        excluded_ids = {e["id"] for e in self.raw["events"]
                        if e["event_type"] in {"Shots off target", "Blocks"}}
        self.assertTrue(excluded_ids.isdisjoint(s["external_event_id"] for s in result["shots"]))

    def test_actual_arrow_recovers_goal_line_and_start(self):
        goal = normalize_chalkboard(self.raw)["shots"][0]
        self.assertEqual(goal["player_name"], "Lamine Yamal")
        self.assertEqual(goal["start"], {"x": 3.9, "y": 35.0})
        self.assertEqual(goal["end"], {"x": 0.0, "y": 51.3})
        self.assertEqual(goal["result"], "goal")

    def test_stoppage_time_and_home_direction(self):
        shots = normalize_chalkboard(self.raw)["shots"]
        shot = next(s for s in shots if s["external_event_id"].endswith("-277"))
        self.assertEqual((shot["minute"], shot["extra_minute"]), (45, 4))
        self.assertEqual(shot["external_player_id"], "4rktv6j9sioe0gmu7jt77fsh5")
        self.assertGreater(shot["end"]["x"], shot["start"]["x"])

    def test_partial_player_selection_cannot_pass_as_full_match(self):
        self.raw["events"] = self.raw["events"][:2]
        with self.assertRaisesRegex(ValueError, "유효슈팅 수"):
            normalize_chalkboard(self.raw)

    def test_conflicting_duplicate_is_not_silently_discarded(self):
        self.raw["events"][1]["coords"][0] = "100"
        with self.assertRaisesRegex(ValueError, "같은 이벤트 ID"):
            normalize_chalkboard(self.raw)

    def test_wrong_fixture_period_and_filter_rejected(self):
        for field, value in [("match_id", "different"), ("full_game", False),
                             ("selected_events", ["Shots on target"]), ("orientation", "vertical")]:
            with self.subTest(field=field):
                raw = copy.deepcopy(self.raw)
                raw[field] = value
                with self.assertRaises(ValueError):
                    normalize_chalkboard(raw)

    def test_url_requires_actual_match_context(self):
        self.assertEqual(match_page_ids(self.raw["source_url"])["matchId"], self.raw["match_id"])
        with self.assertRaises(ValueError):
            match_page_ids("https://theanalyst.com/opta-football-match-centre")


if __name__ == "__main__":
    unittest.main()
