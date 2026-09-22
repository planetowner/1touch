from __future__ import annotations

import json
import unittest
import re
import sqlite3
from copy import deepcopy
from pathlib import Path
from unittest.mock import MagicMock, Mock, patch

from one_touch_loader.api.repos import fixtures_repo
from one_touch_loader.loaders import fixture_details_loader as details
from one_touch_loader.loaders import team_stats_loader
from one_touch_loader.loaders import players_loader
from one_touch_loader.core import db
from one_touch_loader.core.sportmonks import SportmonksClient
from one_touch_loader.loaders.fixture_details_loader import _normalize_fixture_details


def _player() -> dict:
    return {
        "id": 100,
        "name": "Player Full Name",
        "display_name": "Player Name",
        "detailed_position_id": 154,
        "nationality_id": 20,
        "date_of_birth": "2000-01-01",
        "height": 180,
        "weight": 75,
        "image_path": "https://example.test/player.png",
    }


def _payload() -> dict:
    return {
        "id": 500,
        "events": [
            {
                "id": 900,
                "participant_id": 10,
                "type_id": 14,
                "player_id": 100,
                "related_player_id": None,
                "minute": 28,
                "extra_minute": None,
                "on_bench": False,
                "type": {"id": 14, "code": "goal", "name": "Goal"},
            }
        ],
        "statistics": [
            {
                "participant_id": 10,
                "type_id": 45,
                "data": {"value": 63},
                "type": {
                    "id": 45,
                    "code": "ball-possession",
                    "name": "Ball Possession %",
                },
            }
        ],
        "lineups": [
            {
                "player_id": 100,
                "team_id": 10,
                "position_id": 25,
                "type_id": 11,
                "formation_field": "2:4",
                "jersey_number": 2,
                "player": _player(),
                "details": [
                    {"type_id": 118, "data": {"value": 7.38}},
                    {"type_id": 119, "data": {"value": 90}},
                ],
            }
        ],
        "formations": [
            {"participant_id": 10, "formation": "4-3-3"}
        ],
        "coaches": [
            {
                "id": 700,
                "display_name": "Coach Name",
                "meta": {"participant_id": 10},
            }
        ],
        "pressure": [
            {"participant_id": 10, "minute": 1, "pressure": 12.5}
        ],
    }


class FixtureDetailsLoaderTests(unittest.TestCase):
    def test_resume_starts_at_fixture_in_scope_order_for_both_fetch_modes(self):
        # 대회·시각 순서는 ID 오름차순과 달라요. 실패한 경기 자체도 다시 처리해야 해요.
        scope = [11974939, 1818704, 1818000]
        for player_stats_only in (False, True):
            with self.subTest(player_stats_only=player_stats_only), \
                 patch.object(details, "_load_scope", return_value=scope), \
                 patch.object(details, "SportmonksClient") as client, \
                 patch.object(details, "replace_fixture_detail_rows", return_value=0) as write, \
                 patch("builtins.print"):
                client.return_value.get_fixture_details.side_effect = lambda fid: {**_payload(), "id": fid}
                client.return_value.get_fixture_details_batch.side_effect = lambda ids: [
                    {**_payload(), "id": fid} for fid in ids
                ]
                result = details.collect_fixture_details_for_competition_season(
                    "2017/2018", [5], player_stats_only=player_stats_only, from_fixture_id=1818704,
                )
                self.assertEqual(result["fixtures"], 2)
                self.assertEqual([call.args[0] for call in write.call_args_list], scope[1:])
                client.return_value.get_fixture_details_batch.assert_called_once_with(scope[1:])
                client.return_value.get_fixture_details.assert_not_called()

    def test_resume_outside_scope_fails_before_provider_requests_or_writes(self):
        with patch.object(details, "_load_scope", return_value=[500]), \
             patch.object(details, "SportmonksClient") as client, \
             patch.object(details, "replace_fixture_detail_rows") as write:
            with self.assertRaisesRegex(ValueError, "not in the selected"):
                details.collect_fixture_details_for_competition_season("2017/2018", [5], from_fixture_id=1818704)
            client.assert_not_called()
            write.assert_not_called()

    def test_batch_requires_complete_ids_and_uses_existing_corrections(self):
        client = SportmonksClient.__new__(SportmonksClient)
        with patch.object(client, "_get", return_value={"data": [{"id": 501}, {"id": 500}]}), \
             patch.object(client, "correct_fixture_details", side_effect=lambda f: {**f, "corrected": True}):
            self.assertEqual(client.get_fixture_details_batch([500, 501]), [
                {"id": 500, "corrected": True}, {"id": 501, "corrected": True},
            ])
        with patch.object(client, "_get", return_value={"data": [{"id": 500}]}):
            with self.assertRaisesRegex(ValueError, "response IDs differ"):
                client.get_fixture_details_batch([500, 501])
        with patch.object(client, "_get") as read:
            for ids in ([], list(range(51))):
                with self.assertRaises(ValueError):
                    client.get_fixture_details_batch(ids)
            read.assert_not_called()

    def test_full_details_batches_reads_and_keeps_fixture_storage_and_resume_order(self):
        ids = list(range(500, 601))
        with patch.object(details, '_load_scope', return_value=ids), \
                patch.object(details, 'SportmonksClient') as client, \
                patch.object(details, 'replace_fixture_detail_rows', return_value=0) as write, \
                patch('builtins.print'):
            client.return_value.get_fixture_details_batch.side_effect = lambda group: [
                dict(_payload(), id=fid) for fid in group]
            client.return_value.get_fixture_details.side_effect = lambda fid: dict(_payload(), id=fid)
            result = details.collect_fixture_details_for_competition_season('2026/2027', [8])
        self.assertEqual(result['fixtures'], 101)
        self.assertEqual([c.args[0] for c in client.return_value.get_fixture_details_batch.call_args_list],
                         [ids[:50], ids[50:100]])
        client.return_value.get_fixture_details.assert_called_once_with(600)
        self.assertEqual([c.args[:2] for c in write.call_args_list], [
            (fid, _normalize_fixture_details(dict(_payload(), id=fid), fid)) for fid in ids])

    @patch.object(details, "replace_fixture_detail_rows", return_value=0)
    @patch.object(details, "SportmonksClient")
    @patch.object(details, "_load_scope", return_value=list(range(500, 551)))
    def test_player_backfill_batches_and_replaces_only_player_collections(self, scope, client, write):
        payload = _payload()
        payload["lineups"][0]["details"].append({"type_id": 120, "data": {"value": 64}})
        client.return_value.get_fixture_details_batch.side_effect = lambda ids: [
            {**payload, "id": fixture_id} for fixture_id in ids
        ]
        with patch("builtins.print"):
            result = details.collect_fixture_details_for_competition_season(
                "2024/2025", [8], player_stats_only=True,
            )
        self.assertEqual([len(call.args[0]) for call in client.return_value.get_fixture_details_batch.call_args_list], [50, 1])
        self.assertEqual(result["fixtures"], 51)
        self.assertEqual(result["player_stats"], 51)
        self.assertEqual(result["events"], 0)
        self.assertEqual(result["team_stats"], 0)
        for call in write.call_args_list:
            self.assertEqual(set(call.args[1]), {"lineups", "player_stats"})
            self.assertEqual(call.args[1]["player_stats"][0][-1], 64)

    def test_andy_substitution_uses_the_verified_gomez_identity(self):
        payload = _payload()
        for index, lineup in enumerate(payload["lineups"]):
            lineup["id"] = index
        payload["events"] = [{**payload["events"][0], "id": 157312532, "type_id": 18,
                              "participant_id": 7058, "player_id": 37591542,
                              "related_player_id": 37757628, "minute": 86}]
        client = SportmonksClient.__new__(SportmonksClient)
        corrected = client.correct_fixture_details(payload)
        event = _normalize_fixture_details(corrected, 19720965)["events"][0]
        self.assertEqual(event[4:7], (37591542, 37718055, 86))

    def test_normalizes_only_verified_fixture_detail_fields(self) -> None:
        rows = _normalize_fixture_details(
            _payload(),
            fixture_id=500,
        )

        self.assertEqual(rows["event_types"], [(14, "goal", "Goal")])
        self.assertEqual(
            rows["events"],
            [(900, 500, 10, 14, 100, None, 28, None, False)],
        )
        self.assertEqual(
            rows["team_stats"],
            [(500, 10, 45, 63.0)],
        )
        self.assertEqual(
            rows["lineups"],
            [(500, 10, 100, 11, "2:4", 2, 90, 7.38, 25)],
        )
        self.assertEqual(rows["formations"], [(500, 10, "4-3-3")])
        self.assertEqual(rows["coaches"], [(700, "Coach Name")])
        self.assertEqual(rows["fixture_coaches"], [(500, 10, 700)])
        self.assertEqual(rows["pressures"], [(500, 10, 1, 12.5)])

    def test_accepts_empty_collections(self) -> None:
        payload = {"id": 500}
        for key in (
            "events",
            "statistics",
            "lineups",
            "formations",
            "coaches",
            "pressure",
        ):
            payload[key] = []

        rows = _normalize_fixture_details(
            payload,
            fixture_id=500,
        )

        self.assertTrue(all(not values for values in rows.values()))

    def test_upcoming_lineup_keeps_missing_minutes_and_rating_null(self) -> None:
        payload = _payload()
        payload["lineups"][0]["details"] = []
        row = _normalize_fixture_details(payload, 500)["lineups"][0]
        self.assertEqual(row[6:8], (None, None))

    def test_duplicate_player_uses_verified_id_in_events_and_lineups(self) -> None:
        payload = _payload()
        payload["lineups"][0]["player_id"] = 73643
        payload["events"][0]["player_id"] = 73643
        rows = _normalize_fixture_details(payload, 500)
        self.assertEqual(rows["lineups"][0][2], 74062)
        self.assertEqual(rows["events"][0][4], 74062)

    @patch.object(team_stats_loader, "replace_fixture_detail_rows")
    @patch.object(team_stats_loader, "SportmonksClient")
    @patch.object(team_stats_loader, "fetch_all", return_value=[(500,)])
    def test_team_stats_uses_same_normalization_as_details(self, read, client, write) -> None:
        client.return_value.get_fixture_with_statistics.return_value = _payload()
        team_stats_loader.refresh_fixture_team_stats(500)
        expected = _normalize_fixture_details(_payload(), 500)
        write.assert_called_once_with(500, {
            "stat_types": expected["stat_types"], "team_stats": expected["team_stats"],
        })

    @patch.object(team_stats_loader, "replace_fixture_detail_rows")
    @patch.object(team_stats_loader, "SportmonksClient")
    @patch.object(team_stats_loader, "fetch_all")
    def test_season_team_stats_batches_reads_and_preserves_every_normalized_fixture(self, read, client, write):
        ids = list(range(500, 601))
        read.return_value = [(fid,) for fid in ids]
        client.return_value.get_fixture_statistics_batch.side_effect = lambda batch: [
            dict(_payload(), id=fid) for fid in batch]
        with patch('builtins.print'):
            team_stats_loader.refresh_fixture_team_stats_for_season(1, only_status='past')
        self.assertEqual(read.call_count, 1)
        client.assert_called_once_with()
        self.assertEqual([c.args[0] for c in client.return_value.get_fixture_statistics_batch.call_args_list],
                         [ids[:50], ids[50:100], ids[100:]])
        self.assertEqual([c.args for c in write.call_args_list], [
            (fid, details.normalize_fixture_statistics(dict(_payload(), id=fid), fid)) for fid in ids])

    @patch.object(team_stats_loader, "SportmonksClient")
    @patch.object(team_stats_loader, "fetch_all", return_value=[])
    def test_empty_season_does_not_create_provider_client(self, read, client):
        with patch('builtins.print'):
            team_stats_loader.refresh_fixture_team_stats_for_season(1)
        client.assert_not_called()

    @patch.object(team_stats_loader, "replace_fixture_detail_rows")
    @patch.object(team_stats_loader, "SportmonksClient")
    @patch.object(team_stats_loader, "fetch_all", return_value=[(500,), (501,)])
    def test_incomplete_batch_is_not_saved_as_empty_statistics(self, read, client, write):
        client.return_value.get_fixture_statistics_batch.side_effect = ValueError('response IDs differ')
        with self.assertRaisesRegex(ValueError, 'response IDs differ'):
            team_stats_loader.refresh_fixture_team_stats_for_season(1)
        write.assert_not_called()

    @patch.object(db, "get_conn")
    def test_empty_statistics_clear_old_stats_without_deleting_lineups(self, get_conn) -> None:
        connection = MagicMock()
        get_conn.return_value = connection
        cursor = connection.cursor.return_value.__enter__.return_value
        details.replace_fixture_detail_rows(500, {"stat_types": [], "team_stats": []})
        cursor.execute.assert_called_once_with(
            "DELETE FROM fixture_team_stats WHERE fixture_id = %s", (500,),
        )
        cursor.executemany.assert_not_called()
        connection.commit.assert_called_once_with()

    @patch.object(db, "get_conn")
    def test_insert_failure_rolls_back_replaced_collections(self, get_conn) -> None:
        connection = MagicMock()
        get_conn.return_value = connection
        cursor = connection.cursor.return_value.__enter__.return_value
        cursor.executemany.side_effect = RuntimeError("database insert failed")
        with self.assertRaisesRegex(RuntimeError, "database insert failed"):
            details.replace_fixture_detail_rows(500, {"team_stats": [(500, 10, 45, 63)]})
        connection.commit.assert_not_called()
        connection.rollback.assert_called_once_with()
        connection.close.assert_called_once_with()


