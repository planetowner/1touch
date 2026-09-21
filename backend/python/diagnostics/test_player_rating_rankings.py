"""운영 DB 대신 메모리 DB에서 실제 집계·저장·조회 SQL을 검증해요."""
from contextlib import contextmanager
from decimal import Decimal
import re
import sqlite3
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

with patch("mysql.connector.pooling.MySQLConnectionPool") as pool:
    pool.return_value.get_connection.side_effect = AssertionError("Operational DB access in isolated tests")
    from one_touch_loader.loaders import player_rating_rankings_loader as loader
    from one_touch_loader.api.repos import player_rankings_repo as repo
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.main import create_app


def convert_row(row):
    if row is None:
        return None
    result = dict(row)
    for key in ("rating_sum", "percentile_score"):
        if key in result and result[key] is not None:
            # MySQL의 DECIMAL 반환형을 메모리 DB에서도 맞춰요.
            places = "0.01" if key == "rating_sum" else "0.0000000001"
            result[key] = Decimal(str(result[key])).quantize(Decimal(places))
    return result


class MemoryCursor:
    def __init__(self, database):
        self.cursor = database.cursor()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.cursor.close()

    def execute(self, sql, params=()):
        self.cursor.execute(self.sql(sql), params)

    @staticmethod
    def sql(sql):
        sql = sql.replace("%s", "?").replace(" FOR UPDATE", "")
        sql = sql.replace("ON DUPLICATE KEY UPDATE", "ON CONFLICT DO UPDATE SET")
        return re.sub(r"VALUES\((\w+)\)", r"excluded.\1", sql)

    def executemany(self, sql, rows):
        self.cursor.executemany(self.sql(sql), [
            tuple(str(value) if isinstance(value, Decimal) else value for value in row) for row in rows
        ])

    def fetchone(self):
        return convert_row(self.cursor.fetchone())

    def fetchall(self):
        return [convert_row(row) for row in self.cursor.fetchall()]


class PlayerRatingRankingsTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:", check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.db.create_function("REGEXP", 2, lambda pattern, value: re.search(pattern, value) is not None)
        self.db.create_function("UNIX_TIMESTAMP", 1, lambda value: 1789740000)
        self.addCleanup(self.db.close)
        self.db.executescript("""
            CREATE TABLE competitions (competition_id INTEGER PRIMARY KEY, competition_type TEXT);
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY, competition_id INTEGER, name TEXT);
            CREATE TABLE stages (stage_id INTEGER PRIMARY KEY, season_id INTEGER);
            CREATE TABLE rounds (round_id INTEGER PRIMARY KEY, name TEXT);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY, stage_id INTEGER, round_id INTEGER, state_id INTEGER);
            CREATE TABLE fixture_lineups (fixture_id INTEGER, team_id INTEGER, player_id INTEGER,
                rating NUMERIC, minutes_played INTEGER, match_position_id INTEGER);
            CREATE TABLE players (player_id INTEGER PRIMARY KEY, display_name TEXT, image_path TEXT);
            CREATE TABLE player_rating_references (competition_id INTEGER PRIMARY KEY,
                start_season_name TEXT, end_season_name TEXT, minimum_rated_matches INTEGER,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP);
            CREATE TABLE player_rating_reference_samples (competition_id INTEGER, season_id INTEGER,
                player_id INTEGER, rated_matches INTEGER CHECK(rated_matches >= 1), rating_sum NUMERIC,
                PRIMARY KEY (competition_id, season_id, player_id));
            CREATE TABLE player_rating_scores (competition_id INTEGER, season_id INTEGER, player_id INTEGER,
                rated_matches INTEGER CHECK(rated_matches >= 1), rating_sum NUMERIC, percentile_score NUMERIC,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (season_id, player_id));
            INSERT INTO competitions VALUES (8,'league'), (82,'league'), (301,'league'), (384,'league'), (564,'league'), (999,'domestic_cup');
            INSERT INTO rounds VALUES (1,'1'), (2,'Play-offs');
        """)
        for competition_id in loader.RATING_COMPETITION_IDS:
            for year in range(2017, 2027):
                season_id = competition_id * 10000 + year
                self.db.execute("INSERT INTO seasons VALUES (?,?,?)", (season_id, competition_id, f"{year}/{year + 1}"))
                self.db.execute("INSERT INTO stages VALUES (?,?)", (season_id, season_id))
        for player_id in range(1, 10):
            self.db.execute("INSERT INTO players VALUES (?,?,NULL)", (player_id, f"Player {player_id}"))
        self.sequence = 0
        self.target = 82025
        self.next_season = 82026
        for competition_id in loader.RATING_COMPETITION_IDS:
            for year in range(2017, 2025):
                self.add_matches(competition_id * 10000 + year, 1, rating=6)
                self.add_matches(competition_id * 10000 + year, 2, rating=8)
        self.db.commit()
        for owner, name, replacement in (
            (loader, "transaction", self.transaction),
            (loader, "get_conn", lambda: self),
            (repo, "fetch_all_dict", self.fetch_all),
            (repo, "fetch_one_dict", self.fetch_one),
        ):
            patcher = patch.object(owner, name, replacement)
            patcher.start()
            self.addCleanup(patcher.stop)

    def cursor(self, **kwargs):
        return MemoryCursor(self.db)

    def close(self):
        # 연결 수명만 흉내 내고 실제 메모리 DB는 addCleanup에서 닫아요.
        pass

    @contextmanager
    def transaction(self):
        # 저장 실패 시 기존 결과가 남는지 실제 롤백으로 확인해요.
        self.db.commit()
        try:
            yield self
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

    def fetch_all(self, sql, params=()):
        with self.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()

    def fetch_one(self, sql, params=()):
        rows = self.fetch_all(sql, params)
        return rows[0] if rows else None

    def add_matches(self, season_id, player_id, *, count=10, rating=7, minutes=90, team=1, position=24, state=5, round_id=1):
        for _ in range(count):
            self.sequence += 1
            self.db.execute("INSERT INTO fixtures (fixture_id,stage_id,round_id,state_id) VALUES (?,?,?,?)", (self.sequence, season_id, round_id, state))
            self.db.execute("INSERT INTO fixture_lineups (fixture_id,team_id,player_id,rating,minutes_played,match_position_id) VALUES (?,?,?,?,?,?)", (
                self.sequence, team, player_id, rating, minutes, position,
            ))

    def initialize(self):
        return loader.rebuild_player_rating_scores(apply=True)

    def add_scheduled_rounds(self, season_id, *, total_rounds=38, completed_rounds=0):
        # 기존 경기의 1라운드에 나머지 일정을 더해, 시즌 중반 전후를 실제 상태로 재현해요.
        fixtures = {}
        for number in range(2, total_rounds + 1):
            round_id = season_id * 100 + number
            self.db.execute("INSERT INTO rounds VALUES (?,?)", (round_id, str(number)))
            self.sequence += 1
            self.db.execute("INSERT INTO fixtures (fixture_id,stage_id,round_id,state_id) VALUES (?,?,?,?)",
                            (self.sequence, season_id, round_id, 5 if number <= completed_rounds else 1))
            fixtures[number] = self.sequence
        return fixtures

    def test_early_season_includes_one_rating_in_scores_and_reference(self):
        self.initialize()
        reference = self.fetch_all("SELECT * FROM player_rating_reference_samples")
        self.add_matches(self.target, 3, count=1, rating=7)
        self.add_matches(self.target, 4, count=1, rating=None)
        self.add_matches(self.target, 5, count=1, minutes=0)
        self.add_matches(self.target, 6, count=1, state=2)
        self.add_scheduled_rounds(self.target)
        self.assertEqual(loader.build_player_rating_scores(self.target), 1)
        client, _ = self.client()
        data = client.get(f"/v1/players/rankings?season_id={self.target}").json()
        self.assertEqual(data["total"], 1)
        self.assertEqual(data["items"][0]["rated_matches"], 1)
        self.assertEqual(data["items"][0]["display_score"], 50)
        self.assertEqual(data["reference"]["minimum_rated_matches"], 10)
        self.assertEqual(len(reference) + 1, len(self.fetch_all("SELECT * FROM player_rating_reference_samples")))
        self.assertEqual(data["reference"]["sample_count"], 81)
        self.assertEqual(data["reference"]["early_season_minimum_rated_matches"], 1)

    def test_half_of_rounds_restores_standard_minimum_and_rebuilds_entire_season(self):
        self.initialize()
        self.add_matches(self.target, 3, count=1)
        self.add_matches(self.target, 4, count=10)
        schedule = self.add_scheduled_rounds(self.target, completed_rounds=18)
        self.assertEqual(loader.build_player_rating_scores(self.target), 2)
        # 19라운드 경기가 연기되면 완료 라운드는 여전히 18개예요.
        self.db.execute("UPDATE fixtures SET state_id=10 WHERE fixture_id=?", (schedule[19],))
        self.assertEqual(loader.build_player_rating_scores(self.target), 2)
        self.db.execute("UPDATE fixtures SET state_id=5 WHERE fixture_id=?", (schedule[19],))
        self.assertEqual(loader.build_player_rating_scores(self.target), 1)
        self.assertEqual(self.fetch_one("SELECT player_id FROM player_rating_scores WHERE season_id=%s", (self.target,))["player_id"], 4)
        self.assertEqual(self.fetch_one("SELECT COUNT(*) AS n FROM player_rating_reference_samples WHERE season_id=%s", (self.target,))["n"], 1)

    def test_odd_round_count_rounds_up_and_nonregular_round_does_not_affect_cutoff(self):
        self.add_matches(self.target, 3, count=1)
        self.add_matches(self.target, 3, count=1, round_id=2)
        schedule = self.add_scheduled_rounds(self.target, total_rounds=5, completed_rounds=2)
        with self.cursor() as cur:
            self.assertEqual(loader.minimum_rated_matches_for_season(cur, self.target, 10), 1)
        self.db.execute("UPDATE fixtures SET state_id=5 WHERE fixture_id=?", (schedule[3],))
        with self.cursor() as cur:
            self.assertEqual(loader.minimum_rated_matches_for_season(cur, self.target, 10), 10)

    def test_shared_aggregation_excludes_missing_ratings_unplayed_unfinished_and_nonleague_rounds(self):
        self.add_matches(self.target, 3, count=9)
        self.add_matches(self.target, 3, count=4, rating=None)
        self.add_matches(self.target, 3, count=4, minutes=0)
        self.add_matches(self.target, 3, count=4, state=2)
        self.add_matches(self.target, 3, count=4, state=17)
        self.add_matches(self.target, 3, count=4, round_id=2)
        with self.cursor() as cur:
            self.assertEqual(loader.fetch_rating_aggregates(cur, [self.target], 10), [])
        self.add_matches(self.target, 3, count=1, state=7)
        with self.cursor() as cur:
            row, = loader.fetch_rating_aggregates(cur, [self.target], 10)
        self.assertEqual((row["rated_matches"], row["rating_sum"]), (10, Decimal(70)))

    def test_transfer_position_and_minutes_do_not_split_or_weight_the_player_mean(self):
        self.initialize()
        self.add_matches(self.target, 3, count=5, rating=6, minutes=90)
        self.add_matches(self.target, 3, count=5, rating=8, minutes=1, team=2, position=27, state=8)
        self.assertEqual(loader.build_player_rating_scores(self.target), 1)
        row, = self.fetch_all("SELECT * FROM player_rating_scores WHERE season_id=%s", (self.target,))
        self.assertEqual((row["rated_matches"], row["rating_sum"], row["percentile_score"]), (10, 70, 50))

    def test_reference_includes_target_and_does_not_include_later_seasons(self):
        self.add_matches(self.target, 3, rating=9)
        self.initialize()
        first = self.fetch_one("SELECT * FROM player_rating_scores WHERE season_id=%s", (self.target,))
        self.assertAlmostEqual(float(first["percentile_score"]), 100 * 80.5 / 81)
        self.add_matches(self.next_season, 4, rating=10.08)
        loader.build_player_rating_scores(self.next_season)
        self.assertEqual(first, self.fetch_one("SELECT * FROM player_rating_scores WHERE season_id=%s", (self.target,)))
        self.assertLess(self.fetch_one("SELECT percentile_score FROM player_rating_scores WHERE player_id=4")["percentile_score"], 100)

    def test_missing_league_season_does_not_save_partial_reference(self):
        self.db.execute("DELETE FROM seasons WHERE season_id=822017")
        with self.assertRaisesRegex(ValueError, "all five"):
            self.initialize()
        self.assertEqual(self.fetch_all("SELECT * FROM player_rating_references"), [])

    def test_uninitialized_or_unknown_season_is_rejected(self):
        for season_id in (self.target, 123):
            with self.assertRaises(ValueError):
                loader.build_player_rating_scores(season_id)
        self.initialize()
        with self.assertRaises(ValueError):
            loader.build_player_rating_scores(123)

    def test_old_fixed_reference_is_not_presented_as_cumulative_scores(self):
        self.db.execute("""INSERT INTO player_rating_references
            (competition_id,start_season_name,end_season_name,minimum_rated_matches)
            VALUES (8,'2020/2021','2024/2025',10)""")
        self.assertIsNone(repo.get_player_rankings(self.target))
        with self.assertRaisesRegex(ValueError, "rebuild"):
            loader.build_player_rating_scores(self.target)

    def test_rebuild_excludes_before_2017_and_other_competitions(self):
        for season_id, competition, name in ((82016, 8, '2016/2017'), (9992025, 999, '2025/2026')):
            self.db.execute("INSERT INTO seasons VALUES (?,?,?)", (season_id, competition, name))
            self.db.execute("INSERT INTO stages VALUES (?,?)", (season_id, season_id))
            self.add_matches(season_id, 9, rating=10)
        report = self.initialize()
        self.assertEqual(report['scores'], 80)
        self.assertEqual(report['seasons'][0]['season_name'], '2017/2018')
        self.assertEqual(self.fetch_all("SELECT * FROM player_rating_scores WHERE player_id=9"), [])

    def test_all_five_leagues_use_one_reference_and_keep_transfer_records_separate(self):
        for competition in loader.RATING_COMPETITION_IDS:
            self.add_matches(competition * 10000 + 2025, 3, rating=7)
        self.initialize()
        rows = self.fetch_all("SELECT competition_id, percentile_score FROM player_rating_scores WHERE player_id=3")
        self.assertEqual(len(rows), 5)
        self.assertEqual({row["percentile_score"] for row in rows}, {50})
        data = repo.get_player_rankings(self.target)
        self.assertEqual(data["reference"]["sample_count"], 85)
        self.assertEqual(data["reference"]["end_season_name"], "2025/2026")

    def test_refresh_removes_ineligible_player_and_preserves_other_seasons(self):
        self.initialize()
        for season in (self.target, self.next_season):
            self.add_matches(season, 3)
            loader.build_player_rating_scores(season)
        self.db.execute("UPDATE fixture_lineups SET rating=NULL WHERE fixture_id=(SELECT MIN(fixture_id) FROM fixtures WHERE stage_id=?)", (self.target,))
        self.assertEqual(loader.build_player_rating_scores(self.target), 0)
        self.assertEqual([row["season_id"] for row in self.fetch_all("SELECT * FROM player_rating_scores WHERE player_id=3")], [self.next_season])

    def test_failed_replacement_rolls_back_deleted_scores(self):
        self.initialize()
        self.add_matches(self.target, 3)
        loader.build_player_rating_scores(self.target)
        before = self.fetch_all("SELECT * FROM player_rating_scores")
        reference = self.fetch_all("SELECT * FROM player_rating_reference_samples")
        with patch.object(MemoryCursor, "executemany", side_effect=RuntimeError("insert failed")):
            with self.assertRaisesRegex(RuntimeError, "insert failed"):
                loader.build_player_rating_scores(self.target)
        self.assertEqual(before, self.fetch_all("SELECT * FROM player_rating_scores"))
        self.assertEqual(reference, self.fetch_all("SELECT * FROM player_rating_reference_samples"))

    def test_correction_refreshes_other_leagues_and_later_seasons_but_preserves_earlier_seasons(self):
        self.add_matches(self.target, 3, rating=6)
        self.add_matches(5642025, 4, rating=7.5)
        self.add_matches(self.next_season, 5, rating=7.5)
        self.initialize()
        earlier = self.fetch_all("SELECT * FROM player_rating_scores WHERE season_id=82024")
        before = {row["player_id"]: row["percentile_score"] for row in self.fetch_all("SELECT * FROM player_rating_scores WHERE player_id IN (4,5)")}
        self.db.execute("UPDATE fixture_lineups SET rating=9 WHERE fixture_id IN (SELECT fixture_id FROM fixtures WHERE stage_id=?)", (self.target,))
        loader.build_player_rating_scores(self.target)
        after = {row["player_id"]: row["percentile_score"] for row in self.fetch_all("SELECT * FROM player_rating_scores WHERE player_id IN (4,5)")}
        self.assertLess(after[4], before[4])
        self.assertLess(after[5], before[5])
        self.assertEqual(earlier, self.fetch_all("SELECT * FROM player_rating_scores WHERE season_id=82024"))

    def test_check_mode_does_not_write_or_lock_and_rebuild_is_repeatable(self):
        with patch.object(MemoryCursor, "executemany", side_effect=AssertionError("write in check")), patch.object(loader, "_lock_rating_pool") as lock:
            report = loader.rebuild_player_rating_scores()
        lock.assert_not_called()
        self.assertFalse(report["apply"])
        self.assertEqual(report["scores"], 80)
        self.assertEqual(self.fetch_all("SELECT * FROM player_rating_references"), [])
        self.initialize()
        scores = self.fetch_all("SELECT * FROM player_rating_scores")
        self.initialize()
        self.assertEqual(scores, self.fetch_all("SELECT * FROM player_rating_scores"))

    def client(self):
        app = create_app()
        app.dependency_overrides[get_user_id] = lambda: 1
        client = TestClient(app)
        self.addCleanup(client.close)
        return client, app

    def test_api_paginates_original_mean_order_and_returns_reference_and_score(self):
        self.initialize()
        for player, rating in ((3, 7), (4, 7.5), (5, 7.5)):
            self.add_matches(self.target, player, rating=rating)
        loader.build_player_rating_scores(self.target)
        client, _ = self.client()
        response = client.get(f"/v1/players/rankings?season_id={self.target}&limit=2&offset=1")
        self.assertEqual(response.status_code, 200, response.text)
        data = response.json()
        self.assertEqual(data["total"], 3)
        self.assertEqual(data["method"], "cumulative_all_leagues_percentile")
        self.assertEqual([row["player_id"] for row in data["items"]], [5, 3])
        self.assertEqual([row["rank"] for row in data["items"]], [1, 3])
        self.assertEqual([row["display_score"] for row in data["items"]], [50.3, 48.8])
        self.assertAlmostEqual(data["items"][0]["percentile_score"], 4200 / 83)
        stored = self.fetch_one("SELECT percentile_score FROM player_rating_scores WHERE season_id=%s AND player_id=5", (self.target,))
        self.assertAlmostEqual(float(stored["percentile_score"]), 4200 / 83)
        self.assertEqual(data["reference"]["sample_count"], 83)
        self.assertEqual(data["reference"]["competition_ids"], [8, 82, 301, 384, 564])
        self.assertEqual(data["reference"]["start_season_name"], "2017/2018")
        self.assertEqual(data["reference"]["end_season_name"], "2025/2026")
        self.assertTrue(data["reference"]["updated_at"].endswith("Z"))
        self.assertNotIn("frozen_at", data["reference"])
        self.assertNotIn("rating_sum", data["items"][0])
        self.assertEqual(client.get(f"/v1/players/rankings?season_id={self.target}&offset=99").json()["items"], [])

    def test_api_unknown_reference_empty_scores_validation_auth_and_openapi(self):
        client, app = self.client()
        self.assertEqual(client.get(f"/v1/players/rankings?season_id={self.target}").status_code, 404)
        self.initialize()
        response = client.get(f"/v1/players/rankings?season_id={self.target}")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["items"], [])
        for query in ("", "season_id=0", "season_id=-1", f"season_id={self.target}&limit=101", f"season_id={self.target}&offset=-1"):
            with self.subTest(query=query):
                self.assertEqual(client.get(f"/v1/players/rankings?{query}").status_code, 422)
        schema = client.get("/openapi.json").json()
        self.assertEqual(schema["paths"]["/v1/players/rankings"]["get"]["security"], [{"HTTPBearer": []}])
        app.dependency_overrides.clear()
        response = client.get(f"/v1/players/rankings?season_id={self.target}")
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.headers["WWW-Authenticate"], "Bearer")

    def test_cli_routes_rebuild_and_season_ids_to_the_selected_loader(self):
        from one_touch_loader import cli

        for args, apply in (([], False), (["--check"], False), (["--apply"], True)):
            with patch.object(cli, "rebuild_player_rating_scores", return_value={}) as run:
                with patch("sys.argv", ["cli", "player-rankings", "rebuild", *args]), patch("builtins.print"):
                    cli.main()
                run.assert_called_once_with(apply=apply)
        with patch.object(cli, "build_player_rating_scores", return_value=10) as run:
            with patch("sys.argv", ["cli", "player-rankings", "build-scores", "25583"]), patch("builtins.print"):
                cli.main()
            run.assert_called_once_with(25583)


if __name__ == "__main__":
    unittest.main()
