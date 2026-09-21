"""실제 경기 저장 경로에서 종료·정정·실패 시 시즌 랭킹을 함께 확인해요."""
from datetime import datetime
import sqlite3
import unittest
from unittest.mock import patch

from diagnostics import test_player_rating_rankings as ranking_tests
from diagnostics.test_fixture_details import _SqliteCursor
from one_touch_loader.loaders import fixture_details_loader as details
from one_touch_loader.loaders import live_fixtures_loader as live
from one_touch_loader.loaders import player_rating_rankings_loader as rankings


class RefreshCursor(ranking_tests.MemoryCursor):
    def __init__(self, database, *, dictionary=False):
        super().__init__(database)
        self.dictionary = dictionary

    def execute(self, sql, params=()):
        super().execute(_SqliteCursor._sql(sql), params)

    def executemany(self, sql, rows):
        super().executemany(_SqliteCursor._sql(sql), rows)

    def fetchone(self):
        row = self.cursor.fetchone()
        if self.dictionary:
            return ranking_tests.convert_row(row)
        return tuple(row) if row is not None else None

    def fetchall(self):
        return [ranking_tests.convert_row(row) if self.dictionary else tuple(row) for row in self.cursor.fetchall()]


class PlayerRatingRefreshTests(unittest.TestCase):
    setUp_rankings = ranking_tests.PlayerRatingRankingsTests.setUp
    transaction = ranking_tests.PlayerRatingRankingsTests.transaction
    add_matches = ranking_tests.PlayerRatingRankingsTests.add_matches
    add_scheduled_rounds = ranking_tests.PlayerRatingRankingsTests.add_scheduled_rounds
    freeze = ranking_tests.PlayerRatingRankingsTests.freeze

    def cursor(self, **kwargs):
        return RefreshCursor(self.db, **kwargs)

    def fetch_all(self, sql, params=()):
        with self.cursor(dictionary=True) as cur:
            cur.execute(sql, params)
            return cur.fetchall()

    def fetch_one(self, sql, params=()):
        rows = self.fetch_all(sql, params)
        return rows[0] if rows else None

    def setUp(self):
        from contextlib import nullcontext
        role_refresh = patch.object(details.squad_roles, 'refresh_squad_roles_after_fixture',
                                    side_effect=lambda *args, **kwargs: nullcontext())
        role_refresh.start()
        self.addCleanup(role_refresh.stop)
        self.setUp_rankings()
        for name in ("home_score", "away_score", "home_penalty_score", "away_penalty_score"):
            self.db.execute(f"ALTER TABLE fixtures ADD COLUMN {name} INTEGER")
        for name, kind in (("lineup_type_id", "INTEGER"), ("formation_field", "TEXT"), ("jersey_number", "INTEGER")):
            self.db.execute(f"ALTER TABLE fixture_lineups ADD COLUMN {name} {kind}")
        # 이 시나리오는 평점만 바꿔요. 다른 상세 컬렉션은 빈 응답의 교체만 확인해요.
        for table in ("fixture_events", "fixture_team_stats", "fixture_player_stats",
                      "fixture_formations", "fixture_coaches", "fixture_pressures"):
            self.db.execute(f"CREATE TABLE {table} (fixture_id INTEGER)")
        self.db.executescript("""
            CREATE TABLE fixture_states (state_id INTEGER PRIMARY KEY, state_code TEXT, name TEXT);
            CREATE TABLE fixture_clock (
                fixture_id INTEGER PRIMARY KEY, period_type_id INTEGER, counts_from INTEGER,
                period_length INTEGER, minutes INTEGER, seconds INTEGER CHECK(seconds < 60),
                ticking INTEGER, time_added INTEGER, sampled_at TEXT
            );
        """)
        for owner in (details, live):
            patcher = patch.object(owner, "transaction", self.transaction)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.freeze()
        # 기반 픽스처의 INSERT는 추가한 점수 필드도 명시하도록 이 테스트에서만 맞춰요.
        self.seed_matches(self.target, count=9)
        self.fixture_id = self.sequence + 1
        self.sequence = self.fixture_id
        self.db.execute("INSERT INTO fixtures (fixture_id,stage_id,round_id,state_id) VALUES (?,?,1,2)",
                        (self.fixture_id, self.target))
        self.db.commit()

    def seed_matches(self, season_id, *, count):
        for _ in range(count):
            self.sequence += 1
            self.db.execute("INSERT INTO fixtures (fixture_id,stage_id,round_id,state_id) VALUES (?,?,1,5)",
                            (self.sequence, season_id))
            self.db.execute("""INSERT INTO fixture_lineups
                (fixture_id,team_id,player_id,rating,minutes_played,match_position_id) VALUES (?,10,3,6,90,27)""",
                            (self.sequence,))

    def payload(self, *, state=5, rating=8, seconds=0):
        return {
            "id": self.fixture_id, "state_id": state,
            "state": {"id": state, "state": str(state), "name": str(state)},
            "participants": [{"id": 10, "meta": {"location": "home"}},
                             {"id": 20, "meta": {"location": "away"}}],
            "scores": [{"participant_id": 10, "type_id": 1525, "score": {"goals": 1}},
                       {"participant_id": 20, "type_id": 1525, "score": {"goals": 0}}],
            "periods": [{"type_id": 2, "counts_from": 45, "period_length": 45, "minutes": 90,
                         "seconds": seconds, "ticking": False, "sort_order": 2, "time_added": 0}],
            "lineups": [{"id": 1, "team_id": 10, "player_id": 3, "player": {"id": 3}, "type_id": 11,
                         "formation_field": None, "jersey_number": 9, "position_id": 27,
                         "details": [{"type_id": 119, "data": {"value": 90}},
                                     {"type_id": 118, "data": {"value": rating}}]}],
            "events": [], "statistics": [], "formations": [], "coaches": [], "pressure": [],
        }

    def store(self, **kwargs):
        live.store_live_fixture(self.payload(**kwargs), 10, 20, datetime(2026, 9, 18))

    def score(self):
        return self.fetch_one("SELECT * FROM player_rating_scores WHERE season_id=%s AND player_id=3", (self.target,))

    def test_live_match_only_enters_rankings_after_tenth_rated_match_finishes(self):
        with patch.object(rankings, "_write_player_rating_scores", wraps=rankings._write_player_rating_scores) as score:
            self.store(state=2)
            score.assert_not_called()
            self.assertIsNone(self.score())
            self.store(state=5)
            self.assertEqual(score.call_count, 1)
        row = self.score()
        self.assertEqual((row["rated_matches"], row["rating_sum"], row["percentile_score"]), (10, 62, 50))

    def test_early_season_first_finished_rating_enters_and_missing_rating_removes_player(self):
        self.db.execute("DELETE FROM fixture_lineups WHERE fixture_id IN (SELECT fixture_id FROM fixtures WHERE stage_id=?)",
                        (self.target,))
        self.add_scheduled_rounds(self.target)
        self.store(state=2)
        self.assertIsNone(self.score())
        self.store()
        self.assertEqual(self.score()["rated_matches"], 1)
        self.store(rating=None)
        self.assertIsNone(self.score())

    def test_last_match_of_nineteenth_completed_round_applies_ten_matches_to_all_players(self):
        schedule = self.add_scheduled_rounds(self.target, completed_rounds=18)
        self.db.execute("UPDATE fixtures SET round_id=? WHERE fixture_id=?",
                        (self.target * 100 + 19, self.fixture_id))
        self.db.execute("UPDATE fixtures SET state_id=5 WHERE fixture_id=?", (schedule[19],))
        self.db.execute("""INSERT INTO fixture_lineups (fixture_id,team_id,player_id,rating,minutes_played,match_position_id)
            SELECT fixture_id,10,4,7,90,27 FROM fixtures WHERE stage_id=? AND round_id=1 LIMIT 1""", (self.target,))
        self.assertEqual(rankings.build_player_rating_scores(self.target), 2)
        self.store(state=2)
        self.assertEqual(self.fetch_one("SELECT COUNT(*) AS n FROM player_rating_scores")["n"], 2)
        self.store()
        self.assertEqual(self.score()["rated_matches"], 10)
        self.assertEqual(self.fetch_one("SELECT COUNT(*) AS n FROM player_rating_scores")["n"], 1)

    def test_finished_rating_correction_refreshes_score_without_changing_reference(self):
        reference = self.fetch_all("SELECT * FROM player_rating_reference_samples")
        self.store()
        self.store(rating=6)
        self.assertEqual(self.score()["percentile_score"], 25)
        self.assertEqual(reference, self.fetch_all("SELECT * FROM player_rating_reference_samples"))

    def test_missing_or_removed_rating_removes_newly_ineligible_player(self):
        self.store()
        self.store(rating=None)
        self.assertIsNone(self.score())
        self.store()
        details.replace_fixture_detail_rows(self.fixture_id, {"lineups": []})
        self.assertIsNone(self.score())

    def test_finished_state_reversal_removes_match_from_ranking(self):
        self.store()
        self.store(state=2)
        # 이 픽스처는 유일한 라운드예요. 종료 취소로 중반 전이 되면 나머지 9경기는 남아요.
        self.assertEqual(self.score()["rated_matches"], 9)
        self.assertEqual(self.score()["rating_sum"], 54)

    def test_league_without_reference_and_nonregular_round_still_save_match(self):
        with patch.object(rankings, "_write_player_rating_scores", wraps=rankings._write_player_rating_scores) as score:
            self.db.execute("UPDATE fixtures SET stage_id=5642025 WHERE fixture_id=?", (self.fixture_id,))
            self.store()
            score.assert_not_called()
            self.assertEqual(self.fetch_one("SELECT state_id FROM fixtures WHERE fixture_id=%s", (self.fixture_id,))["state_id"], 5)
            self.db.execute("UPDATE fixtures SET stage_id=?,round_id=2 WHERE fixture_id=?", (self.target, self.fixture_id))
            self.store()
            score.assert_not_called()
        self.assertEqual(self.fetch_one("SELECT COUNT(*) AS n FROM player_rating_references")["n"], 1)

    def test_team_statistics_only_do_not_recalculate_player_rankings(self):
        self.store()
        with patch.object(rankings, "_write_player_rating_scores") as score:
            details.replace_fixture_detail_rows(self.fixture_id, {"team_stats": []})
            score.assert_not_called()

    def test_ranking_failure_rolls_back_final_state_rating_and_clock_so_live_can_retry(self):
        with patch.object(rankings, "_write_player_rating_scores", side_effect=RuntimeError("score write failed")):
            with self.assertRaisesRegex(RuntimeError, "score write failed"):
                self.store()
        self.assertEqual(self.fetch_one("SELECT state_id FROM fixtures WHERE fixture_id=%s", (self.fixture_id,))["state_id"], 2)
        self.assertEqual(self.fetch_one("SELECT COUNT(*) AS n FROM fixture_lineups WHERE fixture_id=%s", (self.fixture_id,))["n"], 0)
        self.assertEqual(self.fetch_one("SELECT COUNT(*) AS n FROM fixture_clock")["n"], 0)
        self.store()
        self.assertIsNotNone(self.score())

    def test_invalid_match_write_preserves_existing_score_and_does_not_recalculate(self):
        self.store()
        before = self.score()
        with patch.object(rankings, "_write_player_rating_scores") as score:
            with self.assertRaises(sqlite3.IntegrityError):
                self.store(rating=6, seconds=60)
            score.assert_not_called()
        self.assertEqual(before, self.score())

    def test_manual_fixture_detail_collection_uses_same_refresh(self):
        self.db.execute("UPDATE fixtures SET state_id=5 WHERE fixture_id=?", (self.fixture_id,))
        with patch.object(details, "_load_scope", return_value=[self.fixture_id]), patch.object(details, "SportmonksClient") as client:
            client.return_value.get_fixture_details.return_value = self.payload()
            result = details.collect_fixture_details(self.fixture_id)
        self.assertEqual(result["fixtures"], 1)
        self.assertEqual(self.score()["rated_matches"], 10)


if __name__ == "__main__":
    unittest.main()
