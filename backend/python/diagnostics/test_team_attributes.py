from __future__ import annotations

import re
import sqlite3
import unittest
from contextlib import contextmanager
from unittest.mock import patch

import numpy as np
import pandas as pd

from one_touch_loader.loaders import team_attribute_regression_trainer as trainer
from one_touch_loader.loaders import team_attribute_scores_loader as scores
from one_touch_loader.loaders import team_attribute_training_features_loader as loader
from one_touch_loader.loaders.team_attribute_common import ALL_FEATURES, FEATURE_GROUPS


class PartialFixtureStatisticsTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.row_factory = sqlite3.Row
        self.db.create_function("regexp", 2, lambda pattern, value: bool(re.search(pattern, value)))
        self.db.executescript("""
            CREATE TABLE seasons (season_id INTEGER, competition_id INTEGER);
            CREATE TABLE stages (stage_id INTEGER, season_id INTEGER);
            CREATE TABLE rounds (round_id INTEGER, name TEXT);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY, stage_id INTEGER,
                round_id INTEGER, state_id INTEGER, home_team_id INTEGER, away_team_id INTEGER);
            CREATE TABLE fixture_stat_types (stat_type_id INTEGER PRIMARY KEY, code TEXT UNIQUE);
            CREATE TABLE fixture_team_stats (fixture_id INTEGER, team_id INTEGER,
                stat_type_id INTEGER, stat_value REAL NOT NULL,
                PRIMARY KEY (fixture_id, team_id, stat_type_id));
            CREATE TABLE standings (season_id INTEGER, team_id INTEGER,
                won INTEGER, draw INTEGER, lost INTEGER, points REAL);
            INSERT INTO seasons VALUES (10, 8);
            INSERT INTO stages VALUES (100, 10);
            INSERT INTO rounds VALUES (1000, '1');
            INSERT INTO standings VALUES (10, 1, 20, 0, 18, 60), (10, 2, 10, 0, 28, 30);
        """)
        # SQLite의 정수 나눗셈 차이 때문에 points를 REAL로 두어 MySQL의 소수 나눗셈을 재현해요.

    def tearDown(self):
        self.db.close()

    def add_stats(self, fixture_id, team_id, stats):
        self.db.execute("INSERT OR IGNORE INTO fixtures VALUES (?, 100, 1000, 5, 1, 2)", (fixture_id,))
        for code, value in stats.items():
            self.db.execute("INSERT OR IGNORE INTO fixture_stat_types (code) VALUES (?)", (code,))
            type_id = self.db.execute("SELECT stat_type_id FROM fixture_stat_types WHERE code=?", (code,)).fetchone()[0]
            self.db.execute("INSERT INTO fixture_team_stats VALUES (?, ?, ?, ?)", (fixture_id, team_id, type_id, value))

    def feature_row(self, team_id=1):
        sql = loader._build_feature_query([10]).replace("%s", "?")
        rows = self.db.execute(sql, (10,)).fetchall()
        return next(dict(row) for row in rows if row["team_id"] == team_id)

    def test_defending_uses_30_common_games_instead_of_38_standing_games(self):
        for fixture_id in range(1, 39):
            stats = {"goals": 2, "shots-on-target": 4, "shots-insidebox": 10, "dangerous-attacks": 50}
            if fixture_id <= 30:
                stats["big-chances-created"] = 2
            else:
                stats["goals"] = 99
            self.add_stats(fixture_id, 2, stats)
        row = self.feature_row()
        self.assertAlmostEqual(row["points_per_match"], 60 / 38)
        self.assertEqual(row["goals_against_per_match"], 2)
        self.assertEqual(row["big_chances_against_per_match"], 2)
        self.assertEqual(row["shots_on_target_against_per_match"], 4)
        self.assertEqual(row["dangerous_attacks_against_per_match"], 50)

    def test_provided_zero_counts_but_missing_stat_does_not(self):
        self.add_stats(1, 2, {"goals": 0, "shots-on-target": 0, "shots-insidebox": 0,
                              "big-chances-created": 0, "dangerous-attacks": 0})
        self.add_stats(2, 2, {"goals": 8, "shots-on-target": 8, "shots-insidebox": 8, "dangerous-attacks": 8})
        row = self.feature_row()
        for feature in FEATURE_GROUPS["defending"]:
            self.assertEqual(row[feature], 0)

    def test_no_common_game_keeps_entire_group_null(self):
        self.add_stats(1, 2, {"goals": 2, "shots-on-target": 4, "shots-insidebox": 10, "dangerous-attacks": 50})
        self.add_stats(2, 2, {"big-chances-created": 3})
        row = self.feature_row()
        self.assertTrue(all(row[feature] is None for feature in FEATURE_GROUPS["defending"]))

    def test_passes_and_successes_must_come_from_same_games(self):
        self.add_stats(1, 1, {"ball-possession": 50, "ball-safe": 100, "passes": 100, "successful-passes": 80})
        self.add_stats(2, 1, {"ball-possession": 80, "ball-safe": 999, "passes": 900})
        self.add_stats(3, 1, {"ball-possession": 90, "ball-safe": 999, "successful-passes": 100})
        row = self.feature_row()
        self.assertEqual(row["ball_possession_avg"], 50)
        self.assertEqual(row["passes_per_match"], 100)
        self.assertAlmostEqual(row["pass_accuracy"], 0.8)
        self.assertIsNone(row["key_passes_per_match"])

    def test_success_rate_is_ratio_of_sums_not_mean_of_match_rates(self):
        for fixture_id, attempts, successes in [(1, 2, 1), (2, 100, 80)]:
            self.add_stats(fixture_id, 1, {"ball-possession": 50, "ball-safe": 100,
                                         "passes": attempts, "successful-passes": successes})
        row = self.feature_row()
        self.assertAlmostEqual(row["pass_accuracy"], 81 / 102)
        self.assertEqual(row["passes_per_match"], 51)

    def test_zero_denominator_stays_unavailable(self):
        self.add_stats(1, 1, {"ball-possession": 0, "ball-safe": 0, "passes": 0, "successful-passes": 0})
        row = self.feature_row()
        self.assertEqual(row["passes_per_match"], 0)
        self.assertIsNone(row["pass_accuracy"])

    def test_defending_reads_opponent_stats_without_score_or_player_fallback(self):
        for team_id, goals in [(1, 2), (2, 5)]:
            self.add_stats(1, team_id, {"goals": goals, "shots-on-target": 6, "shots-insidebox": 9,
                                      "big-chances-created": 3, "dangerous-attacks": 50})
        self.assertEqual(self.feature_row(1)["goals_against_per_match"], 5)
        self.assertEqual(self.feature_row(2)["goals_against_per_match"], 2)

    def test_standing_without_statistics_has_null_features(self):
        row = self.feature_row()
        self.assertTrue(all(row[feature] is None for feature in ALL_FEATURES))


