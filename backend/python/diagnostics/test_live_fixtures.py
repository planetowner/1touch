from __future__ import annotations

from datetime import datetime
import sqlite3
import unittest
from unittest.mock import Mock, patch

from diagnostics import test_fixture_details as detail_tests
from one_touch_loader.api.repos import fixture_clock_repo as clock_repo
from one_touch_loader.core.sportmonks import LIVE_FIXTURE_INCLUDE, SportmonksClient
from one_touch_loader.loaders import live_fixtures_loader as live


OBSERVED_AT = datetime(2026, 9, 13, 12, 0, 0)


def live_payload():
    fixture = detail_tests._payload()
    fixture.update({
        "state_id": 2, "state": {"id": 2, "state": "INPLAY_1ST_HALF", "name": "1st Half"},
        "participants": [{"id": 10, "meta": {"location": "home"}},
                         {"id": 20, "meta": {"location": "away"}}],
        "scores": [{"participant_id": 10, "type_id": 1525, "score": {"goals": 1}},
                   {"participant_id": 20, "type_id": 1525, "score": {"goals": 0}}],
        "periods": [{"type_id": 1, "counts_from": 0, "period_length": 45,
                     "minutes": 28, "seconds": 50, "ticking": True,
                     "sort_order": 1, "time_added": None}],
    })
    return fixture


class LiveStorageTests(unittest.TestCase):
    # 기존 상세 저장 테스트의 실제 FK·트랜잭션 환경을 함께 사용해요.
    setUp_details = detail_tests.FixtureDetailsStorageTests.setUp
    tearDown = detail_tests.FixtureDetailsStorageTests.tearDown

    def setUp(self):
        self.setUp_details()
        for name in ("state_id", "home_score", "away_score", "home_penalty_score", "away_penalty_score"):
            self.connection.execute(f"ALTER TABLE fixtures ADD COLUMN {name} INTEGER")
        self.connection.executescript("""
            CREATE TABLE fixture_states (state_id INTEGER PRIMARY KEY, state_code TEXT, name TEXT);
            CREATE TABLE fixture_clock (
                fixture_id INTEGER PRIMARY KEY REFERENCES fixtures(fixture_id),
                period_type_id INTEGER, counts_from INTEGER, period_length INTEGER,
                minutes INTEGER, seconds INTEGER CHECK(seconds < 60), ticking INTEGER,
                time_added INTEGER, sampled_at TEXT
            );
        """)
        self.connection.commit()

    def snapshot(self):
        return {table: self.connection.execute(f"SELECT * FROM {table}").fetchall()
                for table in ("fixtures", "fixture_events", "fixture_team_stats", "fixture_lineups",
                              "fixture_player_stats", "fixture_pressures", "fixture_clock", "fixture_states")}

    def test_var_correction_replaces_score_event_stats_and_clock_together(self):
        fixture = live_payload()
        live.store_live_fixture(fixture, 10, 20, OBSERVED_AT)
        fixture["scores"][0]["score"]["goals"] = 0
        fixture["events"] = []
        fixture["statistics"][0]["data"]["value"] = 60
        fixture["periods"][0].update(minutes=30, seconds=5)
        live.store_live_fixture(fixture, 10, 20, OBSERVED_AT)
        self.assertEqual(self.connection.execute("SELECT home_score,away_score FROM fixtures").fetchone(), (0, 0))
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_events").fetchone(), (0,))
        self.assertEqual(self.connection.execute("SELECT stat_value FROM fixture_team_stats").fetchone(), (60,))
        self.assertEqual(self.connection.execute("SELECT minutes,seconds FROM fixture_clock").fetchone(), (30, 5))

    def test_clock_constraint_failure_rolls_back_entire_live_update(self):
        fixture = live_payload()
        fixture["lineups"][0]["details"].append({"type_id": 120, "data": {"value": 12}})
        live.store_live_fixture(fixture, 10, 20, OBSERVED_AT)
        before = self.snapshot()
        fixture["events"] = []
        fixture["scores"][0]["score"]["goals"] = 0
        fixture["lineups"][0]["details"][-1]["data"]["value"] = 15
        fixture["periods"][0]["seconds"] = 60
        with self.assertRaises(sqlite3.IntegrityError):
            live.store_live_fixture(fixture, 10, 20, OBSERVED_AT)
        self.assertEqual(self.snapshot(), before)

    def test_live_refresh_uses_the_same_player_stat_storage(self):
        fixture = live_payload()
        fixture["lineups"][0]["details"].append({"type_id": 120, "data": {"value": 12}})
        live.store_live_fixture(fixture, 10, 20, OBSERVED_AT)
        fixture["lineups"][0]["details"][-1]["data"]["value"] = 15
        live.store_live_fixture(fixture, 10, 20, OBSERVED_AT)
        self.assertEqual(self.connection.execute("SELECT stat_value FROM fixture_player_stats WHERE stat_type_id=120").fetchone(), (15,))
        fixture["lineups"] = []
        live.store_live_fixture(fixture, 10, 20, OBSERVED_AT)
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_player_stats").fetchone(), (0,))

    def test_different_participants_do_not_modify_existing_match(self):
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "participants differ"):
            live.store_live_fixture(live_payload(), 20, 10, OBSERVED_AT)
        self.assertEqual(self.snapshot(), before)

    def test_half_time_and_final_scores_pause_the_clock(self):
        fixture = live_payload()
        fixture["state_id"] = 3
        fixture["state"] = {"id": 3, "state": "HT", "name": "Half Time"}
        fixture["periods"][0].update(minutes=47, seconds=12, ticking=False, time_added=2)
        live.store_live_fixture(fixture, 10, 20, OBSERVED_AT)
        self.assertEqual(self.connection.execute("SELECT ticking,minutes FROM fixture_clock").fetchone(), (0, 47))
        fixture["state_id"] = 5
        fixture["state"] = {"id": 5, "state": "FT", "name": "Full Time"}
        fixture["periods"].append({**fixture["periods"][0], "sort_order": 2,
                                   "type_id": 2, "counts_from": 45, "minutes": 95})
        live.store_live_fixture(fixture, 10, 20, OBSERVED_AT)
        self.assertEqual(self.connection.execute("SELECT ticking,minutes,counts_from FROM fixture_clock").fetchone(), (0, 95, 45))
        self.assertEqual(self.connection.execute("SELECT state_id FROM fixtures").fetchone(), (5,))


