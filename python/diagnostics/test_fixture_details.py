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
            [(500, 10, 100, 11, "2:4", 2, 90, 7.38)],
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
        self.assertEqual(row[6:], (None, None))

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
        get_fixture.return_value = {"fixture_id": 500}
        fetch_all_dict.side_effect = [
            [{"event_id": 900}],
            [{"stat_type_id": 45}],
            [{"player_id": 100}],
            [{"team_id": 10, "formation": "4-3-3"}],
            [{"team_id": 10, "coach_id": 700}],
            [{"team_id": 10, "minute": 1, "pressure": 12.5}],
        ]

        with (
            patch.object(fixtures_repo, "get_fixture_expected_goals", return_value=None),
            patch.object(fixtures_repo, "list_fixture_player_expected_goals", return_value=[]),
            patch.object(fixtures_repo, "list_fixture_shots", return_value=[]),
        ):
            result = fixtures_repo.get_fixture_detail(500)

        self.assertEqual(result["events"], [{"event_id": 900}])
        self.assertEqual(result["statistics"], [{"stat_type_id": 45}])
        self.assertEqual(result["lineups"], [{"player_id": 100}])
        self.assertEqual(result["formations"][0]["formation"], "4-3-3")
        self.assertEqual(result["coaches"][0]["coach_id"], 700)
        self.assertEqual(result["pressure"][0]["minute"], 1)
        self.assertEqual(fetch_all_dict.call_count, 6)
        self.assertIsNone(result["expected_goals"])
        self.assertEqual(result["player_expected_goals"], [])
        self.assertEqual(result["shots"], [])

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
        self.connection.commit()
        self.mock_connection = patch.object(db, "get_conn", return_value=_SqliteConnection(self.connection))
        self.mock_connection.start()

    def tearDown(self):
        self.mock_connection.stop()
        self.connection.close()

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
            "sportmonks_lineup_null_player_id.json",
            "sportmonks_lineup_event_player_mismatch.json",
            "sportmonks_2026_strassen_actor_errors.json",
            "sportmonks_2026_conference_lineups.json",
        ):
            sample = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
            profiles = {p["id"]: p for p in sample["correct_players"]}
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
                    with self.assertRaisesRegex(sqlite3.IntegrityError, "FOREIGN KEY constraint failed"):
                        details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id), payload["lineups"])
                    self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM players").fetchone(), before_players)

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
        for filename in (
            "sportmonks_event_player_missing_lineup.json",
            "sportmonks_lisakovich_missing_lineup.json",
            "sportmonks_charles_cook_missing_lineup.json",
        ):
            sample = json.loads((Path(__file__).parent / "fixtures" / filename).read_text(encoding="utf-8"))
            payload = sample["fixture"]
            fixture_id = payload["id"]
            original_event = payload["events"][0]
            player_id = original_event["player_id"]
            profile = sample["profiles"][str(player_id)]
            with self.subTest(fixture_id=fixture_id):
                self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
                self.connection.execute("INSERT INTO teams VALUES (?)", (original_event["participant_id"],))
                self.connection.executemany("INSERT OR IGNORE INTO positions VALUES (?)", {
                    (p["detailed_position_id"],) for p in [profile, *(l["player"] for l in payload["lineups"])]
                })
                self.connection.commit()
                before_count = self.connection.execute("SELECT COUNT(*) FROM players").fetchone()
                client = SportmonksClient.__new__(SportmonksClient)
                client._get = Mock(side_effect=lambda path, **kwargs: {
                    "data": deepcopy(payload) if path.startswith("fixtures/") else deepcopy(sample["profiles"][path.split("/")[1]])
                })
                # 라인업에 없는 실제 교체 선수 때문에 저장 전체가 취소됐던 경로를 재현해요.
                with self.assertRaisesRegex(sqlite3.IntegrityError, "FOREIGN KEY constraint failed"):
                    details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id), payload["lineups"])
                self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM players").fetchone(), before_count)

                corrected = client.get_fixture_details(fixture_id)
                event = deepcopy(corrected["events"][0])
                self.assertEqual(event.pop("verified_player_profile"), profile)
                self.assertEqual(event, original_event)
                self.assertEqual(corrected["lineups"], payload["lineups"])
                self.assertEqual(client._get.call_count, 2)

                with patch.object(details, "_load_scope", return_value=[fixture_id]), patch.object(details, "SportmonksClient", return_value=client), patch("builtins.print"):
                    self.assertEqual(details.collect_fixture_details(fixture_id)["players"], 2)
                    self.connection.execute("UPDATE players SET display_name='기존 검증 이름' WHERE player_id=?", (player_id,))
                    self.connection.commit()
                    self.assertEqual(details.collect_fixture_details(fixture_id)["players"], 0)
                self.assertEqual(self.connection.execute(
                    "SELECT player_id,related_player_id,minute FROM fixture_events WHERE fixture_id=?", (fixture_id,),
                ).fetchall(), [(player_id, original_event["related_player_id"], original_event["minute"])])
                self.assertEqual(self.connection.execute(
                    "SELECT player_id FROM fixture_lineups WHERE fixture_id=?", (fixture_id,),
                ).fetchall(), [(original_event["related_player_id"],)])
                self.assertEqual(self.connection.execute(
                    "SELECT display_name,date_of_birth FROM players WHERE player_id=?", (player_id,),
                ).fetchone(), ("기존 검증 이름", profile["date_of_birth"]))

                # 검증 목록 밖 이벤트는 같은 선수 ID여도 프로필을 가져오거나 자동 저장하지 않아요.
                payload["events"][0]["id"] = 999
                client._get.reset_mock()
                unverified = client.get_fixture_details(fixture_id)
                self.assertNotIn("verified_player_profile", unverified["events"][0])
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
            coach["meta"]["participant_id"]
            for case in sample["cases"] for coach in case["fixture"]["coaches"]
        }
        self.connection.executemany("INSERT INTO teams VALUES (?)", [(team,) for team in teams])
        self.connection.executemany("INSERT INTO players (player_id) VALUES (?)", [(p,) for p in sample["known_player_ids"]])
        self.connection.commit()
        for case in sample["cases"]:
            payload = case["fixture"]
            fixture_id = payload["id"]
            with self.subTest(fixture_id=fixture_id):
                self.connection.execute("INSERT INTO fixtures VALUES (?)", (fixture_id,))
                self.connection.commit()
                # 실제 선수만 등록하면 모든 원문 표본의 잘못된 FK에서 실패해야 해요.
                with self.assertRaisesRegex(sqlite3.IntegrityError, "FOREIGN KEY constraint failed"):
                    details.replace_fixture_detail_rows(fixture_id, _normalize_fixture_details(payload, fixture_id))
                self.assertEqual(self.connection.execute(
                    "SELECT COUNT(*) FROM fixture_events WHERE fixture_id=?", (fixture_id,),
                ).fetchone(), (0,))

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