def feature_frame():
    rows = []
    for team_id in range(1, 8):
        row = dict(competition_id=8, season_id=10, team_id=team_id,
                   points_per_match=team_id * 10 / 38)
        row.update({feature: float(10 - team_id if feature in trainer.LOWER_IS_BETTER_FEATURES else team_id)
                    for feature in ALL_FEATURES})
        rows.append(row)
    return pd.DataFrame(rows)


class AttributeModelTests(unittest.TestCase):
    def test_group_with_no_data_stays_empty_instead_of_getting_neutral_scores(self):
        df = feature_frame()
        df["key_passes_per_match"] = np.nan
        chance = trainer._add_competition_season_zscores(df, FEATURE_GROUPS["chance_creation"])
        self.assertTrue(chance.empty)
        self.assertEqual(len(trainer._add_competition_season_zscores(df, FEATURE_GROUPS["defending"])), 7)

    def test_group_missing_value_does_not_affect_other_groups(self):
        df = feature_frame()
        df.loc[0, "key_passes_per_match"] = np.nan
        chance = trainer._add_competition_season_zscores(df, FEATURE_GROUPS["chance_creation"])
        defending = trainer._add_competition_season_zscores(df, FEATURE_GROUPS["defending"])
        self.assertEqual(len(chance), 6)
        self.assertEqual(len(defending), 7)
        self.assertNotIn(1, chance["team_id"].tolist())
        self.assertAlmostEqual(chance["corners_per_match_z"].mean(), 0)

    def test_existing_zscore_direction_and_constant_values_are_preserved(self):
        df = feature_frame()
        df["goals_against_per_match"] = [7, 6, 5, 4, 3, 2, 1]
        df["dangerous_attacks_against_per_match"] = 0
        result = trainer._add_competition_season_zscores(df, FEATURE_GROUPS["defending"])
        np.testing.assert_allclose(result["goals_against_per_match_z"], [-1.5, -1, -.5, 0, .5, 1, 1.5])
        self.assertTrue((result["dangerous_attacks_against_per_match_z"] == 0).all())

    def test_existing_weight_conversion_and_display_formula_are_preserved(self):
        positive, weights = trainer._weights_from_coefficients(np.array([-1, 2, 6]))
        self.assertEqual(positive, [0, 2, 6])
        self.assertEqual(weights, [0, .25, .75])
        self.assertEqual(scores._to_display_score(0), 50)
        self.assertEqual(scores._to_display_score(1), 65)
        self.assertEqual(scores._to_display_score(-10), 5)
        self.assertEqual(scores._to_display_score(10), 95)

    def test_training_uses_group_specific_rows_and_keeps_ridge_settings(self):
        df = feature_frame()
        df.loc[0, "key_passes_per_match"] = np.nan
        with patch.object(trainer, "_fetch_training_dataframe", return_value=df), \
             patch.object(trainer, "_persist_model_atomically", return_value=44) as persist, \
             patch.object(trainer, "Ridge", wraps=trainer.Ridge) as ridge:
            self.assertEqual(trainer.train_team_attribute_regression_weights(), 44)
        results = persist.call_args.kwargs["notes"]["group_results"]
        self.assertEqual(results["chance_creation"]["rows_used"], 6)
        self.assertEqual(results["defending"]["rows_used"], 7)
        for result in results.values():
            self.assertEqual(set(result), {"rows_used", "intercept", "r2_score"})
        self.assertEqual(ridge.call_count, 5)
        for call in ridge.call_args_list:
            self.assertEqual(call.kwargs, {"alpha": 1.0, "fit_intercept": True})

    def test_scoring_removes_stale_missing_group_and_preserves_other_scopes(self):
        db = sqlite3.connect(":memory:")
        self.addCleanup(db.close)
        db.execute("""CREATE TABLE team_attribute_group_scores (
            model_id INTEGER, season_id INTEGER, team_id INTEGER,
            attribute_group TEXT, display_score_0_100 REAL,
            PRIMARY KEY (model_id, team_id, season_id, attribute_group))""")
        old_rows = [(1, 10, 1, "chance_creation", 65),
                    (1, 20, 1, "chance_creation", 65),
                    (2, 10, 1, "chance_creation", 65)]
        db.executemany("INSERT INTO team_attribute_group_scores VALUES (?, ?, ?, ?, ?)", old_rows)
        db.commit()

        class Cursor:
            def __enter__(self):
                return self
            def __exit__(self, *args):
                return False
            def execute(self, statement, params):
                db.execute(statement.replace("%s", "?"), params)
            def executemany(self, statement, rows):
                statement = statement.replace("%s", "?")
                db.executemany(statement, rows)

        class Connection:
            def cursor(self):
                return Cursor()

        @contextmanager
        def transaction():
            with db:
                yield Connection()

        df = feature_frame()
        df.loc[0, "key_passes_per_match"] = np.nan
        weights = {group: {feature: 1 / len(features) for feature in features}
                   for group, features in FEATURE_GROUPS.items()}
        # 가중치가 0이어도 필수 항목이 없으면 그 영역은 미산출해야 해요.
        weights["chance_creation"]["key_passes_per_match"] = 0
        with patch.object(scores, "_fetch_weights", return_value=weights), \
             patch.object(scores, "fetch_team_attribute_feature_dataframe", return_value=df), \
             patch.object(scores, "transaction", transaction):
            self.assertEqual(scores.build_team_attribute_group_scores(1, [10]), 34)
        self.assertEqual(db.execute("SELECT COUNT(*) FROM team_attribute_group_scores WHERE model_id=1 AND season_id=10 AND team_id=1 AND attribute_group='chance_creation'").fetchone()[0], 0)
        self.assertEqual(db.execute("SELECT COUNT(*) FROM team_attribute_group_scores WHERE model_id=1 AND season_id=10 AND team_id=1 AND attribute_group='defending'").fetchone()[0], 1)
        self.assertEqual(db.execute("SELECT COUNT(*) FROM team_attribute_group_scores").fetchone()[0], 36)



class MinimalFeatureStorageTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.addCleanup(self.db.close)
        self.db.executescript(f"""
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY, competition_id INTEGER);
            CREATE TABLE team_attribute_features (
                team_id INTEGER, season_id INTEGER, points_per_match REAL,
                {', '.join(feature + ' REAL' for feature in ALL_FEATURES)},
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (team_id, season_id));
            INSERT INTO seasons VALUES (10, 82), (20, 8);
        """)

    def save_rows(self, sql, rows):
        # 저장 컬럼과 바인딩은 실제 SQL을 쓰고, UPSERT 문법만 SQLite에 맞춰요.
        sql = sql.replace("%s", "?").replace(
            "ON DUPLICATE KEY UPDATE", "ON CONFLICT(team_id, season_id) DO UPDATE SET",
        )
        sql = re.sub(r"VALUES\((\w+)\)", r"excluded.\1", sql)
        self.db.executemany(sql, rows)

    def fetch_rows(self, sql, params=()):
        return self.db.execute(sql.replace("%s", "?"), params).fetchall()

    def test_rebuild_replaces_old_value_with_null_and_keeps_provided_zero(self):
        first = (10, 1, 2.0, *([1.0] * len(ALL_FEATURES)))
        second = (10, 1, 2.0, None, 0.0, *([1.0] * (len(ALL_FEATURES) - 2)))
        with patch.object(loader, "fetch_all", return_value=[first]), \
             patch.object(loader, "upsert_many", self.save_rows):
            self.assertEqual(loader.build_team_attribute_training_features_for_seasons([10]), 1)
        with patch.object(loader, "fetch_all", return_value=[second]), \
             patch.object(loader, "upsert_many", self.save_rows):
            self.assertEqual(loader.build_team_attribute_training_features_for_seasons([10]), 1)
        self.assertEqual(self.db.execute(
            "SELECT ball_possession_avg, ball_safe_per_match FROM team_attribute_features",
        ).fetchall(), [(None, 0.0)])

    def test_shared_reader_joins_competition_and_selects_target_only_for_training(self):
        self.save_rows(loader.UPSERT_SQL, [
            (season_id, 1, 2.0, *([0.0] * len(ALL_FEATURES))) for season_id in (10, 20)
        ])
        with patch.object(loader, "fetch_all", self.fetch_rows):
            score_df = loader.fetch_team_attribute_feature_dataframe([10])
            training_df = loader.fetch_team_attribute_feature_dataframe([10], include_target=True)
            all_df = loader.fetch_team_attribute_feature_dataframe()
        self.assertEqual(score_df["competition_id"].tolist(), [82])
        self.assertNotIn("points_per_match", score_df)
        self.assertEqual(training_df["points_per_match"].tolist(), [2.0])
        self.assertEqual(all_df["competition_id"].tolist(), [8, 82])


if __name__ == "__main__":
    unittest.main()
