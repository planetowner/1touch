from __future__ import annotations

import io
import json
import re
import sqlite3
import copy
import unittest
from contextlib import ExitStack, redirect_stdout
from pathlib import Path
from unittest.mock import MagicMock, patch

from fastapi import FastAPI, HTTPException

from one_touch_loader.api.repos import injuries_repo as repo
from one_touch_loader.api.routes import teams as routes
from one_touch_loader.api.schemas.common import TeamInjuriesResponse
from one_touch_loader import cli
from one_touch_loader.core import db
from one_touch_loader.loaders import injuries_loader as loader


CASES = json.loads((Path(__file__).parent / "fixtures/sportmonks_injuries_verified.json").read_text(encoding="utf-8"))


class InjuryDatabaseTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(redirect_stdout(io.StringIO()))
        self.sql = sqlite3.connect(":memory:")
        self.addCleanup(self.sql.close)
        self.sql.execute("PRAGMA foreign_keys=ON")
        self.sql.executescript("""
            CREATE TABLE teams (team_id BIGINT PRIMARY KEY);
            CREATE TABLE players (player_id BIGINT PRIMARY KEY, display_name TEXT, image_path TEXT);
            CREATE TABLE team_squad_members (
                team_id BIGINT, season_id BIGINT, player_id BIGINT, jersey_number INT,
                PRIMARY KEY (team_id,season_id,player_id)
            );
            INSERT INTO teams VALUES (8), (598), (7047), (7980), (1099);
        """)
        # 실제 생성 SQL의 PK·FK를 사용하고, MySQL 전용 인덱스·엔진 표기만 제거해요.
        ddl = (Path(__file__).parents[1] / "one_touch_loader/sql/create_team_player_injuries.sql").read_text(encoding="utf-8")
        ddl = re.sub(r"^  KEY \w+ \([^\n]+\),\n", "", ddl, flags=re.MULTILINE)
        ddl = re.sub(r"\) ENGINE=[^;]+;", ");", ddl)
        self.sql.executescript(ddl)
        self.sql.commit()
        self.stack.enter_context(patch.object(repo, "fetch_all_dict", side_effect=self.fetch_dicts))
        self.stack.enter_context(patch.object(db, "get_conn", side_effect=self.connection))

    def connection(self):
        conn = MagicMock()
        cur = MagicMock()
        raw = self.sql.cursor()
        cur.__enter__.return_value = cur
        def translate(statement):
            return statement.replace("%s", "?").replace(
                "ON DUPLICATE KEY UPDATE name = VALUES(name)",
                "ON CONFLICT(type_id) DO UPDATE SET name = excluded.name",
            )
        cur.execute.side_effect = lambda statement, params=(): raw.execute(translate(statement), params)
        cur.executemany.side_effect = lambda statement, rows: raw.executemany(translate(statement), rows)
        cur.fetchall.side_effect = raw.fetchall
        conn.cursor.return_value = cur
        conn.commit.side_effect = self.sql.commit
        conn.rollback.side_effect = self.sql.rollback
        return conn

    def add_squad(self, key, player_ids=None):
        case = CASES[key]
        ids = player_ids if player_ids is not None else {item["player_id"] for item in case["sidelined"]}
        for player_id in ids:
            self.sql.execute("INSERT OR IGNORE INTO players VALUES (?, ?, NULL)", (player_id, str(player_id)))
            self.sql.execute("INSERT INTO team_squad_members VALUES (?, 100, ?, NULL)", (case["team_id"], player_id))
        self.sql.commit()
        return case

    def fetch_dicts(self, statement, params=()):
        cursor = self.sql.execute(statement.replace("%s", "?"), params)
        names = [column[0] for column in cursor.description]
        return [dict(zip(names, row)) for row in cursor.fetchall()]

    def insert_case(self, key):
        case = CASES[key]
        for item in case["sidelined"]:
            if item["category"] != "injury":
                continue
            self.sql.execute("INSERT OR IGNORE INTO players VALUES (?, ?, NULL)", (item["player_id"], str(item["player_id"])))
            self.sql.execute("INSERT OR IGNORE INTO injury_types VALUES (?, ?)", (item["type_id"], item["type"]["name"]))
            self.sql.execute("INSERT INTO team_player_injuries VALUES (?, ?, ?, ?, ?, ?)", (
                item["id"], case["team_id"], item["player_id"], item["type_id"], item["start_date"], item["end_date"],
            ))
        self.sql.commit()
        return case["team_id"]

    def test_api_groups_actual_multiple_injuries_without_guessing_return(self):
        team_id = self.insert_case("atletico_past_dates")
        player_id = CASES["atletico_past_dates"]["sidelined"][0]["player_id"]
        self.sql.execute("INSERT INTO team_squad_members VALUES (?, 100, ?, NULL)", (team_id, player_id))
        result = repo.get_team_injuries(team_id, 100)
        self.assertEqual(len(result["players"]), 1)
        player = result["players"][0]
        self.assertEqual(len(player["injuries"]), 3)
        self.assertIsNone(player["jersey_number"])
        self.assertTrue(all(item["end_date"] < "2026-01-01" for item in player["injuries"]))
        self.assertNotIn("weeks_until_return", player)
        TeamInjuriesResponse.model_validate(result)

    def test_api_reads_current_profile_and_exact_team_season_membership(self):
        team_id = self.insert_case("liverpool")
        self.sql.execute("INSERT INTO team_squad_members VALUES (8, 100, 129836, 14)")
        self.sql.execute("INSERT INTO team_squad_members VALUES (8, 99, 1453, 2)")
        self.sql.execute("INSERT INTO team_squad_members VALUES (598, 100, 1453, 3)")
        self.sql.execute("UPDATE players SET display_name='Updated profile', image_path='new.png' WHERE player_id=129836")
        result = repo.get_team_injuries(team_id, 100)
        self.assertEqual([p["player_id"] for p in result["players"]], [129836])
        player = result["players"][0]
        self.assertEqual((player["player_name"], player["player_image"], player["jersey_number"]), ("Updated profile", "new.png", 14))
        self.sql.execute("DELETE FROM team_squad_members WHERE team_id=8 AND season_id=100")
        self.assertEqual(repo.get_team_injuries(team_id, 100)["players"], [])

    def test_api_preserves_missing_end_date_and_empty_list(self):
        self.insert_case("liverpool")
        self.sql.execute("INSERT INTO team_squad_members VALUES (8, 100, 1453, NULL)")
        result = repo.get_team_injuries(8, 100)
        self.assertIsNone(result["players"][0]["injuries"][0]["end_date"])
        self.assertEqual(repo.get_team_injuries(1099, 100)["players"], [])

    def test_ddl_enforces_player_team_and_type_relationships(self):
        self.sql.execute("INSERT INTO injury_types VALUES (554, 'Muscle Injury')")
        self.sql.execute("INSERT INTO players VALUES (129836, 'Chiesa', NULL)")
        for team_id, player_id, type_id in ((999, 129836, 554), (8, 999, 554), (8, 129836, 999)):
            with self.assertRaises(sqlite3.IntegrityError):
                self.sql.execute("INSERT INTO team_player_injuries VALUES (1, ?, ?, ?, NULL, NULL)", (team_id, player_id, type_id))

    def test_null_unused_count_past_dates_and_multiple_events_are_preserved(self):
        for key in ("rennes_missing_count", "atletico_past_dates"):
            case = self.add_squad(key)
            result = loader.replace_team_injuries(case["team_id"], 100, case["sidelined"])
            expected = [item for item in case["sidelined"] if item["category"] == "injury"]
            self.assertEqual(result["injuries"], len(expected))
            stored = self.sql.execute("SELECT sideline_id,start_date,end_date FROM team_player_injuries WHERE team_id=? ORDER BY sideline_id", (case["team_id"],)).fetchall()
            self.assertEqual(stored, sorted((i["id"], i["start_date"], i["end_date"]) for i in expected))

    def test_only_db_squad_injuries_are_stored_and_exclusions_identify_events(self):
        case = self.add_squad("liverpool", {129836})
        original = copy.deepcopy(case)
        result = loader.replace_team_injuries(8, 100, case["sidelined"])
        self.assertEqual((result["received"], result["injuries"], result["non_injury"]), (5, 1, 2))
        self.assertEqual({r["player_id"] for r in result["excluded_not_in_squad"]}, {1453, 37288979})
        self.assertEqual(case, original)
        self.assertEqual(self.sql.execute("SELECT sideline_id FROM team_player_injuries").fetchall(), [(811008,)])
        self.assertEqual(self.sql.execute("SELECT type_id FROM injury_types").fetchall(), [(554,)])
        self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM players").fetchone(), (1,))

    def test_repeated_and_empty_team_replacement_preserve_other_team(self):
        first = self.add_squad("liverpool")
        other = self.add_squad("troyes_multiple")
        loader.replace_team_injuries(7047, 100, other["sidelined"])
        for _ in range(2):
            result = loader.replace_team_injuries(8, 100, first["sidelined"])
            self.assertEqual(result["injuries"], 3)
        loader.replace_team_injuries(8, 100, [])
        self.assertEqual(self.sql.execute("SELECT DISTINCT team_id FROM team_player_injuries").fetchall(), [(7047,)])
        self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM team_player_injuries").fetchone(), (4,))

    def test_storage_failure_rolls_back_dictionary_and_old_list_together(self):
        case = self.add_squad("liverpool")
        loader.replace_team_injuries(8, 100, case["sidelined"])
        before = self.sql.execute("SELECT * FROM team_player_injuries ORDER BY sideline_id").fetchall()
        before_types = self.sql.execute("SELECT * FROM injury_types ORDER BY type_id").fetchall()
        changed = copy.deepcopy(case["sidelined"])
        changed[0]["type"]["name"] = "Changed reason"
        self.sql.execute("CREATE TRIGGER fail_injury BEFORE INSERT ON team_player_injuries BEGIN SELECT RAISE(ABORT,'controlled write failure'); END")
        self.sql.commit()
        with self.assertRaisesRegex(sqlite3.IntegrityError, "controlled write failure"):
            loader.replace_team_injuries(8, 100, changed)
        self.assertEqual(self.sql.execute("SELECT * FROM team_player_injuries ORDER BY sideline_id").fetchall(), before)
        self.assertEqual(self.sql.execute("SELECT * FROM injury_types ORDER BY type_id").fetchall(), before_types)
        self.sql.execute("DROP TRIGGER fail_injury")
        self.assertEqual(loader.replace_team_injuries(8, 100, case["sidelined"])["injuries"], 3)


