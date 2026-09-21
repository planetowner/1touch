"""종료 경기 범위와 실제 감독 경고 실패를 재현해요."""
from copy import deepcopy
import io
import json
from pathlib import Path
import sqlite3
import unittest
from contextlib import redirect_stdout
from unittest.mock import Mock, patch

from diagnostics import test_fixture_details as samples
from diagnostics.test_fixtures_loader import _fixture_payload
from one_touch_loader import cli
from one_touch_loader.core.sportmonks import SportmonksClient
from one_touch_loader.loaders import fixture_details_loader as details
from one_touch_loader.loaders import fixtures_loader as fixtures
from one_touch_loader.loaders import live_fixtures_loader as live


class CurrentScopeTests(unittest.TestCase):
    def test_historic_teams_keep_original_fixture_identity_across_collections(self):
        cases = json.loads((Path(__file__).parent / 'fixtures/sportmonks_2017_team_identity_errors.json').read_text(encoding='utf-8'))
        client = SportmonksClient.__new__(SportmonksClient)
        for case in cases:
            raw = case['fixture']
            with self.subTest(fixture_id=raw['id']):
                with self.assertRaises(ValueError):
                    live.validate_fixture_participants(raw, case['home'], case['away'])
                corrected = client.correct_fixture_details(deepcopy(raw))
                live.validate_fixture_participants(corrected, case['home'], case['away'])
                self.assertEqual(client.correct_fixture_details(deepcopy(corrected)), corrected)
                normalized = details._normalize_fixture_details(corrected, raw['id'])
                for key, team_index in [('events', 2), ('lineups', 1), ('player_stats', 1), ('team_stats', 1), ('formations', 1), ('fixture_coaches', 1)]:
                    self.assertTrue({row[team_index] for row in normalized[key]} <= {case['home'], case['away']})
                # 같은 이름의 다른 경기까지 재창단 구단과 합치지 않아요.
                other = deepcopy(raw)
                other['id'] = 1
                self.assertEqual(client.correct_fixture_details(other)['participants'], raw['participants'])
                corrected['participants'][0]['id'] = 999999
                with self.assertRaises(ValueError):
                    live.validate_fixture_participants(corrected, case['home'], case['away'])

    def test_real_cli_command_filters_current_season_before_resume(self):
        # 실행 중 PowerShell이 다음 시즌에 사용하는 명령을 그대로 통과시켜요.
        states = [{"id": 90, "state_id": 5}, {"id": 20, "state_id": 1},
                  {"id": 80, "state_id": 7}, {"id": 30, "state_id": 2},
                  {"id": 70, "state_id": 8}, {"id": 40, "state_id": 10}]
        client = Mock()
        client.get_fixtures_batch.return_value = states
        client.get_fixture_details_batch.side_effect = lambda ids: [
            {**samples._payload(), "id": fid} for fid in ids]
        with patch.object(details, "fetch_all", return_value=[(f["id"], 1) for f in states]), \
             patch.object(details, "SportmonksClient", return_value=client), \
             patch.object(details, "replace_fixture_detail_rows", return_value=0) as write, \
             patch("sys.argv", ["cli", "fixture-details", "2026/2027", "8", "82", "301", "384", "564", "2", "5", "2286", "--player-stats-only"]), \
             redirect_stdout(io.StringIO()):
            cli.main()
        self.assertEqual([call.args[0] for call in write.call_args_list], [90, 80, 70])
        client.get_fixtures_batch.assert_called_once_with([90, 20, 80, 30, 70, 40], include="state")

    def test_previous_seasons_keep_scope_without_provider_state_filter(self):
        for season in ("2024/2025", "2025/2026"):
            with self.subTest(season=season), \
                 patch.object(details, "fetch_all", return_value=[(900, 0), (100, 0)]), \
                 patch.object(details, "SportmonksClient") as client:
                self.assertEqual(details._load_scope(season, [8], completed_current_seasons=True), [900, 100])
                client.assert_not_called()

    def test_mixed_all_scope_keeps_old_fixtures_and_empty_current_is_allowed(self):
        with patch.object(details, "fetch_all", return_value=[(900, 0), (100, 1)]), \
             patch.object(details, "SportmonksClient") as client, redirect_stdout(io.StringIO()):
            client.return_value.get_fixtures_batch.return_value = [{"id": 100, "state_id": 1}]
            self.assertEqual(details._load_scope(completed_current_seasons=True), [900])

    def test_live_pending_query_includes_past_ns_only_in_current_seasons(self):
        with patch.object(live, "fetch_all", return_value=[]) as read, \
             patch.object(live, "SportmonksClient") as client:
            client.return_value.get_livescores.return_value = []
            live.refresh_live_fixtures()
        # MySQL의 실제 선택 조건을 SQLite에서도 실행해 과거·미래·연기 경기를 구분해요.
        db = sqlite3.connect(":memory:")
        db.create_function("UTC_TIMESTAMP", 0, lambda: "2026-09-20 17:00:00")
        db.executescript("""
            CREATE TABLE seasons(season_id INTEGER,is_current INTEGER);
            CREATE TABLE stages(stage_id INTEGER,season_id INTEGER);
            CREATE TABLE fixtures(fixture_id INTEGER,stage_id INTEGER,state_id INTEGER,starting_at TEXT);
            INSERT INTO seasons VALUES(1,1),(2,0);
            INSERT INTO stages VALUES(1,1),(2,2);
            INSERT INTO fixtures VALUES
            (1,1,1,'2026-09-20 14:00:00'),(2,1,1,'2026-09-20 19:00:00'),
            (3,2,1,'2025-09-20 14:00:00'),(4,1,10,'2026-09-20 14:00:00'),
            (5,1,2,'2026-09-20 16:00:00'),(6,2,3,'2025-09-20 14:00:00');
        """)
        sql, args = read.call_args.args
        self.assertEqual(db.execute(sql.replace("%s", "?"), args).fetchall(), [(1,), (5,), (6,)])
        db.close()


