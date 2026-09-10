from __future__ import annotations

import json
import re
import sqlite3
import unittest
from copy import deepcopy
from decimal import Decimal
from pathlib import Path
from unittest.mock import Mock, patch

from one_touch_loader.core import db
from one_touch_loader.core.identity import normalize_identity_text
from one_touch_loader.core.understat import UnderstatClient, season_start_year
from one_touch_loader.loaders import understat_ids_loader as ids
from one_touch_loader.loaders import understat_loader as loader
from one_touch_loader.loaders import understat_common as common
from one_touch_loader.loaders import xg_standings_loader as standings
from one_touch_loader.api.repos import expected_goals_repo as repo


SAMPLE = json.loads((Path(__file__).parent / "fixtures/understat_match_27270.json").read_text(encoding="utf-8"))


def sample_rows():
    # 파서·저장 테스트용 ID예요. 실제 공급자 매핑이라고 가정하지 않아요.
    players = {str(p["player_id"]): int(p["player_id"]) + 1000000
               for roster in SAMPLE["details"]["rosters"].values() for p in roster.values()}
    rows = loader.normalize_understat_match(SAMPLE["match"], SAMPLE["details"], 1,
                                            {"148": 10, "223": 20}, players)
    return rows, players


class ProviderTests(unittest.TestCase):
    def test_actual_match_preserves_own_goal_and_supplied_player_zero(self):
        rows, players = sample_rows()
        self.assertEqual(rows["expected_goals"], (1, Decimal("2.75333"), Decimal("0.490847")))
        self.assertEqual(len(rows["shots"]), 26)
        self.assertEqual(len(rows["player_expected_goals"]), 31)
        own_goal, = [s for s in rows["shots"] if s[-1] == "OwnGoal"]
        self.assertEqual(own_goal[0], 624665)
        self.assertEqual(own_goal[2], 20)
        self.assertEqual(own_goal[5], Decimal("0.05"))
        xg = {r[1]: r[2] for r in rows["player_expected_goals"]}
        self.assertEqual(xg[players["6942"]], Decimal("0"))
        self.assertNotIn(999, xg)

    def test_roster_player_id_is_not_roster_row_id(self):
        rows, players = sample_rows()
        self.assertIn((1, players["9805"], Decimal("0.10230077803134918")), rows["player_expected_goals"])
        self.assertNotIn(715447, players.values())

    def test_repeated_player_row_is_rejected_before_storage_even_if_xg_is_equal(self):
        _, players = sample_rows()
        details = deepcopy(SAMPLE["details"])
        player = next(iter(details["rosters"]["h"].values()))
        details["rosters"]["h"]["duplicate"] = {**player, "id": "different_roster_id"}
        with self.assertRaisesRegex(ValueError, "repeats player_id"):
            loader.normalize_understat_match(SAMPLE["match"], details, 1,
                                              {"148": 10, "223": 20}, players)

    def test_missing_value_or_mapping_is_never_replaced_with_zero(self):
        _, players = sample_rows()
        details = deepcopy(SAMPLE["details"])
        first = next(iter(details["rosters"]["h"].values()))
        del first["xG"]
        with self.assertRaises(KeyError):
            loader.normalize_understat_match(SAMPLE["match"], details, 1, {"148": 10, "223": 20}, players)
        del players["9805"]
        with self.assertRaises(KeyError):
            loader.normalize_understat_match(SAMPLE["match"], SAMPLE["details"], 1,
                                              {"148": 10, "223": 20}, players)

    @patch("one_touch_loader.core.understat.requests.Session")
    def test_shared_client_uses_observed_json_endpoints(self, session):
        session.return_value.headers = {}
        client = UnderstatClient()
        client.get_season(564, "2024/2025")
        client.get_match("27270")
        self.assertEqual([c.args[0] for c in session.return_value.get.call_args_list], [
            "https://understat.com/", "https://understat.com/getLeagueData/La_liga/2024",
            "https://understat.com/getMatchData/27270",
        ])
        self.assertEqual(session.return_value.headers["X-Requested-With"], "XMLHttpRequest")
        client.close()
        session.return_value.close.assert_called_once()

    def test_season_contract(self):
        self.assertEqual(season_start_year("2026/2027"), 2026)
        for invalid in ("26/27", "2024/2026", "2024"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                season_start_year(invalid)


class MappingTests(unittest.TestCase):
    def setUp(self):
        self.observations = [{"team_id": 10, "player_id": i + 1,
                              "display_name": name, "full_name": name}
                             for i, name in enumerate(("Alex One", "Ben Two", "Chris Three"))]
        self.source = {"teams": {"100": {"title": "Source Team"}}, "dates": [], "players": [
            {"id": str(i + 1000), "player_name": r["display_name"], "team_title": "Source Team"}
            for i, r in enumerate(self.observations)]}

    def test_reciprocal_team_identity_and_three_player_minimum(self):
        self.assertEqual(ids.plan_team_ids(self.source, self.observations, {})[0], {"100": 10})
        self.assertEqual(ids.plan_team_ids(self.source, self.observations[:2], {})[0], {})
        duplicate = [{**r, "team_id": 20} for r in self.observations]
        self.assertEqual(ids.plan_team_ids(self.source, self.observations + duplicate, {})[0], {})

    def test_exact_player_identity_decodes_entities_and_preserves_existing(self):
        self.source["players"][0]["player_name"] = "Al&#233;x One"
        found, pending = ids.plan_player_ids(self.source, self.observations, {"100": 10}, {"1001": 999})
        self.assertEqual(found, {"1000": 1, "1002": 3})
        self.assertEqual(pending, [])

    def test_similar_or_ambiguous_names_are_reported(self):
        self.source["players"][0]["player_name"] = "Alex Ones"
        duplicate = {**self.observations[1], "player_id": 5}
        found, pending = ids.plan_player_ids(self.source, self.observations + [duplicate], {"100": 10}, {})
        self.assertEqual(found, {"1002": 3})
        self.assertEqual(pending[1]["candidate_player_ids"], [2, 5])

    def test_verified_id_still_requires_observed_team_membership(self):
        self.source["players"] = [{"id": "9805", "player_name": "Álex Balde", "team_title": "Source Team"}]
        row = {"team_id": 10, "player_id": 37316480, "display_name": "Alejandro Balde", "full_name": None}
        self.assertEqual(ids.plan_player_ids(self.source, [row], {"100": 10}, {})[0], {"9805": 37316480})
        self.assertEqual(ids.plan_player_ids(self.source, [{**row, "team_id": 20}], {"100": 10}, {})[0], {})

    def test_transfer_player_uses_both_observed_teams(self):
        self.source["teams"]["200"] = {"title": "Second Team"}
        self.source["players"][0]["team_title"] = "Source Team,Second Team"
        found, _ = ids.plan_player_ids(self.source, [{**self.observations[0], "team_id": 20}],
                                      {"100": 10, "200": 20}, {})
        self.assertEqual(found, {"1000": 1})

    def test_rescheduled_fixture_uses_pair_and_duplicate_pair_uses_date(self):
        match = deepcopy(SAMPLE["match"])
        fixture = {"fixture_id": 1, "home_team_id": 10, "away_team_id": 20, "starting_at": "2025-04-01"}
        source = {"dates": [match]}
        self.assertEqual(ids.plan_fixture_ids(source, [fixture], {"148": 10, "223": 20}, {})[0], {"27270": 1})
        second = {**fixture, "fixture_id": 2, "starting_at": match["datetime"]}
        self.assertEqual(ids.plan_fixture_ids(source, [fixture, second], {"148": 10, "223": 20}, {})[0], {"27270": 2})
        second["starting_at"] = "2025-04-02"
        found, pending = ids.plan_fixture_ids(source, [fixture, second], {"148": 10, "223": 20}, {})
        self.assertEqual(found, {})
        self.assertEqual(len(pending), 1)

    def test_noncompleted_matches_are_not_mapped(self):
        match = {**SAMPLE["match"], "isResult": False}
        self.assertEqual(ids.plan_fixture_ids({"dates": [match]}, [], {}, {}), ({}, []))

    def test_duplicate_provider_identity_is_not_silently_overwritten(self):
        with self.assertRaisesRegex(ValueError, "unverified duplicates"):
            ids._validate_mapping_uniqueness("player", {"one": 1}, {"two": 1})

    def test_verified_player_aliases_preserve_both_ids_but_do_not_allow_new_ones(self):
        for player_id, aliases in ((37459033, ("11328", "11471")),
                                   (37590278, ("14378", "14432")),
                                   (37774860, ("13276", "13294")),
                                   (37721978, ("13265", "14296"))):
            existing, added = {aliases[0]: player_id}, {aliases[1]: player_id}
            with self.subTest(player_id=player_id):
                ids._validate_mapping_uniqueness("player", existing, added)
                with self.assertRaises(ValueError):
                    ids._validate_mapping_uniqueness("player", existing, {**added, "unverified": player_id})
                for entity in ("team", "fixture"):
                    with self.assertRaises(ValueError):
                        ids._validate_mapping_uniqueness(entity, existing, added)

    def test_turkish_spelling_is_normalized_without_short_name_matching(self):
        for source, db_name in (("Burak Yilmaz", "Burak Yılmaz"), ("Yusuf Yazici", "Yusuf Yazıcı"),
                                ("Semih Kiliçsoy", "Semih Kılıçsoy")):
            self.assertEqual(normalize_identity_text(source), normalize_identity_text(db_name))
        self.assertNotEqual(normalize_identity_text("B. Yılmaz"), normalize_identity_text("Burak Yılmaz"))

    def test_verified_historical_homonym_requires_same_team_observation(self):
        source = {"teams": {"100": {"title": "Leicester"}}, "players": [
            {"id": "473", "player_name": "Danny Ward", "team_title": "Leicester"}]}
        observations = [{"team_id": 10, "player_id": pid, "display_name": "Danny Ward", "full_name": "Danny Ward"}
                        for pid in (320, 3282)]
        found, pending = ids.plan_player_ids(source, observations, {"100": 10}, {})
        self.assertEqual((found, pending), ({"473": 3282}, []))
        found, pending = ids.plan_player_ids(source, observations[:1], {"100": 10}, {})
        self.assertEqual(found, {})
        self.assertEqual(len(pending), 1)

    def test_corrupt_match_and_future_match_are_outside_both_collection_scopes(self):
        source = {"dates": [SAMPLE["match"], {**SAMPLE["match"], "id": "31948"},
                             {**SAMPLE["match"], "id": "30804"},
                             {**SAMPLE["match"], "id": "future", "isResult": False}]}
        matches, unavailable = common.select_understat_matches(source)
        self.assertEqual(matches, [SAMPLE["match"]])
        self.assertEqual([m["external_fixture_id"] for m in unavailable], ["31948", "30804"])

    def test_historical_corrupt_matches_are_not_requested_for_player_mapping(self):
        source = {"teams": {}, "dates": [
            {**SAMPLE["match"], "id": sid} for sid in ("18116", "23028", "27930", "29482")
        ]}
        client = Mock()
        actual, unavailable = ids.load_mapping_source(client, source)
        client.get_match.assert_not_called()
        self.assertEqual(actual["dates"], [])
        self.assertEqual(actual["players"], [])
        self.assertEqual(len(unavailable), 4)

    def test_mapping_uses_valid_rosters_instead_of_contaminated_season_totals(self):
        source = {"teams": {"148": {"title": "Barcelona"}, "223": {"title": "Girona"}},
                  "dates": [SAMPLE["match"], {**SAMPLE["match"], "id": "31948"}],
                  "players": [{"id": "bad", "player_name": "Unrelated player", "team_title": "Barcelona"}]}
        client = Mock()
        client.get_match.return_value = SAMPLE["details"]
        actual, unavailable = ids.load_mapping_source(client, source)
        client.get_match.assert_called_once_with("27270")
        self.assertEqual(actual["dates"], [SAMPLE["match"]])
        self.assertEqual(len(actual["players"]), 31)
        self.assertNotIn("bad", {p["id"] for p in actual["players"]})
        self.assertEqual(next(p["team_title"] for p in actual["players"] if p["id"] == "6942"), "Girona")
        self.assertEqual(len(unavailable), 1)

    def test_roster_mapping_preserves_same_players_transfer_teams(self):
        match = SAMPLE["match"]
        source = {"teams": {"148": {"title": "Barcelona"}, "223": {"title": "Girona"}},
                  "dates": [match, {**match, "id": "second"}]}
        player = {"player_id": "123", "player": "Alex One"}
        client = Mock()
        client.get_match.side_effect = [{"rosters": {"h": {"row1": player}, "a": {}}},
                                        {"rosters": {"h": {}, "a": {"row2": player}}}]
        actual, _ = ids.load_mapping_source(client, source)
        self.assertEqual(actual["players"], [
            {"id": "123", "player_name": "Alex One", "team_title": "Barcelona,Girona"}])


class Cursor:
    def __init__(self, connection):
        self.cursor = connection.cursor()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.cursor.close()

    def execute(self, sql, args=()):
        return self.cursor.execute(sql.replace("%s", "?"), args)

    def executemany(self, sql, rows):
        return self.cursor.executemany(sql.replace("%s", "?"), rows)


class Connection:
    def __init__(self, connection):
        self.connection = connection

    def cursor(self):
        return Cursor(self.connection)

    def commit(self):
        self.connection.commit()

    def rollback(self):
        self.connection.rollback()

    def close(self):
        pass


class StorageTests(unittest.TestCase):
    def setUp(self):
        sqlite3.register_adapter(Decimal, str)
        self.conn = sqlite3.connect(":memory:")
        self.addCleanup(self.conn.close)
        self.conn.execute("PRAGMA foreign_keys=ON")
        self.conn.executescript("""
            CREATE TABLE seasons(season_id INTEGER PRIMARY KEY, competition_id INTEGER, name TEXT);
            CREATE TABLE stages(stage_id INTEGER PRIMARY KEY, season_id INTEGER REFERENCES seasons);
            CREATE TABLE teams(team_id INTEGER PRIMARY KEY, name TEXT, image_path TEXT);
            CREATE TABLE players(player_id INTEGER PRIMARY KEY, display_name TEXT);
            CREATE TABLE fixtures(fixture_id INTEGER PRIMARY KEY, stage_id INTEGER REFERENCES stages,
              home_team_id INTEGER, away_team_id INTEGER, home_score INTEGER, away_score INTEGER,
              state_id INTEGER, starting_at TEXT);
            INSERT INTO seasons VALUES(100,564,'2024/2025');
            INSERT INTO stages VALUES(1000,100);
            INSERT INTO teams VALUES(10,'Home',NULL),(20,'Away',NULL);
            INSERT INTO fixtures VALUES(1,1000,10,20,4,1,5,'2025-03-30'),(2,1000,10,20,0,0,5,'2025-03-31');
        """)
        # 같은 DDL의 테이블·FK·PK를 SQLite에서도 실행해요. MySQL 전용 문법만 바꿔요.
        sql = (Path(__file__).parents[1] / "one_touch_loader/sql/migrate_understat_minimal.sql").read_text(encoding="utf-8")
        sql = re.sub(r"--[^\n]*", "", sql)
        sql = re.sub(r"DROP TABLE \w+;", "", sql)
        sql = re.sub(r"\) ENGINE=InnoDB[^;]*;", ");", sql)
        sql = re.sub(r"COLLATE utf8mb4_bin", "", sql)
        sql = re.sub(r"UNIQUE KEY \w+", "UNIQUE", sql)
        sql = re.sub(r"\s*KEY \w+ \([^)]*\),", "", sql)
        self.conn.executescript(sql)
        self.rows, players = sample_rows()
        self.conn.executemany("INSERT INTO players VALUES (?,?)", [(p, f"Player {p}") for p in players.values()])
        self.conn.commit()
        self.connection_patch = patch.object(db, "get_conn", return_value=Connection(self.conn))
        self.connection_patch.start()
        self.addCleanup(self.connection_patch.stop)

    def all_dict(self, sql, args=()):
        cursor = self.conn.execute(sql.replace("%s", "?"), args)
        keys = [c[0] for c in cursor.description]
        return [dict(zip(keys, row)) for row in cursor.fetchall()]

    def one_dict(self, sql, args=()):
        rows = self.all_dict(sql, args)
        return rows[0] if rows else None

    def test_refresh_is_idempotent_and_failure_restores_all_three_tables(self):
        loader.replace_understat_rows([self.rows])
        loader.replace_understat_rows([self.rows])
        self.assertEqual(self.conn.execute("SELECT count(*) FROM fixture_shots").fetchone()[0], 26)
        broken = deepcopy(self.rows)
        broken["expected_goals"] = (1, 999, 999)
        broken["shots"][0] = (*broken["shots"][0][:3], 999999999, *broken["shots"][0][4:])
        with self.assertRaises(sqlite3.IntegrityError):
            loader.replace_understat_rows([broken])
        self.assertEqual(self.conn.execute("SELECT home_xg FROM fixture_expected_goals").fetchone()[0], 2.75333)
        self.assertEqual(self.conn.execute("SELECT count(*) FROM fixture_player_expected_goals").fetchone()[0], 31)
        self.assertEqual(self.conn.execute("SELECT count(*) FROM fixture_shots").fetchone()[0], 26)

    def test_batch_failure_restores_every_fixture_and_single_refresh_preserves_other_fixture(self):
        second = deepcopy(self.rows)
        second["expected_goals"] = (2, *second["expected_goals"][1:])
        second["player_expected_goals"] = [(2, *r[1:]) for r in second["player_expected_goals"]]
        second["shots"] = [(r[0] + 1000000, 2, *r[2:]) for r in second["shots"]]
        loader.replace_understat_rows([self.rows, second])
        loader.replace_understat_rows([self.rows, second])
        before = {table: self.conn.execute(f"SELECT * FROM {table} ORDER BY 1,2").fetchall()
                  for table in ("fixture_expected_goals", "fixture_player_expected_goals", "fixture_shots")}
        changed, broken = deepcopy(self.rows), deepcopy(second)
        changed["expected_goals"] = (1, 999, 999)
        broken["shots"][0] = (*broken["shots"][0][:3], 999999999, *broken["shots"][0][4:])
        with self.assertRaises(sqlite3.IntegrityError):
            loader.replace_understat_rows([changed, broken])
        for table, rows in before.items():
            self.assertEqual(self.conn.execute(f"SELECT * FROM {table} ORDER BY 1,2").fetchall(), rows)
        loader.replace_understat_rows([self.rows])
        for table, rows in before.items():
            self.assertEqual(self.conn.execute(f"SELECT * FROM {table} ORDER BY 1,2").fetchall(), rows)

    def test_fixture_external_ids_keep_the_one_to_one_contract(self):
        self.conn.execute("INSERT INTO fixture_external_ids VALUES (1,'understat','27270')")
        for row in [(2, "understat", "27270"), (1, "understat", "different")]:
            with self.subTest(row=row), self.assertRaises(sqlite3.IntegrityError):
                self.conn.execute("INSERT INTO fixture_external_ids VALUES (?,?,?)", row)

    def test_player_alias_migration_preserves_data_and_external_id_ownership(self):
        self.conn.executescript("""
            CREATE TABLE player_external_ids(
                player_id INTEGER REFERENCES players(player_id), provider TEXT, external_player_id TEXT,
                PRIMARY KEY(provider,external_player_id));
            CREATE UNIQUE INDEX uq_player_external_provider ON player_external_ids(player_id,provider);
            INSERT INTO players VALUES(37459033,'Ángel Alarcón');
            INSERT INTO player_external_ids VALUES(37459033,'understat','11328');
            INSERT INTO player_external_ids VALUES(37459033,'capology','angel-alarcon-test');
        """)
        before = self.conn.execute("SELECT * FROM player_external_ids ORDER BY provider").fetchall()
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("INSERT INTO player_external_ids VALUES(37459033,'understat','11471')")
        sql = (Path(__file__).parents[1] / "one_touch_loader/sql/migrate_player_external_ids_aliases.sql").read_text(encoding="utf-8")
        # 같은 인덱스 변경을 SQLite의 분리된 CREATE/DROP 문법으로 검사해요.
        sql = re.sub(r"--[^\n]*", "", sql)
        sql = re.sub(r"ALTER TABLE player_external_ids\s+ADD INDEX", "CREATE INDEX", sql)
        sql = sql.replace("idx_player_external_player_provider (", "idx_player_external_player_provider ON player_external_ids (")
        sql = re.sub(r",\s+DROP INDEX", "; DROP INDEX", sql)
        self.conn.executescript(sql)
        self.assertEqual(self.conn.execute("SELECT * FROM player_external_ids ORDER BY provider").fetchall(), before)
        self.conn.execute("INSERT INTO player_external_ids VALUES(37459033,'understat','11471')")
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("INSERT INTO player_external_ids VALUES(1006942,'understat','11471')")
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("INSERT INTO player_external_ids VALUES(999999,'understat','missing-player')")

    def test_api_preserves_missing_and_provided_zero_and_derives_xga(self):
        loader.replace_understat_rows([self.rows])
        with patch.object(repo, "fetch_one_dict", self.one_dict), patch.object(repo, "fetch_all_dict", self.all_dict):
            self.assertIsNone(repo.get_fixture_expected_goals(2))
            result = repo.get_fixture_expected_goals(1)
            self.assertEqual(result["home_xga"], result["away_xg"])
            self.assertEqual(result["away_xga"], result["home_xg"])
            self.assertEqual(len(repo.list_fixture_shots(1)), 26)
            xg = {r["player_id"]: r["xg"] for r in repo.list_fixture_player_expected_goals(1)}
            self.assertEqual(xg[1006942], 0)

    def test_calibration_query_only_uses_results_with_xg(self):
        loader.replace_understat_rows([self.rows])
        with patch.object(standings, "fetch_all", lambda sql, args: self.conn.execute(sql.replace("%s", "?"), args).fetchall()):
            matches = standings.load_xg_matches([100])
        self.assertEqual([m["fixture_id"] for m in matches], [1])
        calibration = standings.calculate_calibration(matches)
        self.assertEqual(calibration["target_draw_rate"], Decimal(0))

    def test_standings_storage_replaces_season_atomically_and_api_filters_competition(self):
        matches = [{"home_team_id": 10, "away_team_id": 20, "home_xg": 2, "away_xg": 1}]
        rows = standings.aggregate_xg_standings(matches, Decimal("0.3"))
        calibration = {"calibration_match_count": 1900, "target_draw_rate": Decimal("0.25"), "draw_band": Decimal("0.3")}
        standings._save_standings(100, calibration, rows)
        standings._save_standings(100, calibration, rows)
        with patch.object(repo, "fetch_all_dict", self.all_dict):
            self.assertEqual([r["xpts"] for r in repo.list_xg_standings(564, 100)], [3, 0])
            self.assertEqual(repo.list_xg_standings(8, 100), [])
        rows[0]["team_id"] = 999
        with self.assertRaises(sqlite3.IntegrityError):
            standings._save_standings(100, calibration, rows)
        self.assertEqual(self.conn.execute("SELECT count(*) FROM xg_standings").fetchone()[0], 2)


class StandingsAlgorithmTests(unittest.TestCase):
    def test_draw_band_is_closed_on_both_sides_after_three_digit_rounding(self):
        match = {"home_team_id": 10, "away_team_id": 20, "home_xg": "1.30049", "away_xg": "1"}
        rows = standings.aggregate_xg_standings([match], Decimal("0.300"))
        self.assertEqual([r["xpts"] for r in rows], [1, 1])
        match["home_xg"] = "1.30050"
        self.assertEqual([r["xpts"] for r in standings.aggregate_xg_standings([match], Decimal("0.300"))], [3, 0])

    def test_calibration_uses_actual_draw_proportion_and_empirical_rank(self):
        matches = [{"home_score": 1, "away_score": a, "home_xg": h, "away_xg": "1"}
                   for a, h in [(1, "1.1"), (1, "1.2"), (0, "2"), (0, "2.5")]]
        self.assertEqual(standings.calculate_calibration(matches), {
            "calibration_match_count": 4, "target_draw_rate": Decimal("0.5"), "draw_band": Decimal("0.2")})

    def test_tied_teams_have_stable_id_order(self):
        rows = standings.aggregate_xg_standings([
            {"home_team_id": 20, "away_team_id": 10, "home_xg": "1", "away_xg": "1"}], Decimal("0.3"))
        self.assertEqual([r["team_id"] for r in rows], [10, 20])

    @patch.object(standings, "_save_standings")
    @patch.object(standings, "load_xg_matches", return_value=[])
    @patch.object(standings, "fetch_all", return_value=[])
    @patch.object(standings, "load_understat_scope", return_value=[{"season_id": 100, "competition_id": 8, "name": "2026/2027"}])
    def test_no_five_season_history_does_not_create_an_invented_score(self, scope, fetch, matches, save):
        result = standings.build_xg_standings()
        save.assert_not_called()
        self.assertEqual(result["unavailable"][0]["reason"], "five_previous_seasons_required")


class ExecutionTests(unittest.TestCase):
    def test_later_source_failure_does_not_write_a_partial_league(self):
        _, players = sample_rows()
        maps = {"fixture": {"27270": 1, "next": 2}, "team": {"148": 10, "223": 20}, "player": players}
        client = Mock()
        client.get_season.return_value = {"dates": [SAMPLE["match"], {**SAMPLE["match"], "id": "next"}]}
        client.get_match.side_effect = [SAMPLE["details"], RuntimeError("source interrupted")]
        with (patch.object(loader, "UnderstatClient", return_value=client),
              patch.object(loader, "load_understat_scope", return_value=[{"season_id": 100, "competition_id": 564, "name": "2024/2025"}]),
              patch.object(loader, "load_external_ids", side_effect=maps.__getitem__),
              patch.object(loader, "replace_understat_rows") as write):
            with self.assertRaisesRegex(RuntimeError, "source interrupted"):
                loader.collect_understat()
        write.assert_not_called()
        client.close.assert_called_once()

    def test_collection_check_uses_real_payload_without_writing(self):
        _, players = sample_rows()
        maps = {"fixture": {"27270": 1}, "team": {"148": 10, "223": 20}, "player": players}
        client = Mock()
        client.get_season.return_value = {"dates": [SAMPLE["match"]]}
        client.get_match.return_value = SAMPLE["details"]
        scope = [{"season_id": 100, "competition_id": 564, "name": "2024/2025"}]
        with (patch.object(loader, "UnderstatClient", return_value=client),
              patch.object(loader, "load_understat_scope", return_value=scope),
              patch.object(loader, "load_external_ids", side_effect=maps.__getitem__),
              patch.object(loader, "replace_understat_rows") as write):
            result = loader.collect_understat(check=True)
        self.assertEqual(result, {"fixtures": 1, "players": 31, "shots": 26, "unavailable": 0})
        write.assert_not_called()
        client.close.assert_called_once()

    def test_unmapped_player_reports_id_and_stops_before_writing(self):
        _, players = sample_rows()
        del players["9805"]
        maps = {"fixture": {"27270": 1}, "team": {"148": 10, "223": 20}, "player": players}
        client = Mock()
        client.get_season.return_value = {"dates": [SAMPLE["match"]]}
        client.get_match.return_value = SAMPLE["details"]
        with (patch.object(loader, "UnderstatClient", return_value=client),
              patch.object(loader, "load_understat_scope", return_value=[{"season_id": 100, "competition_id": 564, "name": "2024/2025"}]),
              patch.object(loader, "load_external_ids", side_effect=maps.__getitem__),
              patch.object(loader, "write_understat_report", return_value="report.json") as report,
              patch.object(loader, "replace_understat_rows") as write):
            with self.assertRaisesRegex(ValueError, "9805"):
                loader.collect_understat()
        write.assert_not_called()
        self.assertEqual(report.call_args.args[1]["missing"]["players"], ["9805"])

    def test_mapping_check_does_not_open_a_write_transaction(self):
        source = {"teams": {"148": {"title": "Barcelona"}, "223": {"title": "Girona"}},
                  "dates": [SAMPLE["match"]], "players": []}
        _, players = sample_rows()
        maps = {"team": {"148": 10, "223": 20}, "fixture": {}, "player": players}
        client = Mock()
        client.get_season.return_value = source
        client.get_match.return_value = SAMPLE["details"]
        scope = [{"season_id": 100, "competition_id": 564, "name": "2024/2025"}]
        fixtures = [{"fixture_id": 1, "home_team_id": 10, "away_team_id": 20, "starting_at": "2025-03-30"}]
        with (patch.object(ids, "UnderstatClient", return_value=client),
              patch.object(ids, "load_understat_scope", return_value=scope),
              patch.object(ids, "load_external_ids", side_effect=maps.__getitem__),
              patch.object(ids, "load_player_observations", return_value=[]),
              patch.object(ids, "load_mapping_fixtures", return_value=fixtures),
              patch.object(ids, "write_understat_report", return_value="report.json"),
              patch.object(ids, "transaction") as write):
            result = ids.collect_understat_ids(check=True)
        self.assertEqual(result, {"seasons": 1, "pending": 0, "unavailable": 0})
        write.assert_not_called()

    def test_unavailable_match_never_fetches_or_writes_values_even_with_mapping(self):
        client = Mock()
        client.get_season.return_value = {"dates": [{**SAMPLE["match"], "id": "31948"},
                                                   {**SAMPLE["match"], "id": "30804"}]}
        with (patch.object(loader, "UnderstatClient", return_value=client),
              patch.object(loader, "load_understat_scope", return_value=[
                  {"season_id": 100, "competition_id": 301, "name": "2026/2027"}]),
              patch.object(loader, "load_external_ids", return_value={"31948": 19715433}),
              patch.object(loader, "write_understat_report", return_value="report.json") as report,
              patch.object(loader, "replace_understat_rows") as write):
            result = loader.collect_understat()
        self.assertEqual(result, {"fixtures": 0, "players": 0, "shots": 0, "unavailable": 2})
        client.get_match.assert_not_called()
        write.assert_not_called()
        self.assertEqual(report.call_args.args[1]["fixtures"][0]["external_fixture_id"], "31948")

    def test_cli_commands_share_scope_and_check_parsing(self):
        from one_touch_loader import cli
        for command, function in [("understat-ids", "collect_understat_ids"),
                                  ("understat", "collect_understat"), ("xg-standings", "build_xg_standings")]:
            with self.subTest(command=command), patch.object(cli, function) as handler:
                with patch("sys.argv", ["cli", command, "2026/2027", "8", "564", "--check"]):
                    cli.main()
                handler.assert_called_once_with("2026/2027", [8, 564], check=True)
            with self.subTest(command=command, scope="all"), patch.object(cli, function) as handler:
                with patch("sys.argv", ["cli", command, "all"]):
                    cli.main()
                handler.assert_called_once_with(None, None, check=False)

    def test_later_season_mapping_removes_player_from_final_pending_report(self):
        source = {"teams": {"100": {"title": "Team"}}, "dates": [],
                  "players": [{"id": "1000", "player_name": "Alex One", "team_title": "Team"}]}
        observations = [{"team_id": 10, "player_id": 1, "display_name": "Alex One", "full_name": None}]
        maps = {"team": {"100": 10}, "fixture": {}, "player": {}}
        client = Mock()
        client.get_season.return_value = source
        scope = [{"season_id": 100 + i, "competition_id": 8, "name": f"{2024+i}/{2025+i}"} for i in range(2)]
        with (patch.object(ids, "UnderstatClient", return_value=client),
              patch.object(ids, "load_understat_scope", return_value=scope),
              patch.object(ids, "load_mapping_source", return_value=(source, [])),
              patch.object(ids, "load_external_ids", side_effect=maps.__getitem__),
              patch.object(ids, "load_player_observations", side_effect=[[], observations]),
              patch.object(ids, "load_mapping_fixtures", return_value=[]),
              patch.object(ids, "write_understat_report", return_value="report.json") as report,
              patch.object(ids, "transaction") as write):
            result = ids.collect_understat_ids(check=True)
        self.assertEqual(result["pending"], 0)
        self.assertEqual(report.call_args.args[1]["players"], [])
        write.assert_not_called()

    def test_xg_route_uses_current_season_and_discloses_1touch_method(self):
        from one_touch_loader.api.routes import competitions
        with (patch.object(competitions, "ensure_user"),
              patch.object(competitions, "get_current_season_id_for_competition", return_value=100),
              patch.object(competitions, "list_xg_standings", return_value=[]) as read):
            response = competitions.competition_xg_standings(564, season_id=None, user_id=1)
        self.assertEqual(response["xpts_method"], "historical_draw_rate")
        read.assert_called_once_with(564, 100)


if __name__ == "__main__":
    unittest.main()