class InjuryRouteTests(unittest.TestCase):
    def test_current_scope_empty_list_and_unknown_team(self):
        app = FastAPI()
        app.include_router(routes.router, prefix="/v1")
        response = {"team_id": 8, "season_id": 28083, "players": []}
        with patch.object(routes, "find_team_current_context", return_value=(8, 28083)) as context, patch.object(routes, "get_team_injuries", return_value=response) as read:
            result = routes.team_injuries(8, user_id=1)
            self.assertEqual(result, response)
            read.assert_called_once_with(8, 28083)
            context.return_value = None
            with self.assertRaises(HTTPException) as error:
                routes.team_injuries(999, user_id=1)
            self.assertEqual(error.exception.status_code, 404)
        operation = app.openapi()["paths"]["/v1/teams/{team_id}/injuries"]["get"]
        self.assertEqual(operation["responses"]["200"]["content"]["application/json"]["schema"]["$ref"], "#/components/schemas/TeamInjuriesResponse")
        self.assertEqual({p["name"] for p in operation["parameters"]}, {"team_id"})
        self.assertEqual(operation["security"], [{"HTTPBearer": []}])


class InjuryScopeTests(unittest.TestCase):
    def test_all_and_single_team_use_the_same_current_squad_scope_and_storage(self):
        scope = [{"team_id": 8, "season_id": 28083}, {"team_id": 7047, "season_id": 28082}]
        with patch.object(loader, "load_squad_scope", return_value=scope) as read_scope, patch.object(loader, "SportmonksClient") as client, patch.object(loader, "replace_team_injuries", return_value={"received": 1, "injuries": 0, "non_injury": 0, "excluded_not_in_squad": [{"sideline_id": 1, "player_id": 99}]}) as store, redirect_stdout(io.StringIO()) as output:
            client.return_value.get_team_with_sidelined.return_value = {"sidelined": []}
            self.assertEqual(loader.refresh_current_injuries()["teams"], 2)
            read_scope.assert_called_once_with(current_only=True)
            self.assertEqual([c.args[:2] for c in store.call_args_list], [(8, 28083), (7047, 28082)])
            store.reset_mock()
            self.assertEqual(loader.refresh_team_injuries(8)["teams"], 1)
            store.assert_called_once_with(8, 28083, [])
            self.assertIn("reason=not_in_db_current_squad", output.getvalue())
            self.assertIn('"sideline_id": 1', output.getvalue())

    def test_unknown_team_is_rejected_before_provider_or_storage(self):
        with patch.object(loader, "load_squad_scope", return_value=[{"team_id": 8, "season_id": 28083}]), patch.object(loader, "SportmonksClient") as client:
            with self.assertRaisesRegex(ValueError, "Not a current Big 5 team"):
                loader.refresh_team_injuries(999)
            client.assert_not_called()

    def test_cli_documents_and_routes_current_and_team_commands(self):
        for args, name, expected in [
            (["refresh-current"], "refresh_current_injuries", None),
            (["refresh-current", "8,7047"], "refresh_current_injuries", [8, 7047]),
            (["refresh-team", "8"], "refresh_team_injuries", 8),
        ]:
            with patch("sys.argv", ["cli", "injuries", *args]), patch.object(cli, name, return_value={}) as collect, redirect_stdout(io.StringIO()):
                cli.main()
                collect.assert_called_once_with(expected)
        self.assertIn("15. injuries", cli.USAGE)


if __name__ == "__main__":
    unittest.main()