class FixtureDetailsRepositoryTests(unittest.TestCase):
    @patch("one_touch_loader.api.repos.fixtures_repo.fetch_all_dict")
    @patch("one_touch_loader.api.repos.fixtures_repo.get_fixture")
    def test_adds_detail_collections_to_base_fixture(
        self,
        get_fixture: Mock,
        fetch_all_dict: Mock,
    ) -> None:
        get_fixture.return_value = {"fixture_id": 500, "home_team_id": 10, "away_team_id": 20}
        fetch_all_dict.side_effect = [
            [{"event_id": 900}],
            [{"stat_type_id": 45}],
            [{"player_id": 100, "team_id": 10, "lineup_type_id": 11, "match_position_id": 25,
              "minutes_played": 90, "rating": 7.38}],
            [{"team_id": 10, "formation": "4-3-3"}],
            [{"team_id": 10, "coach_id": 700}],
            [{"team_id": 10, "minute": 1, "pressure": 12.5}],
            [{"team_id": 10, "player_id": 100, "stat_type_id": 120, "value": 64},
             {"team_id": 10, "player_id": 100, "stat_type_id": 97, "value": 3}],
        ]

        with (
            patch.object(fixtures_repo, "get_fixture_expected_goals", return_value=None),
            patch.object(fixtures_repo, "list_fixture_player_expected_goals", return_value=[]),
            patch.object(fixtures_repo, "list_fixture_shots", return_value=[]),
            patch.object(fixtures_repo, "get_fixture_clock", return_value={"minutes": 62}),
        ):
            result = fixtures_repo.get_fixture_detail(500)

        self.assertEqual(result["events"], [{"event_id": 900}])
        self.assertEqual(result["statistics"], [
            {"stat_type_id": 45},
            {"team_id": 10, "stat_type_id": 120, "stat_code": "touches", "stat_name": "Touches", "value": 64},
            {"team_id": 20, "stat_type_id": 120, "stat_code": "touches", "stat_name": "Touches", "value": None},
            {"team_id": 10, "stat_type_id": 97, "stat_code": "blocked-shots", "stat_name": "Blocks", "value": 3},
            {"team_id": 20, "stat_type_id": 97, "stat_code": "blocked-shots", "stat_name": "Blocks", "value": None},
        ])
        self.assertEqual(result["lineups"][0]["player_id"], 100)
        self.assertEqual(result["formations"][0]["formation"], "4-3-3")
        self.assertEqual(result["coaches"][0]["coach_id"], 700)
        self.assertEqual(result["pressure"][0]["minute"], 1)
        self.assertEqual(fetch_all_dict.call_count, 7)
        self.assertEqual(result["player_statistics"][0]["position_group"], "DF")
        build_up = result["player_statistics"][0]["categories"][2]
        self.assertEqual(build_up["metrics"][0]["value"], 64)
        self.assertIsNone(result["expected_goals"])
        self.assertEqual(result["player_expected_goals"], [])
        self.assertEqual(result["shots"], [])
        self.assertEqual(result["clock"], {"minutes": 62})

    @patch.object(fixtures_repo, "fetch_all_dict")
    @patch.object(fixtures_repo, "get_fixture", return_value=None)
    def test_missing_fixture_does_not_query_detail_tables(self, get_fixture, read) -> None:
        self.assertIsNone(fixtures_repo.get_fixture_detail(500))
        read.assert_not_called()


class _SqliteCursor:
    def __init__(self, connection):
        self.cursor = connection.cursor()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.cursor.close()

    @staticmethod
    def _sql(sql):
        sql = sql.replace("%s", "?").replace("ON DUPLICATE KEY UPDATE", "ON CONFLICT DO UPDATE SET")
        return re.sub(r"VALUES\((\w+)\)", r"excluded.\1", sql)

    def execute(self, sql, params=()):
        return self.cursor.execute(self._sql(sql), params)

    def executemany(self, sql, rows):
        return self.cursor.executemany(self._sql(sql), rows)

    def fetchall(self):
        return self.cursor.fetchall()


class _SqliteConnection:
    def __init__(self, connection):
        self.connection = connection

    def cursor(self):
        return _SqliteCursor(self.connection)

    def commit(self):
        self.connection.commit()

    def rollback(self):
        self.connection.rollback()

    def close(self):
        # 풀 연결을 반환한 뒤에도 테스트가 결과를 확인할 수 있게 유지해요.
        pass


