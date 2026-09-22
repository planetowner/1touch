"""한국어 이름 검색이 기존 선수·팀 범위와 읽기 전용 계약을 유지하는지 확인해요."""
import unittest
import sqlite3
from unittest.mock import MagicMock, patch

with patch("mysql.connector.pooling.MySQLConnectionPool") as pool:
    pool.return_value.get_connection.side_effect = AssertionError("Operational DB access in tests")
    from one_touch_loader.core import football_names as names_repo
    from one_touch_loader.api.repos import player_detail_repo, points_pace_repo
    from diagnostics import migrate_football_names as migration
    from diagnostics import migrate_team_short_names_ko as short_migration
    from diagnostics import migrate_team_short_names as english_migration
    from diagnostics import correct_serie_a_names_ko as correction


class FootballNamesTests(unittest.TestCase):
    def test_verified_ids_and_unknowns(self):
        with patch.object(names_repo, "fetch_all", return_value=[(4313,)]) as fetch:
            self.assertEqual(names_repo.korean_name_ids("players", "손 흥민"), (4313,))
            sql, params = fetch.call_args.args
            self.assertIn("display_name_ko", sql)
            self.assertIn("FROM players", sql)
            self.assertEqual(params, ("손흥민",))
            fetch.reset_mock()
            self.assertEqual(names_repo.korean_name_ids("players", "  "), ())
            fetch.assert_not_called()

    def test_player_search_keeps_current_squad_filter_and_english_response(self):
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchall.return_value = [{"player_id": 4313, "name": "Heung-min Son", "image": None}]
        with patch.object(player_detail_repo, "get_conn", return_value=conn), \
                patch.object(names_repo, "fetch_all", return_value=[(4313,)]):
            rows = player_detail_repo.list_player_comparison_candidates("손흥민")
        sql, params = cur.execute.call_args.args
        self.assertIn("WHERE s.is_current=1 AND (", sql)
        self.assertIn("OR p.player_id IN (%s)", sql)
        self.assertNotIn("손흥민", sql)
        self.assertEqual(params, ("%손흥민%", 4313))
        self.assertEqual(rows[0]["name"], "Heung-min Son")
        conn.start_transaction.assert_called_once_with(readonly=True)
        conn.rollback.assert_called_once()
        conn.commit.assert_not_called()

    def test_unknown_query_keeps_existing_english_search(self):
        conn = MagicMock()
        with patch.object(player_detail_repo, "get_conn", return_value=conn), \
                patch.object(names_repo, "fetch_all", return_value=[]):
            player_detail_repo.list_player_comparison_candidates("Kane")
        sql, params = conn.cursor.return_value.__enter__.return_value.execute.call_args.args
        self.assertNotIn("IN ()", sql)
        self.assertNotIn("OR p.player_id", sql)
        self.assertEqual(params, ("%Kane%",))

    def test_team_search_keeps_season_fixture_rules_and_limit(self):
        with patch.object(points_pace_repo, "fetch_all_dict", return_value=[]) as fetch, \
                patch.object(names_repo, "fetch_all", return_value=[(8,)]):
            points_pace_repo.list_current_form_options(search="리버풀", limit=5)
        sql, params = fetch.call_args.args
        self.assertIn("JOIN fixtures f", sql)
        self.assertIn("s.competition_id IN", sql)
        self.assertIn("OR t.team_id IN (%s)", sql)
        self.assertEqual(params, ("리버풀", "리버풀", "리버풀", 8, 5))

    def test_catalog_reads_changed_db_values_without_file_or_restart(self):
        with patch.object(names_repo, "fetch_all", side_effect=[[(8, "리버풀")], [(997, "해리 케인")],
                                                               [(9, "맨시티")], [(8, "새 이름")], [], [(9, "새 짧은 이름")]]):
            first = names_repo.korean_names()
            second = names_repo.korean_names()
        self.assertEqual(first, {"teams": {"8": "리버풀"}, "players": {"997": "해리 케인"},
                                 "team_short_names": {"9": "맨시티"}})
        self.assertEqual(second, {"teams": {"8": "새 이름"}, "players": {},
                                  "team_short_names": {"9": "새 짧은 이름"}})

    def test_team_search_checks_full_and_short_names_with_bound_parameters(self):
        with patch.object(names_repo, "fetch_all", return_value=[(9,)]) as fetch:
            self.assertEqual(names_repo.korean_name_ids("teams", "맨 시티"), (9,))
        sql, params = fetch.call_args.args
        self.assertIn("REGEXP_REPLACE(name_ko", sql)
        self.assertIn("REGEXP_REPLACE(short_name_ko", sql)
        self.assertIn(" OR ", sql)
        self.assertNotIn("맨시티", sql)
        self.assertEqual(params, ("맨시티", "맨시티"))

    def test_names_endpoint_requires_authentication(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        from one_touch_loader.api.routes.football_names import router
        from one_touch_loader.api.deps import get_user_id
        app = FastAPI()
        app.include_router(router, prefix="/v1")
        client = TestClient(app)
        self.assertEqual(client.get("/v1/football-names/ko").status_code, 401)
        app.dependency_overrides[get_user_id] = lambda: 1
        with patch.object(names_repo, "fetch_all", side_effect=[[(8, "리버풀")], [(997, "해리 케인")], [(9, "맨시티")]]):
            response = client.get("/v1/football-names/ko")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"teams": {"8": "리버풀"}, "players": {"997": "해리 케인"},
                                           "team_short_names": {"9": "맨시티"}})


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("CREATE TABLE teams (team_id INTEGER PRIMARY KEY, name TEXT, short_name TEXT, name_ko TEXT)")
        self.db.execute("CREATE TABLE players (player_id INTEGER PRIMARY KEY, display_name TEXT, full_name TEXT, display_name_ko TEXT)")
        self.db.executemany("INSERT INTO teams VALUES (?, ?, ?, ?)", [(8, "Liverpool", "LFC", None), (9, "Other", "OTH", None)])
        self.db.executemany("INSERT INTO players VALUES (?, ?, ?, ?)", [(997, "Harry Kane", "Harry Kane", None), (1, "Other", "Other Full", None)])
        self.db.commit()
        db = self.db

        class Cursor:
            def __enter__(self):
                self.cursor = db.cursor()
                return self

            def __exit__(self, *args):
                self.cursor.close()

            def execute(self, sql, params=()):
                return self.cursor.execute(sql.replace("%s", "?").replace(" FOR UPDATE", ""), params)

            @property
            def description(self):
                return self.cursor.description

            def fetchall(self):
                return self.cursor.fetchall()

        class Connection:
            def cursor(self):
                return Cursor()

            def start_transaction(self):
                db.execute("BEGIN")

            def commit(self):
                db.commit()

            def rollback(self):
                db.rollback()

        self.connection = Connection()

    def tearDown(self):
        self.db.close()

    def test_migration_changes_only_localized_columns_and_is_repeatable(self):
        reviewed = {"teams": {8: "리버풀"}, "players": {997: "해리 케인"}}
        with patch.object(migration, "reviewed_names", return_value=reviewed):
            migration.migrate_data(self.connection)
            migration.migrate_data(self.connection)
        self.assertEqual(self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall(),
                         [(8, "Liverpool", "LFC", "리버풀"), (9, "Other", "OTH", None)])
        self.assertEqual(self.db.execute("SELECT * FROM players ORDER BY player_id").fetchall(),
                         [(1, "Other", "Other Full", None), (997, "Harry Kane", "Harry Kane", "해리 케인")])

    def test_later_identity_conflict_rolls_back_earlier_team_update(self):
        reviewed = {"teams": {8: "리버풀"}, "players": {999: "없는 선수"}}
        with patch.object(migration, "reviewed_names", return_value=reviewed), self.assertRaises(ValueError):
            migration.migrate_data(self.connection)
        self.assertIsNone(self.db.execute("SELECT name_ko FROM teams WHERE team_id=8").fetchone()[0])

    def test_provider_refresh_leaves_localized_columns_untouched(self):
        from one_touch_loader.loaders.teams_loader import SQL_UPSERT_TEAM
        from one_touch_loader.loaders.players_loader import SQL_UPSERT_PLAYER
        self.assertNotIn("name_ko", SQL_UPSERT_TEAM)
        self.assertNotIn("short_name_ko", SQL_UPSERT_TEAM)
        self.assertNotIn("display_name_ko", SQL_UPSERT_PLAYER)

    def test_short_name_migration_preserves_all_other_values_and_is_repeatable(self):
        self.db.execute("ALTER TABLE teams ADD COLUMN short_name_ko TEXT")
        self.db.execute("UPDATE teams SET name_ko='리버풀' WHERE team_id=8")
        self.db.commit()
        players_before = self.db.execute("SELECT * FROM players ORDER BY player_id").fetchall()
        with patch.object(short_migration, "reviewed_rows", return_value=[{"team_id": 8, "short_name_ko": "리버풀"}]):
            short_migration.migrate_data(self.connection)
            short_migration.migrate_data(self.connection)
        self.assertEqual(self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall(),
                         [(8, "Liverpool", "LFC", "리버풀", "리버풀"), (9, "Other", "OTH", None, None)])
        self.assertEqual(self.db.execute("SELECT * FROM players ORDER BY player_id").fetchall(), players_before)

    def test_short_name_conflict_does_not_overwrite_saved_name(self):
        self.db.execute("ALTER TABLE teams ADD COLUMN short_name_ko TEXT")
        self.db.execute("UPDATE teams SET short_name_ko='기존 이름' WHERE team_id=8")
        self.db.commit()
        before = self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall()
        with patch.object(short_migration, "reviewed_rows", return_value=[{"team_id": 8, "short_name_ko": "리버풀"}]), \
                self.assertRaises(ValueError):
            short_migration.migrate_data(self.connection)
        self.assertEqual(self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall(), before)

    def test_short_name_seed_and_current_membership_check(self):
        rows = short_migration.reviewed_rows()
        self.assertEqual(len(rows), 135)
        self.assertEqual({key: sum(row["competition_id"] == key for row in rows) for key in (8, 82, 301, 384, 564)},
                         {8: 20, 82: 18, 301: 18, 384: 20, 564: 20})
        reviewed = {row["team_id"]: row["short_name_ko"] for row in rows}
        self.assertEqual({key: reviewed[key] for key in (9, 7980, 591, 90)},
                         {9: "맨시티", 7980: "AT 마드리드", 591: "PSG", 90: "아우크스부르크"})
        current = [(row["competition_id"], row["season_id"], row["season"], row["team_id"], row["name"]) for row in rows]
        with patch.object(short_migration, "fetch_all", side_effect=[[], current, [(key, None) for key in reviewed]]):
            self.assertEqual(short_migration.preview(), (False, {"reviewed": 135, "updates": 135}))
        with patch.object(short_migration, "fetch_all", side_effect=[[], current[:-1]]), self.assertRaises(ValueError):
            short_migration.preview()

    def test_uefa_scope_excludes_other_qualifying_teams(self):
        rows = short_migration.reviewed_rows()
        extra = [row for row in rows if row["competition_id"] in (2, 5)]
        self.assertEqual(len(extra), 39)
        self.assertEqual(sum(row["competition_id"] == 2 for row in extra), 15)
        self.assertEqual(sum(row["competition_id"] == 5 for row in extra), 24)
        self.assertNotIn(62, {row["team_id"] for row in rows})  # 첨부 표에 없는 Rangers는 추가하지 않아요.
        by_id = {row["team_id"]: row for row in extra}
        self.assertEqual((by_id[1114]["short_name"], by_id[1114]["source_rank"], by_id[1114]["english_source_rank"]),
                         ("NK Celje", 30, 29))
        self.assertEqual(by_id[61]["short_name_ko"], "알크마르 잔스트리크")
        self.assertEqual(by_id[138649]["short_name"], "Sabah")
        current = [(row["competition_id"], row["season_id"], row["season"], row["team_id"], row["name"]) for row in rows]
        current.append((5, 27913, "2026/2027", 62, "Rangers"))
        with patch.object(short_migration, "fetch_all", side_effect=[[], current, [(row['team_id'], None) for row in rows]]):
            self.assertEqual(short_migration.preview()[1]['reviewed'], 135)

    def test_english_extension_preserves_previous_names_and_other_rows(self):
        self.db.execute("UPDATE teams SET short_name=NULL WHERE team_id=9")
        self.db.execute("UPDATE teams SET name_ko='리버풀' WHERE team_id=8")
        self.db.commit()
        with patch.object(english_migration, "short_names", return_value={8: "LFC", 9: "New short"}):
            english_migration.migrate_data(self.connection)
            english_migration.migrate_data(self.connection)
        self.assertEqual(self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall(),
                         [(8, "Liverpool", "LFC", "리버풀"), (9, "Other", "New short", None)])
        before = self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall()
        with patch.object(english_migration, "short_names", return_value={8: "Wrong replacement"}), self.assertRaises(ValueError):
            english_migration.migrate_data(self.connection)
        self.assertEqual(self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall(), before)

    def test_requested_full_name_correction_preserves_both_short_names(self):
        self.db.execute("ALTER TABLE teams ADD COLUMN short_name_ko TEXT")
        short_names = {43: "라치오", 708: "아탈란타", 2930: "인테르", 113: "밀란"}
        for identifier, (original, previous, _) in correction.CORRECTIONS.items():
            self.db.execute("INSERT INTO teams VALUES (?, ?, ?, ?, ?)",
                            (identifier, original, original, previous, short_names[identifier]))
        self.db.commit()
        before = self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall()
        correction.migrate_data(self.connection)
        correction.migrate_data(self.connection)
        expected = [(row[0], row[1], row[2], correction.CORRECTIONS[row[0]][2] if row[0] in correction.CORRECTIONS else row[3], row[4])
                    for row in before]
        self.assertEqual(self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall(), expected)
        # 새 이름 이외의 중간 수정 값이 있으면 덮어쓰지 않아요.
        self.db.execute("UPDATE teams SET name_ko='별도 수정' WHERE team_id=113")
        self.db.commit()
        before_conflict = self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall()
        with self.assertRaises(ValueError):
            correction.migrate_data(self.connection)
        self.assertEqual(self.db.execute("SELECT * FROM teams ORDER BY team_id").fetchall(), before_conflict)

    def test_seed_has_reviewed_count_and_preserves_source_spelling(self):
        data = migration.reviewed_names()
        self.assertEqual(len(data["teams"]), 452)
        self.assertEqual(len(data["players"]), 12571)
        self.assertEqual(data["teams"][275], "필라델피아 유니언")
        self.assertEqual(data["players"][997], "해리 케인")


if __name__ == "__main__":
    unittest.main()