class LiveRefreshTests(unittest.TestCase):
    @patch.object(live, "store_live_fixture")
    @patch.object(live, "fetch_all", side_effect=[[], [(500, 10, 20)]])
    @patch.object(live, "SportmonksClient")
    def test_preview_transforms_actual_shape_but_does_not_write(self, client, read, write):
        client.return_value.get_livescores.return_value = [live_payload(), {"id": 999}]
        client.return_value.correct_fixture_details.side_effect = lambda value: value
        result = live.refresh_live_fixtures()
        self.assertEqual(result, {"apply": False, "received": 2, "matched": 1, "updated": 0})
        write.assert_not_called()
        client.return_value.correct_fixture_details.assert_called_once()

    @patch.object(live, "store_live_fixture")
    @patch.object(live, "fetch_all", side_effect=[[(500,)], [(500, 10, 20)]])
    @patch.object(live, "SportmonksClient")
    def test_match_dropped_from_live_list_is_fetched_and_saved(self, client, read, write):
        client.return_value.get_livescores.return_value = []
        fixture = live_payload()
        fixture["state_id"] = 5
        client.return_value.get_live_fixture.return_value = fixture
        client.return_value.correct_fixture_details.side_effect = lambda value: value
        result = live.refresh_live_fixtures(apply=True)
        client.return_value.get_live_fixture.assert_called_once_with(500)
        self.assertEqual(write.call_args.args[:3], (fixture, 10, 20))
        self.assertEqual(result["updated"], 1)

    @patch.object(live, "store_live_fixture")
    @patch.object(live, "fetch_all", return_value=[])
    @patch.object(live, "SportmonksClient")
    def test_empty_live_list_does_not_write(self, client, read, write):
        client.return_value.get_livescores.return_value = []
        self.assertEqual(live.refresh_live_fixtures()["received"], 0)
        read.assert_called_once()
        write.assert_not_called()

    def test_both_live_endpoints_request_same_complete_snapshot(self):
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(return_value={"data": []})
        client.get_livescores()
        client.get_live_fixture(500)
        self.assertEqual([call.args for call in client._get.call_args_list], [("livescores",), ("fixtures/500",)])
        for call in client._get.call_args_list:
            self.assertEqual(call.kwargs["params"], {"include": LIVE_FIXTURE_INCLUDE})


class ClockTests(unittest.TestCase):
    def test_upcoming_has_no_invented_clock_and_extra_time_uses_period_minutes(self):
        fixture = live_payload()
        fixture["periods"] = []
        self.assertEqual(live.normalize_clock(fixture, OBSERVED_AT)[1:8],
                         (None, None, None, None, None, False, None))
        fixture["periods"] = [{"type_id": 3, "counts_from": 90, "period_length": 15,
                               "minutes": 101, "seconds": 25, "ticking": True, "sort_order": 3}]
        self.assertEqual(live.normalize_clock(fixture, OBSERVED_AT)[1:7], (3, 90, 15, 101, 25, True))

    def test_clock_interpolation_pause_and_stale_stop(self):
        cases = [
            (True, 15.9, 29, 5, True, False),
            (False, 20, 28, 50, False, False),
            (True, 60, 29, 35, False, True),
            (True, -1, 28, 50, True, False),
        ]
        for ticking, age, minute, second, expected_ticking, stale in cases:
            with self.subTest(ticking=ticking, age=age):
                row = {"minutes": 28, "seconds": 50, "ticking": ticking, "sample_age_seconds": age}
                with patch.object(clock_repo, "fetch_one_dict", return_value=row):
                    clock = clock_repo.get_fixture_clock(500)
                self.assertEqual((clock["minutes"], clock["seconds"], clock["ticking"], clock["is_stale"]),
                                 (minute, second, expected_ticking, stale))

    def test_missing_sample_or_seconds_does_not_run_clock(self):
        with patch.object(clock_repo, "fetch_one_dict", return_value=None):
            self.assertIsNone(clock_repo.get_fixture_clock(500))
        with patch.object(clock_repo, "fetch_one_dict", return_value={
            "minutes": 28, "seconds": None, "ticking": True, "sample_age_seconds": 2,
        }):
            self.assertFalse(clock_repo.get_fixture_clock(500)["ticking"])


if __name__ == "__main__":
    unittest.main()