class FixtureDetailsStorageTests(unittest.TestCase):
    def setUp(self):
        # 이 테스트는 경기 상세 저장을 검증해요. 실제 랭킹 연동은 test_player_rating_refresh에서 확인해요.
        from contextlib import nullcontext
        ranking_refresh = patch.object(details.player_rankings, "refresh_player_ratings_after_fixture",
                                       side_effect=lambda *args, **kwargs: nullcontext())
        ranking_refresh.start()
        self.addCleanup(ranking_refresh.stop)
        role_refresh = patch.object(details.squad_roles, 'refresh_squad_roles_after_fixture',
                                    side_effect=lambda *args, **kwargs: nullcontext())
        role_refresh.start()
        self.addCleanup(role_refresh.stop)
        # 운영 DB 대신 메모리 안에서 실제 INSERT·DELETE·FK·rollback을 확인해요.
        self.connection = sqlite3.connect(":memory:")
        self.connection.execute("PRAGMA foreign_keys = ON")
        self.connection.executescript("""
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY);
            CREATE TABLE teams (team_id INTEGER PRIMARY KEY);
            CREATE TABLE positions (position_id INTEGER PRIMARY KEY);
            CREATE TABLE players (
                player_id INTEGER PRIMARY KEY, display_name TEXT, full_name TEXT,
                position_id INTEGER REFERENCES positions(position_id), nationality_id INTEGER,
                date_of_birth TEXT, height_cm INTEGER, weight_kg INTEGER, image_path TEXT
            );
            CREATE TABLE player_external_ids (
                player_id INTEGER REFERENCES players(player_id), provider TEXT, external_player_id TEXT,
                PRIMARY KEY (player_id, provider), UNIQUE(provider, external_player_id)
            );
            INSERT INTO fixtures VALUES (500);
            INSERT INTO teams VALUES (10), (20);
            INSERT INTO positions VALUES (154);
        """)
        ddl = (Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_fixture_details_minimal.sql").read_text(encoding="utf-8")
        for table, definition in re.findall(r"CREATE TABLE (\w+) \((.*?)\) ENGINE", ddl, re.S):
            definition = re.sub(r"^  KEY .*\n", "", definition, flags=re.M)
            definition = re.sub(r"UNIQUE KEY \w+", "UNIQUE", definition)
            # SQLite는 UNSIGNED를 검사하지 않아, 실제 분 값 범위를 CHECK로 재현해요.
            definition = definition.replace(
                "minute SMALLINT UNSIGNED NOT NULL",
                "minute SMALLINT UNSIGNED NOT NULL CHECK (minute BETWEEN 0 AND 65535)",
            )
            self.connection.execute(f"CREATE TABLE {table} ({definition})")
        self.connection.execute("ALTER TABLE fixture_lineups ADD COLUMN match_position_id INTEGER")
        stats_ddl = (Path(__file__).resolve().parents[1]
                     / "one_touch_loader/sql/migrate_fixture_player_stats.sql").read_text(encoding="utf-8")
        definition = re.search(r"CREATE TABLE fixture_player_stats \((.*?)\) ENGINE", stats_ddl, re.S).group(1)
        self.connection.execute(f"CREATE TABLE fixture_player_stats ({definition})")
        self.connection.commit()
        self.mock_connection = patch.object(db, "get_conn", return_value=_SqliteConnection(self.connection))
        self.mock_connection.start()

    def tearDown(self):
        self.mock_connection.stop()
        self.connection.close()

    def test_verified_atlantas_duplicate_rolls_back_then_stores_once(self):
        self._assert_verified_duplicate_lineup("sportmonks_atlantas_duplicate_lineup.json", 5681)

    def test_verified_paok_duplicate_rolls_back_then_stores_once(self):
        self._assert_verified_duplicate_lineup("sportmonks_paok_duplicate_lineup.json", 649)

    def test_verified_crvena_zvezda_duplicate_rolls_back_then_stores_once(self):
        self._assert_verified_duplicate_lineup("sportmonks_crvena_zvezda_duplicate_lineup.json", 2673)

    def test_verified_paok_basel_duplicate_rolls_back_then_stores_once(self):
        self._assert_verified_duplicate_lineup("sportmonks_paok_basel_duplicate_lineup.json", 649)

    def test_verified_petrocub_duplicate_rolls_back_then_stores_once(self):
        self._assert_verified_duplicate_lineup("sportmonks_petrocub_duplicate_lineup.json", 6131)

    def test_las_rozas_duplicate_keeps_official_number_26(self):
        self._assert_verified_duplicate_lineup("sportmonks_las_rozas_duplicate_lineup.json", 29542)

    def test_vic_unused_keeper_keeps_bench_slot_without_false_participation(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks_vic_unused_keeper.json").read_text(encoding="utf-8"))
        self._assert_verified_lineup_repair(sample)
        self.assertEqual(self.connection.execute(
            "SELECT player_id,lineup_type_id,jersey_number,minutes_played,rating "
            "FROM fixture_lineups WHERE fixture_id=19320855 ORDER BY jersey_number"
        ).fetchall(), [(37787565, 12, 1, None, None), (37787564, 11, 13, 90, 7.21)])
        self.assertEqual(self.connection.execute(
            "SELECT player_id,stat_value FROM fixture_player_stats "
            "WHERE fixture_id=19320855 AND stat_type_id=57"
        ).fetchall(), [(37787564, 5)])

    def test_ki_unused_petersen_keeps_bench_slot_without_copied_minutes(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks_ki_unused_petersen.json").read_text(encoding="utf-8"))
        self._assert_verified_lineup_repair(sample)
        self.assertEqual(self.connection.execute(
            "SELECT player_id,jersey_number,minutes_played FROM fixture_lineups "
            "WHERE fixture_id=19228790 ORDER BY jersey_number"
        ).fetchall(), [(21782198, 20, 14), (87132, 21, None)])

    def test_trakai_ki_goalkeepers_keep_separate_profiles_and_stats(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks_trakai_ki_goalkeepers.json").read_text(encoding="utf-8"))
        self.connection.execute("INSERT OR IGNORE INTO positions VALUES (24)")
        self._assert_verified_lineup_repair(sample)
        self.assertEqual(self.connection.execute(
            "SELECT player_id,jersey_number,minutes_played FROM fixture_lineups WHERE fixture_id=11896778 ORDER BY jersey_number"
        ).fetchall(), [(85663, 1, 90), (86429, 16, None)])

    def test_celje_substitute_keeps_own_profile_and_four_minutes(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks_celje_dundalk_lineup.json").read_text(encoding="utf-8"))
        self.connection.execute("INSERT OR IGNORE INTO positions VALUES (149)")
        self._assert_verified_lineup_repair(sample)
        self.assertEqual(self.connection.execute(
            "SELECT player_id,lineup_type_id,jersey_number,minutes_played,match_position_id "
            "FROM fixture_lineups WHERE fixture_id=16865255 ORDER BY jersey_number"
        ).fetchall(), [(73772, 11, 4, 90, 25), (183562, 12, 6, 4, None)])

    def test_european_lineup_repairs_preserve_verified_players_and_minutes(self):
        samples = []
        for filename in ("sportmonks_2020_europa_lineup_repairs.json", "sportmonks_2021_qualifier_lineup_repairs.json",
                         "sportmonks_2022_qualifier_lineup_repairs.json",
                         "sportmonks_2024_champions_lineup_repairs.json"):
            samples.extend(json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8")))
        for sample in samples:
            with self.subTest(fixture_id=sample["fixture"]["id"]):
                self.connection.executemany("INSERT OR IGNORE INTO positions VALUES (?)", [(152,), (26,), (24,), (154,)])
                self._assert_verified_lineup_repair(sample)
                self.assertEqual(self.connection.execute(
                    "SELECT player_id,lineup_type_id,jersey_number,minutes_played,match_position_id "
                    "FROM fixture_lineups WHERE fixture_id=? ORDER BY jersey_number",
                    (sample["fixture"]["id"],),
                ).fetchall(), [tuple(row) for row in sample["expected_lineups"]])

    def test_kups_null_slots_restore_verified_stats_without_inventing_values(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks_kups_slovan_null_players.json").read_text(encoding="utf-8"))
        payload = sample["fixtures"][0]
        fixture_id = payload["id"]
        profiles = {p["id"]: p for p in sample["correct_players"]}
        # 선수 ID가 비어 있으면 기존 로더는 두 선수의 실제 출전·골 통계를 저장하지 못해요.
        raw = details.normalize_fixture_lineups(payload, fixture_id)
        self.assertEqual(raw["lineups"], [])
        self.assertEqual(raw["player_stats"], [])
        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(side_effect=lambda path, **kwargs: {
            "data": [deepcopy(payload)] if path.startswith("fixtures/multi/") else deepcopy(profiles[int(path.split("/")[1])])
        })
        corrected = client.get_fixture_details_batch([fixture_id])[0]
        for before, after in zip(payload["lineups"], corrected["lineups"]):
            self.assertEqual(before["details"], after["details"])
        rows = details.normalize_fixture_lineups(corrected, fixture_id)
        self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
        self.connection.execute("INSERT INTO teams VALUES (4323)")
        self.connection.commit()
        selected = {k: rows[k] for k in ("lineups", "player_stats")}
        self.assertEqual(details.replace_fixture_detail_rows(fixture_id, selected, corrected["lineups"]), 2)
        self.assertEqual(details.replace_fixture_detail_rows(fixture_id, selected, corrected["lineups"]), 0)
        self.assertEqual(self.connection.execute(
            "SELECT player_id,jersey_number,minutes_played FROM fixture_lineups WHERE fixture_id=? ORDER BY jersey_number",
            (fixture_id,),
        ).fetchall(), [(151627, 13, 33), (90876, 20, 115)])
        self.assertEqual(self.connection.execute(
            "SELECT player_id,stat_type_id,stat_value FROM fixture_player_stats WHERE fixture_id=?", (fixture_id,),
        ).fetchall(), [(151627, 52, 1)])

    def test_zeta_vukcevic_players_keep_separate_profiles_and_minutes(self):
        samples = json.loads((Path(__file__).parent / "fixtures/sportmonks_zeta_vukcevic.json").read_text(encoding="utf-8"))
        for sample in samples:
            with self.subTest(fixture_id=sample["fixture"]["id"]):
                self.connection.execute("INSERT OR IGNORE INTO positions VALUES (25)")
                self._assert_verified_lineup_repair(sample)
                self.assertEqual(self.connection.execute(
                    "SELECT player_id,jersey_number,minutes_played FROM fixture_lineups WHERE fixture_id=? ORDER BY jersey_number",
                    (sample["fixture"]["id"],),
                ).fetchall(), [tuple(row) for row in sample["expected_lineups"]])

    def test_remaining_lineup_repairs_preserve_stats_and_store_once(self):
        for filename in ("sportmonks_2018_lineup_repairs.json", "sportmonks_2018_completion_lineups.json", "sportmonks_2019_completion_lineups.json", "sportmonks_2020_completion_lineups.json", "sportmonks_2021_completion_lineups.json", "sportmonks_2022_completion_lineups.json", "sportmonks_2023_completion_lineups.json", "sportmonks_2024_completion_lineups.json", "sportmonks_2025_completion_lineups.json", "sportmonks_2025-semantic_completion_lineups.json", "sportmonks_2017_completion_lineups.json", "sportmonks_2022-barbadas_completion_lineups.json", "sportmonks_2022-existing_completion_lineups.json"):
            samples = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
            for sample in samples:
                with self.subTest(fixture_id=sample["fixture"]["id"]):
                    self._assert_verified_lineup_repair(sample)

    def _assert_verified_duplicate_lineup(self, sample_name, team_id):
        sample = json.loads((Path(__file__).parent / "fixtures" / sample_name).read_text(encoding="utf-8"))
        verified = sample["verified_lineup"]
        sample.update(team_id=team_id, removed_lineup_ids=[verified["removed_lineup_id"]],
                      lineup_overrides={}, profiles={}, stat_player_overrides={})
        self._assert_verified_lineup_repair(sample)
        self.assertEqual(self.connection.execute(
            "SELECT jersey_number FROM fixture_lineups WHERE fixture_id=? AND player_id=?",
            (sample["fixture"]["id"], verified["player_id"]),
        ).fetchall(), [(verified["jersey_number"],)])

    def _assert_verified_lineup_repair(self, sample):
        payload, fid = sample["fixture"], sample["fixture"]["id"]
        self.connection.execute("INSERT INTO fixtures VALUES (?)", (fid,))
        self.connection.executemany("INSERT OR IGNORE INTO teams VALUES (?)", {
            (lineup["team_id"],) for lineup in payload["lineups"]
        })
        self.connection.executemany("INSERT OR IGNORE INTO positions VALUES (?)", {
            (profile["detailed_position_id"],)
            for profile in [*(lineup["player"] for lineup in payload["lineups"]), *sample["profiles"].values()]
            if profile and profile.get("detailed_position_id") is not None
        })
        self.connection.commit()
        before = self.connection.execute("SELECT COUNT(*) FROM players").fetchone()
        raw = details.normalize_fixture_lineups(payload, fid)
        if sample.get("raw_duplicate", True):
            with self.assertRaisesRegex(sqlite3.IntegrityError, "UNIQUE constraint failed"):
                details.replace_fixture_detail_rows(fid, {k: raw[k] for k in ("lineups", "player_stats")}, payload["lineups"])
            self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM players").fetchone(), before)
        else:
            # 중복 없는 미출전 오기는 이미 저장된 잘못된 통계까지 제거하는지 확인해요.
            details.replace_fixture_detail_rows(fid, {k: raw[k] for k in ("lineups", "player_stats")}, payload["lineups"])
            self.assertEqual(self.connection.execute(
                "SELECT COUNT(*) FROM fixture_player_stats WHERE fixture_id=?", (fid,)
            ).fetchone(), (len(raw["player_stats"]),))

        expected = deepcopy(payload)
        expected["lineups"] = [r for r in expected["lineups"] if r["id"] not in sample["removed_lineup_ids"]]
        for lineup in expected["lineups"]:
            changes = sample["lineup_overrides"].get(str(lineup["id"]), {})
            lineup.update(changes)
            if changes.get("player_id") is not None:
                lineup["player"] = sample["profiles"][str(changes["player_id"])]
            stats = dict(sample.get("stat_overrides", {}).get(str(lineup["id"]), {}))
            minutes = sample.get("minutes_overrides", {}).get(str(lineup["id"]))
            if minutes is not None:
                stats['119'] = minutes
            for detail in lineup["details"]:
                if str(detail["type_id"]) in stats:
                    detail["data"]["value"] = stats[str(detail["type_id"])]
        client = SportmonksClient.__new__(SportmonksClient)
        def response(path, params=None):
            if path.startswith("players/"):
                return {"data": deepcopy(sample["profiles"][path.split("/")[-1]])}
            return {"data": [deepcopy(payload)] if path.startswith("fixtures/multi/") else deepcopy(payload)}
        client._get = Mock(side_effect=response)
        corrected = client.get_fixture_details_batch([fid])[0]
        self.assertEqual(corrected, expected)
        self.assertEqual(client.get_fixture_details(fid), expected)
        self.assertEqual(client.correct_fixture_details(deepcopy(corrected)), expected)
        rows = details.normalize_fixture_lineups(corrected, fid)
        rows = {k: rows[k] for k in ("lineups", "player_stats")}
        # 같은 잘못된 선수 ID의 두 슬롯도 실제로는 다른 선수일 수 있어요.
        # 검증된 슬롯별 기대값으로 확인해야 정상 슬롯의 통계까지 옮기는 오류를 잡아요.
        expected_stats = {
            (fid, lineup["team_id"], details._canonical_player_id(lineup["player_id"]), stat["type_id"], stat["data"]["value"])
            for lineup in expected["lineups"] for stat in lineup["details"]
            if lineup["player_id"] is not None
            and stat["type_id"] in details.STORED_STAT_TYPE_IDS and stat["data"]["value"] is not None
        }
        for player_id in sample.get("discarded_stat_player_ids", []):
            self.assertTrue(any(row[2] == player_id for row in raw["player_stats"]))
        self.assertEqual(set(rows["player_stats"]), expected_stats)
        details.replace_fixture_detail_rows(fid, rows, corrected["lineups"])
        self.assertEqual(details.replace_fixture_detail_rows(fid, rows, corrected["lineups"]), 0)
        self.assertEqual(self.connection.execute(
            "SELECT COUNT(*) FROM fixture_lineups WHERE fixture_id=?", (fid,)
        ).fetchone(), (sum(lineup["player_id"] is not None for lineup in expected["lineups"]),))
        stored = self.connection.execute(
            "SELECT fixture_id,team_id,player_id,stat_type_id,stat_value FROM fixture_player_stats WHERE fixture_id=?", (fid,)
        ).fetchall()
        self.assertEqual(set(stored), expected_stats)
        self.assertEqual(len(stored), len(expected_stats))

        # 검증하지 않은 슬롯 ID에는 등번호·선수 변경이나 중복 제거를 적용하지 않아요.
        unverified = deepcopy(payload)
        for lineup in unverified["lineups"]:
            lineup["id"] += 100_000_000_000
        self.assertEqual(client.correct_fixture_details(deepcopy(unverified)), unverified)

    def test_gent_wrong_identity_is_corrected_in_goal_lineup_and_player_stats(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks-gent-vergara.json").read_text(encoding="utf-8"))
        payload = sample["fixture"]
        fid = payload["id"]
        self.connection.execute("INSERT INTO fixtures VALUES (?)", (fid,))
        self.connection.execute("INSERT INTO teams VALUES (2402)")
        self.connection.execute("INSERT INTO positions VALUES (151)")
        self.connection.execute("INSERT INTO players(player_id) VALUES (37317388)")
        rows = _normalize_fixture_details(payload, fid)
        selected = {key: rows[key] for key in ("event_types", "events", "lineups", "player_stats")}
        details.replace_fixture_detail_rows(fid, selected, payload["lineups"])
        before = self.connection.execute("SELECT lineup_type_id,jersey_number,minutes_played,rating FROM fixture_lineups").fetchall()
        client = SportmonksClient.__new__(SportmonksClient)
        with patch.object(client, "_get", return_value={"data": sample["profile"]}):
            corrected = client.correct_fixture_details(deepcopy(payload))
        rows = _normalize_fixture_details(corrected, fid)
        selected = {key: rows[key] for key in ("event_types", "events", "lineups", "player_stats")}
        self.assertEqual(details.replace_fixture_detail_rows(fid, selected, corrected["lineups"]), 1)
        self.assertEqual(details.replace_fixture_detail_rows(fid, selected, corrected["lineups"]), 0)
        self.assertEqual(self.connection.execute("SELECT lineup_type_id,jersey_number,minutes_played,rating FROM fixture_lineups").fetchall(), before)
        self.assertEqual(self.connection.execute("SELECT player_id FROM fixture_lineups").fetchall(), [(37765373,)])
        self.assertEqual(self.connection.execute("SELECT player_id,minute,related_player_id FROM fixture_events").fetchall(), [(37765373,39,37317388)])
        self.assertEqual(self.connection.execute("SELECT DISTINCT player_id FROM fixture_player_stats").fetchall(), [(37765373,)])
        self.assertEqual(self.connection.execute("SELECT display_name FROM players WHERE player_id=37737079").fetchone(), ("José Mendieta",))

    def test_new_player_and_details_store_once_then_existing_profile_is_preserved(self):
        payload = _payload()
        rows = _normalize_fixture_details(payload, 500)
        self.assertEqual(details.replace_fixture_detail_rows(500, rows, payload["lineups"]), 1)
        payload["lineups"][0]["player"]["detailed_position_id"] = None
        payload["lineups"][0]["player"]["display_name"] = "Changed profile"
        self.assertEqual(details.replace_fixture_detail_rows(500, rows, payload["lineups"]), 0)
        self.assertEqual(self.connection.execute("SELECT display_name,position_id FROM players").fetchall(), [("Player Name", 154)])
        self.assertEqual(self.connection.execute("SELECT * FROM player_external_ids").fetchall(), [(100, "sportmonks", "100")])
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_lineups").fetchone(), (1,))

    def test_player_insert_and_detail_deletes_roll_back_together(self):
        self.connection.execute("INSERT INTO fixture_formations VALUES (500, 10, '4-4-2')")
        self.connection.commit()
        payload = _payload()
        rows = _normalize_fixture_details(payload, 500)
        # 공급자 문제가 아니라 FK 실패 시 기존 묶음을 보존하는 저장 계약을 확인해요.
        rows["pressures"] = [(500, 999, 1, 12.5)]
        with self.assertRaises(sqlite3.IntegrityError):
            details.replace_fixture_detail_rows(500, rows, payload["lineups"])
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM players").fetchone(), (0,))
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM player_external_ids").fetchone(), (0,))
        self.assertEqual(self.connection.execute("SELECT formation FROM fixture_formations").fetchall(), [("4-4-2",)])

    def test_missing_player_uses_existing_name_override(self):
        profile = _player()
        profile["id"] = 1101
        with _SqliteCursor(self.connection) as cursor:
            players_loader.insert_missing_player_profiles(cursor, {1101: profile})
        self.assertEqual(self.connection.execute("SELECT player_id,display_name FROM players").fetchall(), [(1101, "Robbie Brady")])

    def test_real_lineup_player_error_is_corrected_without_dropping_a_player(self):
        cases = (
            ("sportmonks_lineup_player_id_errors.json", 0, [(149243, 11, 16, 90), (148658, 12, 32, None)]),
            ("sportmonks_lineup_2022_spanish_errors.json", 0, [(37608061, 12, 28, None), (37614327, 12, 35, None)]),
            ("sportmonks_lineup_2022_spanish_errors.json", 1, [(37592616, 12, 30, None), (37308357, 12, 31, None), (37543847, 12, 32, None)]),
            ("sportmonks_lineup_2022_spanish_errors.json", 2, [(37590132, 12, 32, None), (37598694, 12, 33, None)]),
        )
        for filename, fixture_index, expected in cases:
            sample = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
            payload = sample["fixtures"][fixture_index]
            fixture_id = payload["id"]
            with self.subTest(fixture_id=fixture_id):
                players = {player["id"]: player for player in sample["correct_players"]}
                for row in payload["lineups"]:
                    players[row["player"]["id"]] = row["player"]
                self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
                self.connection.executemany("INSERT OR IGNORE INTO teams VALUES (?)", {(row["team_id"],) for row in payload["lineups"]})
                self.connection.executemany("INSERT OR IGNORE INTO positions VALUES (?)", {
                    (player["detailed_position_id"],) for player in players.values() if player["detailed_position_id"] is not None
                })
                self.connection.commit()
                before_players = self.connection.execute("SELECT * FROM players ORDER BY player_id").fetchall()
                # 실제 중복 PK를 재현하고, 잘못된 선수 프로필도 함께 롤백되는지 확인해요.
                with self.assertRaisesRegex(sqlite3.IntegrityError, "UNIQUE constraint failed: fixture_lineups"):
                    details.replace_fixture_detail_rows(fixture_id, details.normalize_fixture_lineups(payload, fixture_id), payload["lineups"])
                self.assertEqual(self.connection.execute("SELECT * FROM players ORDER BY player_id").fetchall(), before_players)

                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(side_effect=lambda path, **kwargs: {
                    "data": deepcopy({**payload, "events": []}) if path.startswith("fixtures/") else players[int(path.split("/")[1])]
                })
                corrected = client.get_fixture_details(fixture_id)
                rows = details.normalize_fixture_lineups(corrected, fixture_id)
                self.assertEqual(details.replace_fixture_detail_rows(fixture_id, rows, corrected["lineups"]), len(expected))
                self.assertEqual(details.replace_fixture_detail_rows(fixture_id, rows, corrected["lineups"]), 0)
                self.assertEqual(self.connection.execute(
                    "SELECT player_id,lineup_type_id,jersey_number,minutes_played FROM fixture_lineups WHERE fixture_id=? ORDER BY jersey_number",
                    (fixture_id,),
                ).fetchall(), expected)
                for player_id, *_ in expected:
                    self.assertEqual(self.connection.execute(
                        "SELECT display_name FROM players WHERE player_id=?", (player_id,),
                    ).fetchone(), (players[player_id]["display_name"],))

    def test_verified_lineup_and_event_ids_store_only_confirmed_players(self):
        for filename in (
            "sportmonks_2017_floriana_lineup_error.json",
            "sportmonks_2025_sant_andreu_actor_errors.json",
            "sportmonks_2025_quintanar_actor_errors.json",
            "sportmonks_2025_navalcarnero_lineup_errors.json",
            "sportmonks_2025_cano_tapiador_lineup_errors.json",
            "sportmonks_2025_birch_lineup_error.json",
            "sportmonks_2025_tre_fiori_first_lineup_errors.json",
            "sportmonks_2025_tre_fiori_return_lineup_errors.json",
            "sportmonks_2025_paks_substitution_error.json",
            "sportmonks_2025_warlow_bench_red.json",
            "sportmonks_2025_kolgeci_lineup_errors.json",
            "sportmonks_2025_egnatia_jefferson_lineup_errors.json",
            "sportmonks_2025_sarajevo_owen_lineup_errors.json",
            "sportmonks_2024_cup_two_lineup_errors.json",
            "sportmonks_2024_olot_lineup_errors.json",
            "sportmonks_2024_sant_andreu_lineup_errors.json",
            "sportmonks_2024_conquense_lineup_errors.json",
            "sportmonks_2024_orihuela_lineup_errors.json",
            "sportmonks_2024_salamanca_lineup_errors.json",
            "sportmonks_2024_logrones_europa_lineup_errors.json",
            "sportmonks_2024_cacereno_lineup_errors.json",
            "sportmonks_2024_swansea_edu_lineup_errors.json",
            "sportmonks_2024_ceuta_lineup_errors.json",
            "sportmonks_2024_european_four_lineup_errors.json",
            "sportmonks_lineup_null_player_id.json",
            "sportmonks_lineup_event_player_mismatch.json",
            "sportmonks_2026_strassen_actor_errors.json",
            "sportmonks_2026_conference_lineups.json",
        ):
            sample = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
            profiles = {p["id"]: p for p in sample["correct_players"]}
            # 운영에 이미 있는 이벤트 배우는 표본의 시작 상태로만 넣어요. 빈 명단은 만들지 않아요.
            self.connection.executemany("INSERT OR IGNORE INTO players (player_id) VALUES (?)", [
                (player_id,) for player_id in sample.get("known_player_ids", [])
            ])
            for payload in sample["fixtures"]:
                fixture_id = payload["id"]
                with self.subTest(fixture_id=fixture_id):
                    profiles.update({l["player_id"]: l["player"] for l in payload["lineups"] if l["player_id"] is not None})
                    self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
                    self.connection.executemany("INSERT OR IGNORE INTO teams VALUES (?)", {(l["team_id"],) for l in payload["lineups"]})
                    self.connection.executemany("INSERT OR IGNORE INTO positions VALUES (?)", {
                        (p["detailed_position_id"],) for p in profiles.values() if p["detailed_position_id"] is not None
                    })
                    self.connection.commit()
                    before_players = self.connection.execute("SELECT COUNT(*) FROM players").fetchone()
                    # 라인업이 실제 교체 선수를 가리키지 않으면 이벤트의 선수 FK가 실패해요.
                    if sample.get("raw_fk_failure", {}).get(str(fixture_id), True):
                        with self.assertRaisesRegex(sqlite3.IntegrityError, "FOREIGN KEY constraint failed"):
                            details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id), payload["lineups"])
                        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM players").fetchone(), before_players)
                    else:
                        # 앞 경기에서 같은 선수를 이미 저장했다면 FK는 통과해도 빈 명단은 남아요.
                        details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id), payload["lineups"])

                    client = SportmonksClient.__new__(SportmonksClient)
                    client._get = Mock(side_effect=lambda path, **kwargs: {
                        "data": deepcopy(payload) if path.startswith("fixtures/") else deepcopy(profiles[int(path.split("/")[1])])
                    })
                    corrected = client.get_fixture_details(fixture_id)
                    expected_events = sample.get("expected_events", {}).get(str(fixture_id), payload["events"])
                    self.assertEqual(corrected["events"], expected_events)
                    # Sheriff의 다른 null 슬롯은 검증하지 않았으므로 그대로 남아야 해요.
                    for lineup in corrected["lineups"]:
                        if lineup["id"] == 14674133358:
                            self.assertIsNone(lineup["player_id"])
                    self.assertEqual(client._get.call_count, 1 + sample.get("expected_profile_requests", {}).get(str(fixture_id), 1))
                    rows = _normalize_fixture_details(corrected, fixture_id)
                    expected = sorted(
                        (tuple(row) for row in sample["expected_lineups"][str(fixture_id)]),
                        key=lambda row: (row[1], row[0]),
                    )
                    existing_ids = {row[0] for row in self.connection.execute("SELECT player_id FROM players")}
                    self.assertEqual(
                        details.replace_fixture_detail_rows(fixture_id, rows, corrected["lineups"]),
                        len({player_id for player_id, _ in expected} - existing_ids),
                    )
                    self.assertEqual(details.replace_fixture_detail_rows(fixture_id, rows, corrected["lineups"]), 0)
                    self.assertEqual(self.connection.execute(
                        "SELECT event_id,player_id,related_player_id,minute FROM fixture_events WHERE fixture_id=? ORDER BY event_id", (fixture_id,),
                    ).fetchall(), sorted((e["id"], e["player_id"], e["related_player_id"], e["minute"]) for e in expected_events))
                    self.assertEqual(self.connection.execute(
                        "SELECT player_id,jersey_number FROM fixture_lineups WHERE fixture_id=? ORDER BY jersey_number,player_id", (fixture_id,),
                    ).fetchall(), expected)
                    for player_id, _ in expected:
                        self.assertEqual(self.connection.execute(
                            "SELECT full_name,date_of_birth FROM players WHERE player_id=?", (player_id,),
                        ).fetchone(), (profiles[player_id]["name"], profiles[player_id]["date_of_birth"]))
                    # 벤치 퇴장·빈 상세를 연결해도 검증하지 않은 출전 분·통계를 만들면 안 돼요.
                    for player_id, values in sample.get("expected_player_participation", {}).get(str(fixture_id), {}).items():
                        self.assertEqual(self.connection.execute(
                            "SELECT lineup_type_id,jersey_number,minutes_played,rating FROM fixture_lineups "
                            "WHERE fixture_id=? AND player_id=?", (fixture_id, int(player_id)),
                        ).fetchone(), tuple(values["lineup"]))
                        self.assertEqual(self.connection.execute(
                            "SELECT stat_type_id,stat_value FROM fixture_player_stats "
                            "WHERE fixture_id=? AND player_id=? ORDER BY stat_type_id", (fixture_id, int(player_id)),
                        ).fetchall(), [tuple(row) for row in values["stats"]])

    def test_verified_rexhaj_name_only_preserves_events_and_missing_fields(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks_rexhaj_missing_profile.json").read_text(encoding="utf-8"))
        payload = sample["fixture"]
        fixture_id = payload["id"]
        self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
        self.connection.execute("INSERT INTO teams VALUES (?)", (231923,))
        self.connection.executemany("INSERT OR IGNORE INTO positions VALUES (?)", {
            (lineup["player"]["detailed_position_id"],) for lineup in payload["lineups"]
            if lineup["player"] is not None and lineup["player"]["detailed_position_id"] is not None
        })
        self.connection.commit()
        # 실제 원문은 Rexhaj가 등록되지 않아 교체·퇴장과 다른 선수 삽입까지 취소돼요.
        with self.assertRaisesRegex(sqlite3.IntegrityError, "FOREIGN KEY constraint failed"):
            details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id), payload["lineups"])
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM players").fetchone(), (0,))

        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(side_effect=lambda path, **kwargs: {"data": deepcopy(payload)})
        corrected = client.get_fixture_details(fixture_id)
        self.assertEqual(corrected["events"], payload["events"])
        self.assertEqual(client._get.call_count, 1)
        with patch.object(details, "_load_scope", return_value=[fixture_id]), patch.object(details, "SportmonksClient", return_value=client), patch("builtins.print"):
            self.assertEqual(details.collect_fixture_details(fixture_id)["players"], 2)
            self.assertEqual(self.connection.execute(
                "SELECT * FROM players WHERE player_id=37763035"
            ).fetchone(), (37763035, "Arvanit Rexhaj", "Arvanit Rexhaj", None, None, None, None, None, None))
            self.assertEqual(self.connection.execute(
                "SELECT event_id,player_id,related_player_id,minute FROM fixture_events ORDER BY event_id"
            ).fetchall(), [(157313161, 37763035, 13186421, 81), (157313199, 37763035, None, 88)])
            self.assertEqual(self.connection.execute(
                "SELECT player_id,jersey_number FROM fixture_lineups WHERE player_id=37763035"
            ).fetchall(), [(37763035, 6)])
            self.assertEqual(self.connection.execute(
                "SELECT provider,external_player_id FROM player_external_ids WHERE player_id=37763035"
            ).fetchall(), [("sportmonks", "37763035")])
            # 이후 확보한 프로필이 있어도 경기 재수집의 최소 정보로 지워지면 안 돼요.
            self.connection.execute("UPDATE players SET display_name='기존 검증 이름',position_id=154 WHERE player_id=37763035")
            self.connection.commit()
            self.assertEqual(details.collect_fixture_details(fixture_id)["players"], 0)
            self.assertEqual(self.connection.execute(
                "SELECT display_name,position_id FROM players WHERE player_id=37763035"
            ).fetchone(), ("기존 검증 이름", 154))

        # 같은 이름이 있어도 확인한 라인업 슬롯 밖에는 이 예외를 적용하지 않아요.
        rex = next(lineup for lineup in payload["lineups"] if lineup["id"] == 14674190712)
        rex["id"] = 999
        unverified = client.get_fixture_details(fixture_id)
        self.assertEqual(unverified, payload)

    def test_verified_event_profile_without_lineup_is_inserted_atomically(self):
        baseline = sqlite3.connect(":memory:")
        self.addCleanup(baseline.close)
        self.connection.backup(baseline)
        for filename in (
            "sportmonks_event_player_missing_lineup.json",
            "sportmonks_lisakovich_missing_lineup.json",
            "sportmonks_charles_cook_missing_lineup.json",
            "sportmonks_2017_aik_ki_missing_lineups.json",
            "sportmonks_2017_bristol_missing_lineups.json",
            "sportmonks_2017_braga_away_missing_lineups.json",
            "sportmonks_2017_braga_home_missing_lineups.json",
            "sportmonks_2017_zelj_first_actor_errors.json",
            "sportmonks_2018_aik_missing_lineups.json",
            "sportmonks_2018_bala_missing_lineup.json",
            "sportmonks_2019_aik_missing_lineups.json",
            "sportmonks_2020_completion_profiles.json", "sportmonks_2021_completion_profiles.json", "sportmonks_2022_completion_profiles.json", "sportmonks_2023_completion_profiles.json", "sportmonks_2024_completion_profiles.json", "sportmonks_2025_completion_profiles.json", "sportmonks_2025-semantic_completion_profiles.json", "sportmonks_2017_completion_profiles.json",
        ):
            sample = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
            cases = sample["cases"] if "cases" in sample else [{"fixture": sample["fixture"]}]
            for case in cases:
                payload = case["fixture"]
                fixture_id = payload["id"]
                mapping = {int(eid): pids for eid, pids in case["event_profile_ids"].items()} if "event_profile_ids" in case else {
                    payload["events"][0]["id"]: [payload["events"][0]["player_id"]]
                }
                profiles = {pid: sample["profiles"][str(pid)] for pids in mapping.values() for pid in pids}
                with self.subTest(fixture_id=fixture_id):
                    # 같은 선수의 앞선 경기 저장이 다음 표본의 실제 프로필 누락을 가리지 않게 해요.
                    self.connection.rollback()
                    baseline.backup(self.connection)
                    self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
                    self.connection.executemany("INSERT OR IGNORE INTO teams VALUES (?)", {
                        (event["participant_id"],) for event in payload["events"]
                    } | {(lineup["team_id"],) for lineup in payload["lineups"]})
                    lineup_profiles = {l["player_id"]: l["player"] for l in payload["lineups"] if l["player_id"] is not None and l["player"]}
                    self.connection.executemany("INSERT OR IGNORE INTO positions VALUES (?)", {
                        (p["detailed_position_id"],) for p in [*profiles.values(), *lineup_profiles.values()]
                        if p["detailed_position_id"] is not None
                    })
                    # 기존 DB에 있는 다른 이벤트 배우만 시작 상태로 넣고, 빠진 명단을 만들지 않아요.
                    existing_ids = {pid for event in payload["events"] for pid in (event["player_id"], event["related_player_id"])
                                    if pid is not None} - profiles.keys() - lineup_profiles.keys()
                    self.connection.executemany("INSERT OR IGNORE INTO players(player_id) VALUES (?)", [(pid,) for pid in existing_ids])
                    self.connection.commit()
                    before_players = self.connection.execute("SELECT * FROM players ORDER BY player_id").fetchall()
                    before_ids = {row[0] for row in before_players}
                    client = SportmonksClient.__new__(SportmonksClient)
                    client._get = Mock(side_effect=lambda path, **kwargs: {
                        "data": deepcopy(payload) if path.startswith("fixtures/") else deepcopy(sample["profiles"][path.split("/")[1]])
                    })
                    with self.assertRaisesRegex(sqlite3.IntegrityError, "FOREIGN KEY constraint failed"):
                        details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id), payload["lineups"])
                    self.assertEqual(self.connection.execute("SELECT * FROM players ORDER BY player_id").fetchall(), before_players)
                    self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_events WHERE fixture_id=?", (fixture_id,)).fetchone(), (0,))

                    corrected = client.get_fixture_details(fixture_id)
                    expected = deepcopy(payload)
                    duplicate_ids = set(case.get("duplicate_event_ids", []))
                    expected["events"] = [event for event in expected["events"] if event["id"] not in duplicate_ids]
                    for event in expected["events"]:
                        event.update(case.get("event_overrides", {}).get(str(event["id"]), {}))
                        if event["id"] in mapping:
                            event["verified_player_profiles"] = [profiles[pid] for pid in mapping[event["id"]]]
                    self.assertEqual(corrected, case.get("expected", expected))
                    self.assertEqual(corrected, expected)
                    self.assertEqual(client._get.call_count, 1 + case.get("expected_profile_requests", sum(map(len, mapping.values()))))
                    # 확인한 이벤트 보정 외 실제 카드·명단·통계의 모든 값은 그대로예요.
                    rows = _normalize_fixture_details(corrected, fixture_id)
                    expected_rows = _normalize_fixture_details(expected, fixture_id)
                    expected_rows["events"] = [row for row in expected_rows["events"] if row[0] not in duplicate_ids]
                    self.assertEqual(rows, expected_rows)
                    with patch.object(details, "_load_scope", return_value=[fixture_id]), patch.object(details, "SportmonksClient", return_value=client), patch("builtins.print"):
                        expected_new = (profiles.keys() | lineup_profiles.keys()) - before_ids
                        self.assertEqual(details.collect_fixture_details(fixture_id)["players"], len(expected_new))
                        for pid in profiles:
                            self.connection.execute("UPDATE players SET display_name='기존 검증 이름' WHERE player_id=?", (pid,))
                        self.connection.commit()
                        self.assertEqual(details.collect_fixture_details(fixture_id)["players"], 0)
                    for table, columns, key in (
                        ("fixture_events", "event_id,fixture_id,team_id,event_type_id,player_id,related_player_id,minute,extra_minute,on_bench", "events"),
                        ("fixture_lineups", "fixture_id,team_id,player_id,lineup_type_id,formation_field,jersey_number,minutes_played,rating,match_position_id", "lineups"),
                        ("fixture_player_stats", "fixture_id,team_id,player_id,stat_type_id,stat_value", "player_stats"),
                    ):
                        stored = self.connection.execute(f"SELECT {columns} FROM {table} WHERE fixture_id=?", (fixture_id,)).fetchall()
                        self.assertEqual(set(stored), set(rows[key]))
                        self.assertEqual(len(stored), len(rows[key]))
                    for pid, profile in profiles.items():
                        self.assertEqual(self.connection.execute("SELECT display_name,date_of_birth FROM players WHERE player_id=?", (pid,)).fetchone(), ("기존 검증 이름", profile["date_of_birth"]))
                        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_lineups WHERE fixture_id=? AND player_id=?", (fixture_id,pid)).fetchone(), (0,))
                        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_player_stats WHERE fixture_id=? AND player_id=?", (fixture_id,pid)).fetchone(), (0,))

                    # 검증 목록 밖 이벤트는 같은 배우여도 프로필을 자동으로 보충하지 않아요.
                    unknown = deepcopy(payload)
                    for event in unknown["events"]:
                        event["id"] += 100_000_000_000
                    client._get = Mock(return_value={"data": deepcopy(unknown)})
                    self.assertEqual(client.get_fixture_details(fixture_id), unknown)
                    self.assertEqual(client._get.call_count, 1)

    def test_jagiellonia_verified_actors_keep_missing_and_mixed_lineups_unfilled(self):
        sample = json.loads((Path(__file__).parent / "fixtures/sportmonks_2024_jagiellonia_verified_actors.json").read_text(encoding="utf-8"))
        verified_ids = {int(key) for key in sample["profiles"]}
        for case in sample["cases"]:
            payload, expected = case["fixture"], case["expected"]
            fixture_id = payload["id"]
            with self.subTest(fixture_id=fixture_id):
                self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
                self.connection.executemany("INSERT OR IGNORE INTO teams VALUES (?)", {
                    (event["participant_id"],) for event in payload["events"]
                })
                self.connection.executemany("INSERT OR IGNORE INTO positions VALUES (?)", {
                    (profile["detailed_position_id"],) for profile in sample["profiles"].values()
                })
                existing_ids = {pid for event in payload["events"] for pid in
                                (event["player_id"], event["related_player_id"]) if pid is not None} - verified_ids
                self.connection.executemany("INSERT OR IGNORE INTO players(player_id) VALUES (?)", [(pid,) for pid in existing_ids])
                self.connection.commit()
                keys = ("event_types", "events", "lineups", "player_stats")
                raw_rows = _normalize_fixture_details(payload, fixture_id)
                if fixture_id != 19194448:
                    # 원문은 실제 교체 선수의 FK가 없어 저장 전체가 취소돼요.
                    with self.assertRaisesRegex(sqlite3.IntegrityError, "FOREIGN KEY constraint failed"):
                        details.replace_fixture_detail_rows(fixture_id, {key: raw_rows[key] for key in keys}, payload["lineups"])
                    self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_events WHERE fixture_id=?", (fixture_id,)).fetchone(), (0,))

                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(side_effect=lambda path, **kwargs: {
                    "data": deepcopy(payload) if path.startswith("fixtures/") else deepcopy(sample["profiles"][path.split("/")[1]])
                })
                corrected = client.get_fixture_details(fixture_id)
                # 검증한 두 명단 연결·서른 교체·두 이벤트 프로필 외 전체 원문 값도 비교해요.
                self.assertEqual(corrected, expected)
                rows = _normalize_fixture_details(corrected, fixture_id)
                event_profiles = details.verified_event_player_profiles(corrected)
                details.replace_fixture_detail_rows(fixture_id, {key: rows[key] for key in keys}, corrected["lineups"], event_profiles)
                self.assertEqual(self.connection.execute(
                    "SELECT event_id,fixture_id,team_id,event_type_id,player_id,related_player_id,minute,extra_minute,on_bench "
                    "FROM fixture_events WHERE fixture_id=? ORDER BY event_id", (fixture_id,),
                ).fetchall(), sorted(rows["events"]))
                expected_lineups = {19135801: [(37460555, 77, 5)], 19135802: [(37629806, 36, 18)], 19194448: []}
                self.assertEqual(self.connection.execute(
                    "SELECT player_id,jersey_number,minutes_played FROM fixture_lineups WHERE fixture_id=?", (fixture_id,),
                ).fetchall(), expected_lineups[fixture_id])
                # Marczuk은 실제 슬롯이 없어요. 상대 팀 7번을 고치거나 통계를 만들지 않아요.
                self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_player_stats WHERE fixture_id=? AND player_id=37531515", (fixture_id,)).fetchone(), (0,))
                self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_player_stats WHERE fixture_id=?", (fixture_id,)).fetchone(), (len(rows["player_stats"]),))
                if event_profiles:
                    unknown = deepcopy(payload)
                    unknown["lineups"] = []
                    unknown["events"] = [{**next(e for e in payload["events"] if e["id"] in (117214871, 118164492)), "id": 999}]
                    client._get = Mock(return_value={"data": deepcopy(unknown)})
                    self.assertEqual(client.get_fixture_details(fixture_id), unknown)
                    self.assertEqual(client._get.call_count, 1)

    def test_real_event_player_error_stores_verified_relation_and_preserves_event(self):
        sample = json.loads(
            (Path(__file__).parent / "fixtures/sportmonks_event_related_player_error.json").read_text(encoding="utf-8")
        )
        payload = sample["fixture"]
        self.connection.executescript("""
            INSERT INTO fixtures VALUES (10420711);
            INSERT INTO teams VALUES (231), (528);
            INSERT INTO positions VALUES (24);
        """)
        # 실제 응답의 FK 실패와 선수 삽입 롤백을 먼저 재현해요.
        with self.assertRaises(sqlite3.IntegrityError):
            details.replace_fixture_detail_rows(
                10420711, _normalize_fixture_details(payload, 10420711), payload["lineups"],
            )
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM players").fetchone(), (0,))

        client = SportmonksClient.__new__(SportmonksClient)
        client._get = Mock(return_value={"data": payload})
        corrected = client.get_fixture_details(10420711)
        rows = _normalize_fixture_details(corrected, 10420711)
        self.assertEqual(details.replace_fixture_detail_rows(10420711, rows, corrected["lineups"]), 2)
        self.assertEqual(details.replace_fixture_detail_rows(10420711, rows, corrected["lineups"]), 0)
        self.assertEqual(self.connection.execute(
            "SELECT event_id,event_type_id,player_id,related_player_id,minute FROM fixture_events"
        ).fetchall(), [(32722265, 15, 186591, 185640, 89)])
        self.assertEqual(self.connection.execute(
            "SELECT player_id FROM players ORDER BY player_id"
        ).fetchall(), [(185640,), (186591,)])

    def test_actor_corrections_preserve_lineup_player_transaction(self):
        samples = [
            json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
            for filename in (
                "sportmonks_2026_ki_event_actor_errors.json",
                "sportmonks_2026_sutjeska_event_actor_errors.json",
                "sportmonks_2026_qualifying_event_actor_errors.json",
            )
        ]
        cases = [case for sample in samples for case in sample["cases"]]
        self.connection.executemany("INSERT INTO teams VALUES (?)", sorted({
            (lineup["team_id"],) for case in cases for lineup in case["fixture"]["lineups"]
        } | {
            (event["participant_id"],) for case in cases for event in case["fixture"]["events"]
        } | {
            # 잘못 붙은 이벤트 팀을 감독 소속으로 바로잡는 표본에도 두 팀이 필요해요.
            (coach["meta"]["participant_id"],) for case in cases for coach in case["fixture"]["coaches"]
        }))
        position_ids = {
            lineup["player"]["detailed_position_id"]
            for case in cases for lineup in case["fixture"]["lineups"]
            if lineup["player"]["detailed_position_id"] is not None
        }
        self.connection.executemany(
            "INSERT OR IGNORE INTO positions VALUES (?)", [(p,) for p in position_ids],
        )
        expected_player_ids = set()
        for case in cases:
            payload = case["fixture"]
            fixture_id = payload["id"]
            expected_player_ids.update(lineup["player_id"] for lineup in payload["lineups"])
            with self.subTest(fixture_id=fixture_id):
                self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
                self.connection.commit()
                before_players = self.connection.execute("SELECT * FROM players ORDER BY player_id").fetchall()
                # 이벤트 선수 FK 실패로 직전에 추가한 라인업 선수도 함께 취소돼야 해요.
                with self.assertRaisesRegex(sqlite3.IntegrityError, "FOREIGN KEY constraint failed"):
                    details.replace_fixture_detail_rows(
                        fixture_id, _normalize_fixture_details(payload, fixture_id), payload["lineups"],
                    )
                self.assertEqual(self.connection.execute("SELECT * FROM players ORDER BY player_id").fetchall(), before_players)
                self.assertEqual(self.connection.execute(
                    "SELECT COUNT(*) FROM fixture_events WHERE fixture_id=?", (fixture_id,),
                ).fetchone(), (0,))

                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(return_value={"data": deepcopy(payload)})
                corrected = client.get_fixture_details(fixture_id)
                rows = _normalize_fixture_details(corrected, fixture_id)
                self.assertEqual(
                    details.replace_fixture_detail_rows(fixture_id, rows, corrected["lineups"]),
                    len(expected_player_ids) - len(before_players),
                )
                self.assertEqual(details.replace_fixture_detail_rows(fixture_id, rows, corrected["lineups"]), 0)
                self.assertEqual(self.connection.execute(
                    "SELECT event_id,player_id,related_player_id,minute FROM fixture_events WHERE fixture_id=? ORDER BY event_id",
                    (fixture_id,),
                ).fetchall(), sorted(
                    (e["id"], e["player_id"], e["related_player_id"], e["minute"])
                    for e in case["expected_events"]
                ))
                self.assertEqual(self.connection.execute(
                    "SELECT player_id FROM players ORDER BY player_id",
                ).fetchall(), [(player_id,) for player_id in sorted(expected_player_ids)])

    def test_real_negative_event_minutes_store_verified_events(self):
        cases = (
            ("sportmonks_event_minute_error.json", [(67686961, 28, None), (84175108, 90, 6)]),
            ("sportmonks_sampaoli_event_minute_error.json", [(80254118, 59, None), (83630899, 59, None)]),
            ("sportmonks_salernitana_duplicate_cards.json", [(78866603, 69, None), (78866604, 69, None)]),
            ("sportmonks_duplicate_cards.json", [
                (29990775, 19, None), (29992706, 56, None), (29993074, 65, None),
                (29993092, 66, None), (29993099, 66, None), (29993165, 69, None),
                (29993325, 75, None), (29993551, 82, None), (67695281, 50, None),
                (78696510, 85, None), (78696518, 48, None),
            ]),
        )
        for filename, expected in cases:
            with self.subTest(filename=filename):
                sample = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
                payload = sample["fixture"]
                fixture_id = payload["id"]
                self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
                self.connection.executemany("INSERT INTO teams VALUES (?)", [
                    (team_id,) for team_id in {e["participant_id"] for e in payload["events"]}
                ])
                player_ids = {
                    e[key] for e in payload["events"] for key in ("player_id", "related_player_id")
                    if e[key] is not None
                }
                self.connection.executemany("INSERT INTO players (player_id) VALUES (?)", [(p,) for p in player_ids])
                self.connection.commit()
                with self.assertRaises(sqlite3.IntegrityError):
                    details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id))
                self.assertEqual(self.connection.execute(
                    "SELECT COUNT(*) FROM fixture_events WHERE fixture_id=?", (fixture_id,),
                ).fetchone(), (0,))

                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(return_value={"data": deepcopy(payload)})
                corrected = client.get_fixture_details(fixture_id)
                rows = _normalize_fixture_details(corrected, fixture_id)
                details.replace_fixture_detail_rows(fixture_id, rows)
                details.replace_fixture_detail_rows(fixture_id, rows)
                self.assertEqual(self.connection.execute(
                    "SELECT event_id,minute,extra_minute FROM fixture_events WHERE fixture_id=? ORDER BY event_id",
                    (fixture_id,),
                ).fetchall(), expected)

    def test_coach_event_does_not_create_an_unrelated_player(self):
        cases = (
            ("sportmonks_coach_event_player_error.json", [(82392114, 20, None, 59, 1)]),
            ("sportmonks_basaksehir_coach_error.json", [(156508153, 20, None, 79, 0)]),
            ("sportmonks_tns_coach_error.json", [(156508154, 19, None, 43, 0)]),
            ("sportmonks_duplicate_coach_cards.json", [(120554621, 20, None, 84, 0), (120573201, 20, None, 84, 0)]),
        )
        for filename, expected in cases:
            with self.subTest(filename=filename):
                sample = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
                payload = sample["fixture"]
                fixture_id = payload["id"]
                self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
                self.connection.executemany("INSERT INTO teams VALUES (?)", {
                    (event["participant_id"],) for event in payload["events"]
                })
                self.connection.commit()
                with self.assertRaisesRegex(sqlite3.IntegrityError, "FOREIGN KEY constraint failed"):
                    details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id))
                self.assertEqual(self.connection.execute(
                    "SELECT COUNT(*) FROM fixture_events WHERE fixture_id=?", (fixture_id,),
                ).fetchone(), (0,))

                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(return_value={"data": deepcopy(payload)})
                corrected = client.get_fixture_details(fixture_id)
                rows = _normalize_fixture_details(corrected, fixture_id)
                details.replace_fixture_detail_rows(fixture_id, rows)
                details.replace_fixture_detail_rows(fixture_id, rows)
                self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM players").fetchone(), (0,))
                self.assertEqual(self.connection.execute(
                    "SELECT event_id,event_type_id,player_id,minute,on_bench FROM fixture_events WHERE fixture_id=? ORDER BY event_id",
                    (fixture_id,),
                ).fetchall(), expected)

    def test_real_null_stat_clears_previous_value_and_keeps_measured_zeroes(self):
        sample = json.loads(
            (Path(__file__).parent / "fixtures/sportmonks_null_fixture_stat.json").read_text(encoding="utf-8")
        )
        payload = sample["fixture"]
        self.connection.executescript("""
            INSERT INTO fixtures VALUES (16924696);
            INSERT INTO teams VALUES (65), (78);
        """)
        # 값이 사라진 통계를 다시 수집해도 이전 수치가 남지 않아야 해요.
        previous = deepcopy(payload)
        for stat in previous["statistics"]:
            if stat["id"] == 4206617:
                stat["data"]["value"] = 52
        details.replace_fixture_detail_rows(
            16924696, details.normalize_fixture_statistics(previous, 16924696),
        )
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM fixture_team_stats").fetchone(), (70,))

        rows = details.normalize_fixture_statistics(payload, 16924696)
        details.replace_fixture_detail_rows(16924696, rows)
        actual = self.connection.execute(
            "SELECT team_id,stat_type_id,stat_value FROM fixture_team_stats ORDER BY team_id,stat_type_id"
        ).fetchall()
        self.assertEqual(len(actual), 69)
        self.assertEqual(sum(value == 0 for _, _, value in actual), 4)
        self.assertNotIn((65, 45), [(team_id, stat_id) for team_id, stat_id, _ in actual])
        self.assertIn((78, 45, 48), actual)
        self.assertEqual(self.connection.execute(
            "SELECT code FROM fixture_stat_types WHERE stat_type_id=45"
        ).fetchone(), ("ball-possession",))
        details.replace_fixture_detail_rows(16924696, rows)
        self.assertEqual(self.connection.execute(
            "SELECT team_id,stat_type_id,stat_value FROM fixture_team_stats ORDER BY team_id,stat_type_id"
        ).fetchall(), actual)

    def test_actor_errors_roll_back_then_store_verified_cards_and_substitution(self):
        samples = [
            json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
            for filename in (
                "sportmonks_2024_event_actor_errors.json",
                "sportmonks_2025_event_actor_errors.json",
                "sportmonks_2026_event_actor_errors.json",
                "sportmonks_2026_ki_event_actor_errors.json",
                "sportmonks_2026_sutjeska_event_actor_errors.json",
                "sportmonks_2026_qualifying_event_actor_errors.json",
                "sportmonks_2024_european_six_event_errors.json",
                "sportmonks_2024_sliema_own_goal_error.json",
                "sportmonks_2025_five_coach_duplicate_errors.json",
                "sportmonks_2025_three_coach_duplicate_errors.json",
                "sportmonks_2025_roma_fiorentina_brighton_event_errors.json",
                "sportmonks_2025_arteta_duplicate_error.json",
                "sportmonks_2025_yuri_duplicate_error.json",
                "sportmonks_2025_weiss_two_cards.json",
                "sportmonks_2025_newcastle_coach_duplicate.json",
                "sportmonks_2025_pafos_card_errors.json",
                "sportmonks_2023_weiss_var_error.json",
                "sportmonks_2018_completion_events.json",
                "sportmonks_2019_completion_events.json",
                "sportmonks_2019-semantic_completion_events.json",
                "sportmonks_2020_completion_events.json", "sportmonks_2021_completion_events.json", "sportmonks_2022_completion_events.json", "sportmonks_2023_completion_events.json", "sportmonks_2024_completion_events.json", "sportmonks_2025_completion_events.json", "sportmonks_2025-semantic_completion_events.json", "sportmonks_2017_completion_events.json",
            )
        ]
        sample = {
            "cases": [case for source in samples for case in source["cases"]],
            "known_player_ids": sorted({p for source in samples for p in source["known_player_ids"]}),
        }
        teams = {
            event["participant_id"]
            for case in sample["cases"] for event in case["fixture"]["events"]
        } | {
            event["participant_id"]
            for case in sample["cases"] for event in case["expected_events"]
        } | {
            coach["meta"]["participant_id"]
            for case in sample["cases"] for coach in case["fixture"]["coaches"]
        }
        # 공통 초기 자료에 이미 있는 Newcastle(20) 등은 다시 넣지 않아요.
        existing_teams = {row[0] for row in self.connection.execute("SELECT team_id FROM teams")}
        self.connection.executemany("INSERT INTO teams VALUES (?)", [(team,) for team in teams - existing_teams])
        self.connection.executemany("INSERT INTO players (player_id) VALUES (?)", [(p,) for p in sample["known_player_ids"]])
        self.connection.commit()
        for case in sample["cases"]:
            payload = case["fixture"]
            fixture_id = payload["id"]
            with self.subTest(fixture_id=fixture_id):
                self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
                self.connection.commit()
                # 배우 오류는 FK에서 막히고, 시간만 틀린 기록은 저장된 원값도 교체해야 해요.
                if case.get("raw_actor_error", True):
                    with self.assertRaisesRegex(sqlite3.IntegrityError, "FOREIGN KEY constraint failed"):
                        details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id))
                    self.assertEqual(self.connection.execute(
                        "SELECT COUNT(*) FROM fixture_events WHERE fixture_id=?", (fixture_id,),
                    ).fetchone(), (0,))
                else:
                    details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id))

                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(return_value={"data": deepcopy(payload)})
                corrected = client.get_fixture_details(fixture_id)
                rows = _normalize_fixture_details(corrected, fixture_id)
                expected = sorted(
                    (e["id"], e["participant_id"], e["type_id"], e["player_id"], e["related_player_id"], e["minute"], e["extra_minute"], int(e["on_bench"]))
                    for e in case["expected_events"]
                )
                for _ in range(2):
                    details.replace_fixture_detail_rows(fixture_id, rows)
                    self.assertEqual(self.connection.execute(
                        "SELECT event_id,team_id,event_type_id,player_id,related_player_id,minute,extra_minute,on_bench FROM fixture_events WHERE fixture_id=? ORDER BY event_id",
                        (fixture_id,),
                    ).fetchall(), expected)
        # 감독이나 무관한 선수를 추가해서 FK 오류를 숨기지 않았는지 확인해요.
        self.assertEqual(self.connection.execute("SELECT player_id FROM players ORDER BY player_id").fetchall(), [(p,) for p in sample["known_player_ids"]])


if __name__ == "__main__":
    unittest.main()