class CoachStorageTests(unittest.TestCase):
    setUp = samples.FixtureDetailsStorageTests.setUp
    tearDown = samples.FixtureDetailsStorageTests.tearDown

    def test_negative_coach_minutes_reproduce_db_failure_and_store_verified_clock(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks_negative_completion_events.json").read_text(encoding="utf-8"))
        # 실제 MySQL SMALLINT UNSIGNED의 실패를 SQLite에서도 재현해요.
        self.connection.executescript("""
            CREATE TRIGGER fixture_event_minute_range BEFORE INSERT ON fixture_events
            WHEN NEW.minute < 0 OR NEW.minute > 65535 OR NEW.extra_minute < 0 OR NEW.extra_minute > 65535
            BEGIN SELECT RAISE(ABORT, 'event minute out of range'); END;
        """)
        for case in sample["cases"]:
            payload, expected = case["fixture"], case["expected_events"]
            fid = payload["id"]
            with self.subTest(fixture_id=fid):
                self.connection.execute("INSERT INTO fixtures VALUES (?)", (fid,))
                for team in {e["participant_id"] for e in payload["events"]}:
                    self.connection.execute("INSERT OR IGNORE INTO teams VALUES (?)", (team,))
                self.connection.commit()
                raw = details._normalize_fixture_details(payload, fid)
                with self.assertRaisesRegex(sqlite3.IntegrityError, "event minute out of range"):
                    details.replace_fixture_detail_rows(fid, {key: raw[key] for key in ("events", "event_types")})
                corrected = SportmonksClient.__new__(SportmonksClient).correct_fixture_details(deepcopy(payload))
                rows = details._normalize_fixture_details(corrected, fid)
                details.replace_fixture_detail_rows(fid, {key: rows[key] for key in ("events", "event_types")})
                stored = self.connection.execute("SELECT event_id,event_type_id,player_id,minute,extra_minute FROM fixture_events WHERE fixture_id=? ORDER BY event_id", (fid,)).fetchall()
                self.assertEqual(stored, sorted((e["id"], e["type_id"], None, e["minute"], e["extra_minute"]) for e in expected))
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM players").fetchone(), (0,))

    def test_nikolic_duplicate_preserves_real_coach_and_player_cards(self):
        payload = json.loads((Path(__file__).parent / "fixtures/sportmonks-nikolic-duplicate-card.json").read_text(encoding="utf-8"))["fixture"]
        corrected = SportmonksClient.__new__(SportmonksClient).correct_fixture_details(deepcopy(payload))
        self.assertEqual(corrected["events"], [e for e in payload["events"] if e["id"] != 157833589])
        self.assertEqual({(e["id"], e["participant_id"], e["player_id"], e["minute"]) for e in corrected["events"] if e["id"] in (157832802, 157833587)},
                         {(157832802, 781, None, 11), (157833587, 3369, 513103, 80)})
    def test_actual_coach_cards_preserve_events_without_creating_players(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks-coach-actor-cards.json").read_text(encoding="utf-8"))
        for case in sample["cases"]:
            with self.subTest(fixture=case["fixture_id"]):
                fid = case["fixture_id"]
                self.connection.execute("INSERT INTO fixtures VALUES (?)", (fid,))
                for coach in case["coaches"]:
                    self.connection.execute("INSERT OR IGNORE INTO teams VALUES (?)", (coach["meta"]["participant_id"],))
                self.connection.commit()
                payload = {**samples._payload(), "id": fid, "events": deepcopy(case["events"]),
                           "coaches": case["coaches"], "lineups": []}
                keys = ("events", "event_types", "coaches", "fixture_coaches")
                wrong = details._normalize_fixture_details({**payload, "coaches": []}, fid)
                with self.assertRaises(sqlite3.IntegrityError):
                    details.replace_fixture_detail_rows(fid, {k: wrong[k] for k in keys})
                corrected = SportmonksClient.__new__(SportmonksClient).correct_fixture_details(payload)
                rows = details._normalize_fixture_details(corrected, fid)
                details.replace_fixture_detail_rows(fid, {k: rows[k] for k in keys})
                stored = self.connection.execute("SELECT event_id,player_id,minute FROM fixture_events WHERE fixture_id=?", (fid,)).fetchall()
                self.assertEqual(stored, [(e["id"], None, e["minute"]) for e in case["events"]])
                self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM players").fetchone(), (0,))

    def test_coach_match_requires_same_team_and_no_actual_player_slot(self):
        payload = samples._payload()
        payload["lineups"][0]["id"] = 1000
        client = SportmonksClient.__new__(SportmonksClient)
        payload["events"][0].update(player_id=700, type_id=19, type={"code": "yellowcard", "name": "Yellowcard"})
        payload["coaches"][0]["meta"]["participant_id"] = 20
        self.assertEqual(client.correct_fixture_details(deepcopy(payload))["events"][0]["player_id"], 700)
        payload["coaches"][0]["meta"]["participant_id"] = 10
        payload["lineups"][0]["player_id"] = 700
        self.assertEqual(client.correct_fixture_details(deepcopy(payload))["events"][0]["player_id"], 700)


class SelectedScheduleTests(unittest.TestCase):
    def test_repairs_only_selected_schedule_ids_with_shared_cup_rules(self):
        payload = _fixture_payload()
        payload["league_id"] = 24
        client = Mock()
        client.iter_fixtures_by_season.return_value = [payload, {**payload, "id": 1002}]
        with patch.object(fixtures, "_load_base_team_ids", return_value={10}), \
             patch.object(fixtures, "transaction") as transaction, redirect_stdout(io.StringIO()):
            result = fixtures._collect_and_upsert(client, (2001, 24, "2024/2025", False), {10, 20}, fixture_ids={1002})
        self.assertEqual(result["stored_fixture_count"], 1)
        writes = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value.executemany.call_args_list
        actual = [call.args[1] for call in writes if call.args[0] == fixtures.SQL_UPSERT_FIXTURE]
        self.assertEqual([row[0] for row in actual[0]], [1002])

    def test_requested_missing_or_unrelated_cup_fixture_fails_before_writes(self):
        for ids, base in (({9999}, {10}), ({1001}, {30})):
            with self.subTest(ids=ids, base=base), \
                 patch.object(fixtures, "_load_base_team_ids", return_value=base), \
                 patch.object(fixtures, "transaction") as transaction:
                client = Mock()
                client.iter_fixtures_by_season.return_value = [{**_fixture_payload(), "league_id": 24}]
                with self.assertRaisesRegex(ValueError, "Selected fixture IDs differ"):
                    fixtures._collect_and_upsert(client, (2001, 24, "2024/2025", False), {10, 20}, fixture_ids=ids)
                transaction.assert_not_called()


if __name__ == "__main__":
    unittest.main()
