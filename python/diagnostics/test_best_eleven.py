from __future__ import annotations

import io
import itertools
import json
import random
import re
import sqlite3
import unittest
from contextlib import ExitStack, redirect_stdout
from pathlib import Path
from unittest.mock import MagicMock, patch

from one_touch_loader import cli
from one_touch_loader.api.repos import best_eleven_repo as repo
from one_touch_loader.api.schemas.common import BestElevenResponse
from one_touch_loader.core import db
from one_touch_loader.core.best_eleven import formation_slots, select_players
from one_touch_loader.loaders import best_eleven_loader as loader


CASES = json.loads((Path(__file__).parent / "fixtures/best_eleven_verified_lineups.json").read_text(encoding="utf-8"))


def source_lineup(fixture_id=1, formation="4-3-3", first_player=1):
    return [(fixture_id, formation, first_player + index, slot)
            for index, slot in enumerate(formation_slots(formation))]


class SelectionTests(unittest.TestCase):
    def test_actual_west_ham_maximizes_total_starts(self):
        case = CASES["west_ham"]
        result = loader.build_best_eleven_rows(case["team_id"], case["season_id"], case["rows"])
        self.assertEqual(sum(row[5] for row in result["players"]), 21)
        forwards = {row[3]: row[4] for row in result["players"] if row[3].startswith("5:")}
        self.assertEqual(forwards, {"5:1": 31532, "5:2": 1592})

    def test_assignment_matches_exhaustive_search_with_deterministic_ties(self):
        # 작은 후보 집합의 모든 조합을 직접 열거해 최적 합과 동점 순서를 독립적으로 확인해요.
        rng = random.Random(19)
        slots = ["1:1", "2:1", "2:2"]
        for _ in range(80):
            records = {(slot, player): rng.randrange(5) for slot in slots for player in range(1, 5)}
            records.update({(slot, index + 1): 1 for index, slot in enumerate(slots)})
            records = {key: value for key, value in records.items() if value}
            possible = [(sum(records[slot, player] for slot, player in zip(slots, players)), players)
                        for players in itertools.permutations(range(1, 5), 3)
                        if all((slot, player) in records for slot, player in zip(slots, players))]
            expected = min(possible, key=lambda item: (-item[0], item[1]))
            items = list(records.items())
            rng.shuffle(items)
            actual = select_players(slots, dict(items))
            self.assertEqual((sum(row[2] for row in actual), tuple(row[1] for row in actual)), expected)

    def test_never_uses_unobserved_slot_even_if_partial_assignment_has_more_starts(self):
        result = select_players(["2:1", "2:2"], {("2:1", 1): 100, ("2:1", 2): 1, ("2:2", 1): 1})
        self.assertEqual(result, [("2:1", 2, 1), ("2:2", 1, 1)])

    def test_duplicate_player_cannot_fill_two_slots(self):
        with self.assertRaisesRegex(ValueError, "different starting player"):
            select_players(["2:1", "2:2"], {("2:1", 1): 1, ("2:2", 1): 1})


class LineupTests(unittest.TestCase):
    def test_verified_provider_mismatch_is_excluded_without_changing_source(self):
        case = CASES["marseille_mismatch"]
        original = json.dumps(case)
        result = loader.build_best_eleven_rows(44, 17160, case["rows"] + source_lineup(999))
        self.assertEqual(result["excluded"], [(16481727, "formation_slots_mismatch")])
        self.assertEqual(result["formations"], [(44, 17160, "4-3-3", 1)])
        self.assertEqual(len(result["players"]), 11)
        self.assertTrue(all(row[5] == 1 for row in result["players"]))
        self.assertEqual(json.dumps(case), original)

    def test_missing_minutes_fixture_still_uses_verified_starts(self):
        case = CASES["missing_minutes"]
        result = loader.build_best_eleven_rows(case["team_id"], case["season_id"], case["rows"])
        self.assertEqual(result["formations"], [(683, 18444, "3-4-1-2", 1)])
        self.assertEqual(len(result["players"]), 11)
        self.assertTrue(all(len(row) == 6 and row[5] == 1 for row in result["players"]))

    def test_partial_and_missing_lineups_are_unavailable(self):
        rows = [(1, None, None, None)] + source_lineup(2)[:10]
        rows += [(3, formation, player, None) for _, formation, player, _ in source_lineup(3)]
        result = loader.build_best_eleven_rows(1, 1, rows)
        self.assertEqual(result["formations"], [])
        self.assertEqual(result["players"], [])
        self.assertEqual(result["excluded"], [(1, "missing_formation"), (2, "incomplete_starters"), (3, "missing_slots")])

    def test_extra_starter_with_missing_slot_does_not_pass_eleven_slot_filter(self):
        rows = source_lineup() + [(1, "4-3-3", 12, None)]
        self.assertEqual(loader.build_best_eleven_rows(1, 1, rows)["excluded"], [(1, "incomplete_starters")])

    def test_distinct_players_in_duplicate_slots_are_excluded(self):
        rows = source_lineup()
        rows[-1] = (*rows[-1][:3], rows[-2][3])
        self.assertEqual(loader.build_best_eleven_rows(1, 1, rows)["excluded"], [(1, "formation_slots_mismatch")])

    def test_each_formation_has_its_own_players_and_match_count(self):
        rows = source_lineup(1) + source_lineup(2) + source_lineup(3, "3-5-2", 101)
        result = loader.build_best_eleven_rows(10, 100, rows)
        self.assertEqual(result["formations"], [(10, 100, "4-3-3", 2), (10, 100, "3-5-2", 1)])
        self.assertEqual(len(result["players"]), 22)
        for row in result["players"]:
            self.assertEqual(row[5], 2 if row[2] == "4-3-3" else 1)
            self.assertEqual(row[4] < 100, row[2] == "4-3-3")


class DatabaseFlowTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(redirect_stdout(io.StringIO()))
        self.sql = sqlite3.connect(":memory:")
        self.addCleanup(self.sql.close)
        self.sql.execute("PRAGMA foreign_keys=ON")
        self.sql.executescript("""
            CREATE TABLE team_seasons (team_id BIGINT, season_id BIGINT, PRIMARY KEY(team_id, season_id));
            CREATE TABLE seasons (season_id BIGINT PRIMARY KEY, competition_id INT, name TEXT);
            CREATE TABLE stages (stage_id BIGINT PRIMARY KEY, season_id BIGINT);
            CREATE TABLE fixtures (fixture_id BIGINT PRIMARY KEY, stage_id BIGINT, home_team_id BIGINT, away_team_id BIGINT, state_id INT);
            CREATE TABLE fixture_formations (fixture_id BIGINT, team_id BIGINT, formation TEXT, PRIMARY KEY(fixture_id,team_id));
            CREATE TABLE fixture_lineups (fixture_id BIGINT, team_id BIGINT, player_id BIGINT, lineup_type_id INT, formation_field TEXT, PRIMARY KEY(fixture_id,team_id,player_id));
            CREATE TABLE players (player_id BIGINT PRIMARY KEY, display_name TEXT, image_path TEXT, position_id INT);
            CREATE TABLE positions (position_id INT PRIMARY KEY, position_group_code TEXT, position_code TEXT);
            INSERT INTO seasons VALUES (100,8,'2025/2026'), (200,2,'2025/2026'), (300,8,'2024/2025');
            INSERT INTO stages VALUES (10,100), (20,200), (30,300);
            INSERT INTO team_seasons VALUES (10,100);
            INSERT INTO positions VALUES (1,'GK','GK');
        """)
        # 실제 CREATE SQL의 관계·키·CHECK를 메모리 DB에서도 사용해요. MySQL 전용 인덱스
        # 표기와 저장 엔진만 바꾸며 실제 MySQL 마이그레이션 검증을 대신하지는 않아요.
        ddl = (Path(__file__).parents[1] / "one_touch_loader/sql/create_team_best_eleven.sql").read_text(encoding="utf-8")
        ddl = re.sub(r"^\s*KEY \w+ \([^\n]+\),\n", "", ddl, flags=re.MULTILINE)
        ddl = re.sub(r"UNIQUE KEY \w+", "UNIQUE", ddl)
        ddl = re.sub(r"\) ENGINE=[^;]+;", ");", ddl)
        self.sql.executescript(ddl)
        self.sql.commit()

        def connection():
            conn = MagicMock()
            cur = MagicMock()
            raw = self.sql.cursor()
            cur.__enter__.return_value = cur
            cur.execute.side_effect = lambda statement, params=(): raw.execute(statement.replace("%s", "?"), params)
            cur.executemany.side_effect = lambda statement, rows: raw.executemany(statement.replace("%s", "?"), rows)
            cur.fetchall.side_effect = raw.fetchall
            conn.cursor.return_value = cur
            conn.commit.side_effect = self.sql.commit
            conn.rollback.side_effect = self.sql.rollback
            return conn

        self.read_connections = self.stack.enter_context(patch.object(loader, "get_conn", side_effect=connection))
        self.stack.enter_context(patch.object(db, "get_conn", side_effect=connection))

    def add_fixture(self, fixture_id, formation="4-3-3", first_player=1, stage=10, state=5):
        self.sql.execute("INSERT INTO fixtures VALUES (?,?,10,20,?)", (fixture_id, stage, state))
        self.sql.execute("INSERT INTO fixture_formations VALUES (?,10,?)", (fixture_id, formation))
        for _, _, player, slot in source_lineup(fixture_id, formation, first_player):
            self.sql.execute("INSERT OR IGNORE INTO players VALUES (?,?,NULL,NULL)", (player, f"Player {player}"))
            self.sql.execute("INSERT INTO fixture_lineups VALUES (?,10,?,11,?)", (fixture_id, player, slot))
        self.sql.commit()

    def api(self, formation=None):
        def fetch(statement, params):
            cur = self.sql.execute(statement.replace("%s", "?"), params)
            return [dict(zip((col[0] for col in cur.description), row)) for row in cur.fetchall()]
        with patch.object(repo, "fetch_all_dict", side_effect=fetch) as read:
            result = repo.get_best_eleven(10, 100, formation)
            read.assert_called_once()
        return result

    def test_source_combines_same_season_league_and_cup_completed_games_only(self):
        self.add_fixture(1)
        self.add_fixture(2, stage=20, state=7)
        self.add_fixture(3, stage=20, state=8)
        self.add_fixture(4, stage=30)
        self.add_fixture(5, state=1)
        totals = loader.rebuild_best_eleven("2025/2026")
        self.assertEqual(totals["built"], 1)
        self.assertEqual(self.sql.execute("SELECT matches_used FROM team_best_eleven_formations").fetchone(), (3,))
        self.assertTrue(all(row == (3,) for row in self.sql.execute("SELECT starts FROM team_best_eleven")))

    def test_one_season_scopes_all_five_leagues_and_not_external_opponents(self):
        for index, competition in enumerate((82, 301, 384, 564), start=1):
            self.sql.execute("INSERT INTO seasons VALUES (?,?,'2025/2026')", (100 + index, competition))
            self.sql.execute("INSERT INTO team_seasons VALUES (?,?)", (10 + index, 100 + index))
        self.sql.execute("INSERT INTO team_seasons VALUES (20,200)")
        self.sql.commit()
        totals = loader.rebuild_best_eleven("2025/2026")
        self.assertEqual(totals["team_seasons"], 5)
        self.assertEqual(totals["unavailable"], 5)

    def test_already_loaded_lineups_build_empty_cache_and_repeat_without_duplicates(self):
        self.add_fixture(1)
        for _ in range(2):
            self.assertEqual(loader.rebuild_best_eleven("2025/2026")["built"], 1)
            self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM team_best_eleven").fetchone(), (11,))

    def test_default_overview_and_selected_analysis_have_independent_elevens(self):
        self.add_fixture(1)
        self.add_fixture(2)
        self.add_fixture(3, "3-5-2", 101)
        loader.rebuild_best_eleven("2025/2026")
        overview, analysis = self.api(), self.api("3-5-2")
        self.assertEqual(overview["formation"], "4-3-3")
        self.assertEqual(overview["usage_percentage"], 66.7)
        self.assertEqual(analysis["usage_percentage"], 33.3)
        self.assertEqual(overview["formations"], analysis["formations"])
        self.assertEqual(len(overview["formations"]), 2)
        self.assertTrue(all(row["player_id"] < 100 for row in overview["players"]))
        self.assertTrue(all(row["player_id"] >= 100 for row in analysis["players"]))
        self.assertEqual([row["slot_index"] for row in analysis["players"]], list(range(11)))
        BestElevenResponse.model_validate(overview)
        BestElevenResponse.model_validate(analysis)

    def test_default_formation_tie_uses_name_order(self):
        self.add_fixture(1)
        self.add_fixture(2, "3-5-2", 101)
        loader.rebuild_best_eleven("2025/2026")
        self.assertEqual(self.api()["formation"], "3-5-2")

    def test_profile_changes_are_visible_without_rebuilding(self):
        self.add_fixture(1)
        loader.rebuild_best_eleven("2025/2026")
        self.sql.execute("UPDATE players SET display_name='Updated name', position_id=1 WHERE player_id=1")
        row = self.api()["players"][0]
        self.assertEqual(row["player_name"], "Updated name")
        self.assertEqual((row["position_group_code"], row["position_code"]), ("GK", "GK"))
        self.assertNotIn("total_minutes", row)

    def test_unavailable_formation_returns_none(self):
        self.assertIsNone(self.api())
        self.add_fixture(1)
        loader.rebuild_best_eleven("2025/2026")
        self.assertIsNone(self.api("3-5-2"))

    def test_incomplete_selected_result_is_not_returned_as_an_eleven(self):
        self.add_fixture(1)
        loader.rebuild_best_eleven("2025/2026")
        self.sql.execute("DELETE FROM team_best_eleven WHERE player_id=1")
        with self.assertRaisesRegex(ValueError, "Incomplete Best Eleven"):
            self.api()

    def test_no_valid_input_clears_old_results_and_validates_as_unavailable(self):
        self.add_fixture(1)
        loader.rebuild_best_eleven("2025/2026")
        self.sql.execute("UPDATE fixture_lineups SET formation_field=NULL")
        self.sql.commit()
        self.assertEqual(loader.validate_best_eleven("2025/2026")["status"], "FAIL")
        self.assertEqual(loader.rebuild_best_eleven("2025/2026")["unavailable"], 1)
        self.assertEqual(loader.validate_best_eleven("2025/2026")["status"], "PASS")
        self.assertIsNone(self.api())

    def test_validate_detects_missing_results_and_changed_counts(self):
        self.add_fixture(1)
        self.assertEqual(loader.validate_best_eleven("2025/2026")["status"], "FAIL")
        loader.rebuild_best_eleven("2025/2026")
        self.assertEqual(loader.validate_best_eleven("2025/2026")["status"], "PASS")
        self.sql.execute("UPDATE team_best_eleven SET starts=starts+1 WHERE player_id=1")
        self.sql.commit()
        self.assertEqual(loader.validate_best_eleven("2025/2026")["status"], "FAIL")

    def test_write_error_rolls_back_both_result_tables_and_retry_recomputes_team(self):
        self.add_fixture(1)
        loader.rebuild_best_eleven("2025/2026")
        previous = self.sql.execute("SELECT * FROM team_best_eleven").fetchall()
        self.add_fixture(2, "3-5-2", 101)
        self.sql.execute("""CREATE TRIGGER fail_player_insert BEFORE INSERT ON team_best_eleven
                            BEGIN SELECT RAISE(ABORT,'controlled write failure'); END""")
        self.sql.commit()
        with self.assertRaisesRegex(sqlite3.IntegrityError, "controlled write failure"):
            loader.rebuild_best_eleven("2025/2026")
        self.assertEqual(self.sql.execute("SELECT * FROM team_best_eleven").fetchall(), previous)
        self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM team_best_eleven_formations").fetchone(), (1,))
        self.sql.execute("DROP TRIGGER fail_player_insert")
        loader.rebuild_best_eleven("2025/2026")
        self.assertEqual(self.sql.execute("SELECT COUNT(*) FROM team_best_eleven").fetchone(), (22,))

    def test_result_foreign_keys_and_player_uniqueness_are_enforced(self):
        self.add_fixture(1)
        loader.rebuild_best_eleven("2025/2026")
        for statement in (
            "INSERT INTO team_best_eleven_formations VALUES (999,100,'4-3-3',1)",
            "UPDATE team_best_eleven SET player_id=999 WHERE slot_key='1:1'",
            "UPDATE team_best_eleven SET player_id=1 WHERE slot_key='2:1'",
            "INSERT INTO team_best_eleven VALUES (10,100,'3-5-2','1:1',1,1)",
            "UPDATE team_best_eleven SET starts=0 WHERE slot_key='1:1'",
            "UPDATE team_best_eleven_formations SET matches_used=0",
        ):
            with self.assertRaises(sqlite3.IntegrityError):
                self.sql.execute(statement)


class CliTests(unittest.TestCase):
    def test_season_and_all_rebuild_use_same_entry_point(self):
        for value, expected in [("2025/2026", "2025/2026"), ("all", None)]:
            with patch("sys.argv", ["cli", "best-eleven", value]), patch.object(cli, "rebuild_best_eleven", return_value={}) as build, redirect_stdout(io.StringIO()):
                cli.main()
                build.assert_called_once_with(expected)

    def test_validate_fail_has_nonzero_exit(self):
        with patch("sys.argv", ["cli", "best-eleven", "validate", "2021/2022"]), patch.object(cli, "validate_best_eleven", return_value={"status": "FAIL"}) as validate:
            with self.assertRaises(SystemExit) as error:
                cli.main()
            self.assertEqual(error.exception.code, 1)
            validate.assert_called_once_with("2021/2022")

    def test_validate_all_passes(self):
        with patch("sys.argv", ["cli", "best-eleven", "validate", "all"]), patch.object(cli, "validate_best_eleven", return_value={"status": "PASS"}) as validate:
            cli.main()
            validate.assert_called_once_with(None)

    def test_bare_command_does_not_collect_or_rebuild(self):
        with patch("sys.argv", ["cli", "best-eleven"]), patch.object(cli, "rebuild_best_eleven") as build, redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                cli.main()
            self.assertEqual(error.exception.code, 2)
            build.assert_not_called()


if __name__ == "__main__":
    unittest.main()
