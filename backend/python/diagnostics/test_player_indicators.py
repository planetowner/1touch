"""폼·가성비의 비교 범위, 누락값, 시간 범위와 읽기 전용 API를 검증해요."""
from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import math
import json
import re
from pathlib import Path
import sqlite3
import tempfile
from threading import Event
import unittest
from unittest.mock import patch

import numpy as np
from fastapi import FastAPI
from fastapi.testclient import TestClient

from one_touch_loader.core.player_indicators import (
    _assign_form_grades, _cost_band, _cost_features, _teammate_wage_medians,
    build_player_indicators, calibrate_form_decay, combined_cost_score,
    cost_effectiveness_scores, weighted_rating,
)

with patch("mysql.connector.pooling.MySQLConnectionPool") as pool:
    pool.return_value.get_connection.side_effect = AssertionError("Operational DB access in tests")
    from one_touch_loader.loaders import player_indicators_loader as loader
    from one_touch_loader.api.repos import player_indicators_repo as repo
    from one_touch_loader.api.routes import players as route
    from one_touch_loader.api.deps import get_user_id
    from diagnostics import check_player_indicators as checker


NOW = datetime(2026, 9, 20)


def match(player=1, day=0, rating=7, minutes=90, team=8, fixture=None):
    return dict(player_id=player, team_id=team, season_id=28083,
                fixture_id=fixture if fixture is not None else day + 10,
                starting_at=NOW + timedelta(days=day), rating=rating, minutes_played=minutes)


def roster(player=1, wage=10000):
    return dict(player_id=player, team_id=8, season_id=28083, season_name="2026/2027",
                competition_id=8, position_group_id=25, estimated_weekly_gross_eur=wage)


def fixture(day=0):
    return dict(season_id=28083, home_team_id=8, away_team_id=9,
                starting_at=NOW + timedelta(days=day))


def wage_sample():
    players = [{**roster(i, (10000 + (i % 11) * 3000) * (1 + i // 12)),
                "team_id": 8 + i // 12, "competition_id": 8 if i % 3 else 82,
                "position_group_id": 24 + i % 4} for i in range(180)]
    rows = [{**p, "season_rating": 6 + (i % 7) / 5, "minutes_share": (i % 9 + 1) / 10,
             "actual_weekly_wage_eur": p["estimated_weekly_gross_eur"]}
            for i, p in enumerate(players)]
    return players, rows


class IndicatorMathTests(unittest.TestCase):
    def test_minutes_and_decay_have_separate_effects(self):
        rows = [match(day=-7, rating=6, minutes=90), match(rating=9, minutes=10)]
        self.assertAlmostEqual(weighted_rating(rows), 6.3)
        self.assertAlmostEqual(weighted_rating(rows, math.log(2) / 7), (6 * 45 + 9 * 10) / 55)
        self.assertIsNone(weighted_rating([match(rating=None), match(minutes=0)]))

    def test_latest_five_appearances_do_not_replace_missing_rating(self):
        rows = [match(day=-6, rating=10), *[match(day=d, rating=6) for d in range(-4, 0)],
                match(rating=None), match(day=1, rating=10)]
        item = build_player_indicators([roster()], rows, [fixture()], {"decay_per_day": 0}, as_of=NOW)[0]
        self.assertEqual(item["form"]["raw_score"], 6)
        self.assertEqual(item["form"]["appearances"], 5)
        self.assertEqual(item["form"]["rated_matches"], 4)
        self.assertEqual(item["cost_effectiveness"]["rated_matches"], 5)
        self.assertEqual(item["form"]["last_match_at"], NOW)

    def test_missing_wage_does_not_remove_form_or_become_free(self):
        rows = [match(1), match(2, rating=8)]
        items = build_player_indicators([roster(1, None), roster(2)], rows,
                                        [fixture(), fixture(-7)], {"decay_per_day": 0}, as_of=NOW)
        self.assertEqual(items[0]["form"]["reference_count"], 2)
        cost = items[0]["cost_effectiveness"]
        self.assertIsNone(cost["grade"])
        self.assertEqual(cost["unavailable_reason"], "wage_unavailable")
        self.assertEqual(cost["minutes_share"], .5)
        self.assertEqual(cost["available_minutes"], 180)

    def test_current_club_wage_is_compared_with_current_club_contribution(self):
        rows = [match(team=99, day=-7, rating=9), match(rating=6)]
        item = build_player_indicators([roster()], rows, [fixture()], {"decay_per_day": 0}, as_of=NOW)[0]
        self.assertEqual(item["form"]["raw_score"], 7.5)
        self.assertEqual(item["cost_effectiveness"]["season_rating"], 6)
        self.assertEqual(item["cost_effectiveness"]["minutes_share"], 1)

    def test_all_positions_and_leagues_share_one_distribution(self):
        items = [{"form": {"raw_score": score}}
                 for score in [1, 1, 2, 3, 4]]
        _assign_form_grades(items)
        self.assertEqual(items[0]["form"]["percentile"], 20)
        self.assertEqual(items[0]["form"]["grade"], "Poor")
        self.assertEqual(items[0]["form"], items[1]["form"])
        self.assertEqual(items[-1]["form"]["grade"], "Very Good")

    def test_numeric_noise_does_not_split_ties(self):
        items = [{"form": {"raw_score": x}} for x in [7.1, 7.099999999999999]]
        _assign_form_grades(items)
        self.assertEqual([x["form"]["percentile"] for x in items], [50, 50])

    def test_unavailable_calibration_does_not_invent_form(self):
        item = build_player_indicators([roster()], [match()], [fixture()], None, as_of=NOW)[0]
        self.assertIsNone(item["form"]["grade"])
        self.assertEqual(item["form"]["unavailable_reason"], "form_calibration_unavailable")

    def test_calibration_is_chronological_repeatable_and_does_not_mutate_inputs(self):
        rows = [match(player=p, day=-j, rating=6 + p / 10 + (j % 2) / 10)
                for p in range(1, 9) for j in range(10)]
        before = deepcopy(rows)
        first = calibrate_form_decay(rows)
        self.assertEqual(rows, before)
        self.assertEqual(first, calibrate_form_decay(list(reversed(rows))))
        self.assertEqual(first["validation_pairs"], 72)
        self.assertLessEqual(first["weighted_mse"], first["no_decay_mse"])

    def test_own_performance_is_excluded_from_training_and_calibration(self):
        players, rows = wage_sample()
        original = cost_effectiveness_scores(rows, players)
        self.assertEqual(len(original), len(rows))
        for index in (0, 17, 39):
            with self.subTest(player=index):
                changed_rows = deepcopy(rows)
                changed_rows[index]["season_rating"] += 1
                changed_rows[index]["minutes_share"] += .1
                changed = cost_effectiveness_scores(changed_rows, players)
                for key in ("expected_rating", "expected_minutes_share", "rating_sd",
                            "minutes_share_sd", "fair_boundary", "very_boundary"):
                    self.assertAlmostEqual(original[index][key], changed[index][key], places=9)
                self.assertGreater(changed[index]["raw_score"], original[index]["raw_score"])
        self.assertEqual(original, cost_effectiveness_scores(list(reversed(rows)), players))

    def test_cost_uses_equal_standardized_weights_and_error_bands(self):
        actual, expected, scales = np.asarray([8, .4]), np.asarray([7, .6]), np.asarray([.5, .2])
        self.assertAlmostEqual(float(combined_cost_score(actual, expected, scales)), .5)
        # 경계 안은 Fair이고 양쪽 95% 경계의 바깥부터 Very 등급이에요.
        scores = [-2.01, -2, -1.01, -1, 0, 1, 1.01, 2, 2.01]
        self.assertEqual([_cost_band(v, 1, 2) for v in scores], [0, 1, 1, 2, 2, 2, 3, 3, 4])

    def test_missing_rating_is_not_imputed_or_reweighted(self):
        players, rows = wage_sample()
        rows[0]["season_rating"] = None
        original = cost_effectiveness_scores(rows, players)
        self.assertNotIn(0, original)
        # 평점이 없는 선수도 확인된 출전 비중은 해당 학습 집단에 포함돼요.
        rows[0]["minutes_share"] = .95
        changed = cost_effectiveness_scores(rows, players)
        self.assertTrue(any(original[p]["minutes_share_sd"] != changed[p]["minutes_share_sd"] for p in original))
        self.assertTrue(all(v["reference_count"] == 179 for v in changed.values()))

    def test_insufficient_calibration_or_constant_targets_have_no_cost_grade(self):
        players, rows = wage_sample()
        self.assertEqual(cost_effectiveness_scores(rows[:2], players), {})
        self.assertEqual(cost_effectiveness_scores(rows[:60], players), {})
        for row in rows:
            row["season_rating"] = 7
        self.assertEqual(cost_effectiveness_scores(rows, players), {})

    def test_club_median_excludes_self_and_limits_a_single_superstar(self):
        wages = dict(enumerate([40000, 45000, 50000, 55000, 60000,
                                70000, 80000, 90000, 100000, 500000]))
        levels = _teammate_wage_medians(wages)
        self.assertEqual(levels[9], 60000)
        self.assertEqual(levels[0], 70000)
        wages[9] *= 10
        self.assertEqual(levels, _teammate_wage_medians(wages))
        # 예측 대상의 급여는 동료의 학습 입력에서도 빠져야 해요.
        excluded = _teammate_wage_medians(wages, excluded_player=9)
        self.assertEqual(excluded[0], 65000)
        self.assertEqual(excluded[9], 60000)
        self.assertEqual(_teammate_wage_medians({1: 10000}), {1: None})

    def test_club_level_includes_unplayed_teammates_but_not_other_seasons(self):
        players, rows = wage_sample()
        _, original = _cost_features(rows, players)
        other_season = [{**p, "season_id": 999, "estimated_weekly_gross_eur": 1000000}
                        for p in players]
        np.testing.assert_array_equal(original, _cost_features(rows, players + other_season)[1])
        unplayed = [roster(1000 + i, 1000000) for i in range(15)]
        changed = _cost_features(rows, players + unplayed)[1]
        self.assertNotAlmostEqual(original[0, 1], changed[0, 1], places=5)
        unavailable = [roster(200 + i, wage) for i, wage in enumerate([None, 0])]
        np.testing.assert_array_equal(original, _cost_features(rows, players + unavailable)[1])

    def test_actual_wage_is_a_predictor_but_does_not_raise_own_club_median(self):
        players, rows = wage_sample()
        original = _cost_features(rows, players)[1]
        players[0]["estimated_weekly_gross_eur"] *= 20
        rows[0]["actual_weekly_wage_eur"] *= 20
        changed = _cost_features(rows, players)[1]
        self.assertAlmostEqual(changed[0, 0] - original[0, 0], math.log(20))
        self.assertEqual(changed[0, 1], original[0, 1])


class SnapshotRepositoryTests(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.path = Path(folder.name) / "indicators.sqlite"
        self.fail_insert = False
        self.before_publish = None
        self.writes = []
        self.queries = []
        self.db = self.connect()
        self.addCleanup(self.db.close)
        self.db.executescript("""
          PRAGMA journal_mode=WAL;
          CREATE TABLE players (player_id INTEGER PRIMARY KEY,position_id INTEGER);
          CREATE TABLE competitions (competition_id INTEGER PRIMARY KEY);
          INSERT INTO competitions VALUES (8);
          CREATE TABLE positions (position_id INTEGER PRIMARY KEY,position_group_id INTEGER);
          INSERT INTO positions VALUES (148,25),(150,26);
          INSERT INTO players VALUES (1,148),(2,148),(3,148);
          CREATE TABLE seasons (season_id INTEGER PRIMARY KEY,competition_id INTEGER,name TEXT,is_current INTEGER);
          CREATE TABLE team_squad_members (player_id INTEGER,team_id INTEGER,season_id INTEGER,position_group_id INTEGER,squad_role TEXT);
          CREATE INDEX squad_player ON team_squad_members(player_id);
          CREATE TABLE player_wages (player_id INTEGER,team_id INTEGER,season_id INTEGER,estimated_weekly_gross_eur INTEGER);
          CREATE TABLE stages (stage_id INTEGER,season_id INTEGER);
          CREATE TABLE rounds (round_id INTEGER,name TEXT);
          CREATE TABLE fixtures (fixture_id INTEGER,stage_id INTEGER,round_id INTEGER,state_id INTEGER,
              starting_at TIMESTAMP,home_team_id INTEGER,away_team_id INTEGER);
          CREATE TABLE fixture_lineups (fixture_id INTEGER,player_id INTEGER,team_id INTEGER,minutes_played INTEGER,rating REAL);
          CREATE TABLE player_indicator_snapshots (player_id INTEGER PRIMARY KEY,team_id INTEGER,season_id INTEGER,payload TEXT);
          CREATE TABLE player_indicator_refresh (id INTEGER PRIMARY KEY,input_sha256 TEXT,as_of TIMESTAMP,
              calculated_at TIMESTAMP,checked_at TIMESTAMP,player_count INTEGER DEFAULT 0,read_seconds REAL,calculation_seconds REAL);
          INSERT INTO player_indicator_refresh (id) VALUES (1);
          INSERT INTO seasons VALUES (1,8,'2026/2027',1),(2,8,'2025/2026',0),(3,999,'2026/2027',1);
          INSERT INTO team_squad_members VALUES (1,8,1,25,'prospect'),(2,8,2,25,NULL),(3,8,3,25,NULL);
          INSERT INTO player_wages VALUES (1,8,1,10000);
          INSERT INTO stages VALUES (1,1),(2,2),(3,3);
          INSERT INTO rounds VALUES (1,'1'),(2,'Play-offs');
        """)
        # 정상 경기, 진행 중, 과거 시즌, 미래 시각, 플레이오프, 다른 대회를 섞어요.
        for fid, stage, rnd, state, day in [
            (1, 1, 1, 5, -1),
            (2, 1, 1, 2, -1),
            (3, 2, 1, 5, -1),
            (4, 1, 1, 5, 1),
            (5, 1, 2, 5, -1),
            (6, 3, 1, 5, -1),
        ]:
            self.db.execute(
                "INSERT INTO fixtures VALUES (?,?,?,?,?,?,?)",
                (fid, stage, rnd, state, NOW + timedelta(days=day), 8, 9),
            )
            self.db.execute("INSERT INTO fixture_lineups VALUES (?,1,8,90,7)", (fid,))
        self.db.commit()
        for obj, name, kwargs in (
            (loader, "get_conn", {"side_effect": self.connection}),
            (repo, "fetch_one_dict", {"side_effect": self.fetch_one}),
            (loader, "datetime", {"wraps": datetime}),
        ):
            patcher = patch.object(obj, name, **kwargs)
            value = patcher.start()
            self.addCleanup(patcher.stop)
            if name == "datetime":
                self.dates = value
                value.now.return_value = NOW.replace(tzinfo=timezone.utc)

    def connect(self):
        conn = sqlite3.connect(self.path, detect_types=sqlite3.PARSE_DECLTYPES)
        conn.row_factory = sqlite3.Row
        conn.create_function(
            "REGEXP", 2, lambda pattern, value: re.search(pattern, value) is not None
        )
        return conn

    def connection(self):
        owner = self

        class Connection:
            def __init__(self):
                self.db = owner.connect()

            def start_transaction(self, **kwargs):
                self.readonly = kwargs.get("readonly", False)

            def commit(self):
                self.db.commit()

            def rollback(self):
                self.db.rollback()

            def close(self):
                self.db.close()

            def cursor(self, **kwargs):
                return Cursor(self)

        class Cursor:
            def __init__(self, conn):
                self.conn = conn
                self.cur = conn.db.cursor()

            def __enter__(self):
                return self

            def __exit__(self, *args):
                self.cur.close()

            def execute(self, sql, params=()):
                owner.queries.append((sql, params))
                if not sql.lstrip().startswith("SELECT"):
                    owner.assertFalse(self.conn.readonly)
                    owner.writes.append(sql)
                self.cur.execute(
                    sql.replace("%s", "?").replace(" FOR UPDATE", ""), params
                )
                if "SET input_sha256" in sql and owner.before_publish:
                    owner.before_publish()

            def executemany(self, sql, params):
                owner.assertFalse(self.conn.readonly)
                if owner.fail_insert:
                    raise RuntimeError("insert failed")
                self.cur.executemany(sql.replace("%s", "?"), params)

            def fetchall(self):
                return [dict(r) for r in self.cur.fetchall()]

            def fetchone(self):
                row = self.cur.fetchone()
                return dict(row) if row else None

        return Connection()

    def fetch_one(self, sql, params=()):
        self.assertTrue(sql.lstrip().startswith("SELECT"))
        conn = self.connect()
        try:
            row = conn.execute(sql.replace("%s", "?"), params).fetchone()
            return dict(row) if row else None
        finally:
            conn.close()

    def change(self, sql):
        self.db.execute(sql)
        self.db.commit()
        self.dates.now.return_value += timedelta(minutes=1)

    def metadata(self):
        return dict(
            self.db.execute("SELECT * FROM player_indicator_refresh").fetchone()
        )

    def test_queries_only_include_completed_current_league_matches(self):
        result = loader.refresh(apply=True)
        self.assertEqual(result["player_count"], 1)
        item = repo.get_current_player_indicators(1)
        self.assertEqual(item["form"]["rated_matches"], 1)
        self.assertEqual(item["squad_role"], "prospect")
        self.assertEqual(item["cost_effectiveness"]["minutes_played"], 90)
        self.assertEqual(item["cost_effectiveness"]["available_minutes"], 90)
        self.assertIsNone(repo.get_current_player_indicators(2))
        self.assertIsNone(repo.get_current_player_indicators(3))

    def test_route_auth_contract_missing_player_and_unprepared_snapshot(self):
        app = FastAPI()
        app.include_router(route.router, prefix="/v1")
        with TestClient(app) as client:
            self.assertEqual(client.get("/v1/players/1/indicators").status_code, 401)
            app.dependency_overrides[get_user_id] = lambda: 1
            response = client.get("/v1/players/1/indicators")
            self.assertEqual(response.status_code, 503)
            self.assertEqual(response.headers["Retry-After"], "60")
            loader.refresh(apply=True)
            response = client.get("/v1/players/1/indicators")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["squad_role"], "prospect")
            self.assertIsNone(response.json()["cost_effectiveness"]["grade"])
            self.assertEqual(response.json()["as_of"], "2026-09-20T00:00:00Z")
            self.assertEqual(
                response.json()["comparison_scope"],
                "current_season_big_five_all_positions",
            )
            self.assertEqual(client.get("/v1/players/2/indicators").status_code, 404)

    def test_preview_does_not_write_and_unchanged_inputs_do_not_retrain(self):
        self.assertEqual(loader.refresh()["status"], "preview")
        self.assertEqual(self.writes, [])
        loader.refresh(apply=True)
        old = self.metadata()
        self.change("UPDATE players SET position_id=150 WHERE player_id=1")
        self.dates.now.return_value += timedelta(minutes=1)
        with patch.object(
            loader, "build_snapshot", side_effect=AssertionError("Unexpected training")
        ):
            report = loader.refresh(apply=True)
            self.assertEqual(report["status"], "unchanged")
            self.assertEqual(report["calculation_seconds"], 0)
        new = self.metadata()
        self.assertEqual(new["as_of"], old["as_of"])
        self.assertEqual(new["calculated_at"], old["calculated_at"])
        self.assertGreater(new["checked_at"], old["checked_at"])

    def test_publication_coordinates_with_squad_writes_only_after_calculation(self):
        lock_sql = "SELECT competition_id FROM competitions WHERE competition_id=%s FOR UPDATE"
        build = loader.build_snapshot

        def calculate(*args, **kwargs):
            self.assertFalse(any(sql == lock_sql for sql, _ in self.queries))
            return build(*args, **kwargs)

        with patch.object(loader, "build_snapshot", side_effect=calculate):
            loader.refresh(apply=True)
        lock_index = self.queries.index((lock_sql, (8,)))
        delete_index = next(i for i, (sql, _) in enumerate(self.queries)
                            if sql == "DELETE FROM player_indicator_snapshots")
        self.assertLess(lock_index, delete_index)

        # 입력 확인과 조회 모드는 선수 행을 저장하지 않으므로 공통 잠금이 필요 없어요.
        self.queries.clear()
        self.assertEqual(loader.refresh(apply=True)["status"], "unchanged")
        self.assertFalse(any(sql == lock_sql for sql, _ in self.queries))
        self.change("UPDATE player_wages SET estimated_weekly_gross_eur=20000")
        self.queries.clear()
        self.assertEqual(loader.refresh(apply=False)["status"], "preview")
        self.assertFalse(any(sql == lock_sql for sql, _ in self.queries))

    def test_saved_top_grade_uses_current_name_without_recalculation(self):
        loader.refresh(apply=True)
        saved = json.loads(self.db.execute(
            "SELECT payload FROM player_indicator_snapshots WHERE player_id=1"
        ).fetchone()["payload"])
        for key, grade in (("form", "Excellent"), ("cost_effectiveness", "Very Good")):
            saved[key].update(band=4, grade=grade, unavailable_reason=None)
        saved["form"]["percentile"] = 90
        self.db.execute(
            "UPDATE player_indicator_snapshots SET payload=? WHERE player_id=1",
            (json.dumps(saved),),
        )
        self.db.commit()
        app = FastAPI()
        app.include_router(route.router, prefix="/v1")
        app.dependency_overrides[get_user_id] = lambda: 1
        with patch.object(loader, "build_snapshot", side_effect=AssertionError("Unexpected training")):
            result = repo.get_current_player_indicators(1)
            with TestClient(app) as client:
                response = client.get("/v1/players/1/indicators")
        self.assertEqual(response.status_code, 200)
        for key in ("form", "cost_effectiveness"):
            self.assertEqual(result[key], {**saved[key], "grade": "Very Good"})
            self.assertEqual(response.json()[key]["grade"], "Very Good")
            self.assertEqual(response.json()[key]["band"], 4)
        self.assertEqual(json.loads(self.db.execute(
            "SELECT payload FROM player_indicator_snapshots WHERE player_id=1"
        ).fetchone()["payload"]), saved)

    def test_role_is_fresh_without_retraining_or_request_time_computation(self):
        loader.refresh(apply=True)
        before = repo.get_current_player_indicators(1)
        self.change(
            "UPDATE team_squad_members SET squad_role='crucial' WHERE player_id=1"
        )
        with patch.object(
            loader, "build_snapshot", side_effect=AssertionError("Unexpected training")
        ):
            self.assertEqual(loader.refresh(apply=True)["status"], "unchanged")
            for _ in range(3):
                after = repo.get_current_player_indicators(1)
                self.assertEqual(after, {**before, "squad_role": "crucial"})

    def test_changed_inputs_recalculate_and_removed_player_is_not_served(self):
        loader.refresh(apply=True)
        updates = [
            (
                "UPDATE fixture_lineups SET minutes_played=30 WHERE fixture_id=1",
                lambda r: self.assertEqual(
                    r["cost_effectiveness"]["minutes_played"], 30
                ),
            ),
            (
                "UPDATE fixture_lineups SET rating=NULL WHERE fixture_id=1",
                lambda r: self.assertEqual(r["form"]["rated_matches"], 0),
            ),
            (
                "UPDATE player_wages SET estimated_weekly_gross_eur=20000 WHERE player_id=1",
                lambda r: self.assertEqual(
                    r["cost_effectiveness"]["actual_weekly_wage_eur"], 20000
                ),
            ),
            (
                "UPDATE team_squad_members SET position_group_id=26 WHERE player_id=1",
                lambda r: self.assertEqual(r["position_group_id"], 26),
            ),
            (
                "UPDATE fixtures SET state_id=2 WHERE fixture_id=1",
                lambda r: self.assertEqual(
                    r["cost_effectiveness"]["available_minutes"], 0
                ),
            ),
            ("DELETE FROM team_squad_members WHERE player_id=1", self.assertIsNone),
        ]
        for sql, check in updates:
            self.change(sql)
            self.assertEqual(loader.refresh(apply=True)["status"], "updated")
            check(repo.get_current_player_indicators(1))

    def test_model_version_and_calibration_change_invalidate_saved_results(self):
        loader.refresh(apply=True)
        with patch.object(loader, "MODEL_VERSION", loader.MODEL_VERSION + 1):
            self.assertEqual(loader.refresh(apply=True)["status"], "updated")
            self.assertEqual(loader.refresh(apply=True)["status"], "unchanged")
        inputs = loader.read_current_inputs(NOW)
        inputs[3]["decay_per_day"] += 0.1
        with patch.object(loader, "read_current_inputs", return_value=inputs):
            self.assertEqual(loader.refresh(apply=True)["status"], "updated")

    def test_failures_preserve_previous_snapshot_and_next_run_retries(self):
        loader.refresh(apply=True)
        before, metadata = repo.get_current_player_indicators(1), self.metadata()
        self.change("UPDATE player_wages SET estimated_weekly_gross_eur=20000")
        with patch.object(
            loader, "build_snapshot", side_effect=RuntimeError("calculation failed")
        ):
            with self.assertRaisesRegex(RuntimeError, "calculation failed"):
                loader.refresh(apply=True)
        self.fail_insert = True
        with self.assertRaisesRegex(RuntimeError, "insert failed"):
            loader.refresh(apply=True)
        self.assertEqual(repo.get_current_player_indicators(1), before)
        self.assertEqual(self.metadata(), metadata)
        self.fail_insert = False
        self.assertEqual(loader.refresh(apply=True)["status"], "updated")
        self.assertEqual(
            repo.get_current_player_indicators(1)["cost_effectiveness"][
                "actual_weekly_wage_eur"
            ],
            20000,
        )

    def test_readers_keep_previous_result_during_calculation_and_uncommitted_publication(
        self,
    ):
        loader.refresh(apply=True)
        old = repo.get_current_player_indicators(1)
        self.change("UPDATE player_wages SET estimated_weekly_gross_eur=20000")
        entered, release = Event(), Event()
        original = loader.build_snapshot

        def pause():
            entered.set()
            if not release.wait(5):
                raise AssertionError("Refresh was not released")

        def build(*args):
            pause()
            return original(*args)

        # 학습 중과 DELETE+INSERT 뒤 커밋 전을 각각 멈춰 실제 동시 읽기를 확인해요.
        for during_build in (True, False):
            entered.clear()
            release.clear()
            self.before_publish = None if during_build else pause
            with (
                patch.object(
                    loader,
                    "build_snapshot",
                    side_effect=build if during_build else original,
                ),
                ThreadPoolExecutor(max_workers=1) as workers,
            ):
                work = workers.submit(loader.refresh, apply=True)
                try:
                    self.assertTrue(entered.wait(5))
                    self.assertEqual(repo.get_current_player_indicators(1), old)
                finally:
                    release.set()
                self.assertEqual(work.result(timeout=5)["status"], "updated")
            old = repo.get_current_player_indicators(1)
            self.change("UPDATE player_wages SET estimated_weekly_gross_eur=30000")

    def test_old_season_or_club_snapshot_is_not_used_for_new_membership(self):
        loader.refresh(apply=True)
        self.change("UPDATE team_squad_members SET team_id=9 WHERE player_id=1")
        with self.assertRaises(repo.IndicatorsNotReadyError):
            repo.get_current_player_indicators(1)
        loader.refresh(apply=True)
        self.assertEqual(repo.get_current_player_indicators(1)["team_id"], 9)
        self.change("UPDATE seasons SET is_current=0 WHERE season_id=1")
        self.assertIsNone(repo.get_current_player_indicators(1))

    def test_readiness_checks_complete_snapshot_and_measures_actual_repository(self):
        for index, competition in enumerate((82, 301, 384, 564), 11):
            self.db.execute("INSERT INTO players VALUES (?,148)", (index,))
            self.db.execute(
                "INSERT INTO seasons VALUES (?, ?, ?, 1)",
                (index, competition, "2026/2027"),
            )
            self.db.execute(
                "INSERT INTO team_squad_members VALUES (?,8,?,25,NULL)", (index, index)
            )
        self.db.commit()
        loader.refresh(apply=True)
        self.change(
            "UPDATE player_indicator_snapshots SET payload=json_set(payload,'$.form.grade','Excellent','$.form.band',4) WHERE player_id=1"
        )
        saved = self.db.execute(
            "SELECT payload FROM player_indicator_snapshots WHERE player_id=1"
        ).fetchone()["payload"]
        with patch.object(checker, "get_conn", side_effect=self.connection):
            result = checker.check(player_id=1, samples=3)
            self.assertTrue(result["check"])
            self.assertEqual(result["snapshot"]["player_count"], 5)
            self.assertEqual(result["samples"], 3)
            self.assertGreaterEqual(result["max_ms"], result["p50_ms"])
            self.assertEqual(self.db.execute(
                "SELECT payload FROM player_indicator_snapshots WHERE player_id=1"
            ).fetchone()["payload"], saved)
            self.change(
                "UPDATE player_indicator_snapshots SET payload=json_set(payload,'$.player_id',999) WHERE player_id=1"
            )
            with self.assertRaisesRegex(ValueError, "identity mismatch"):
                checker.check(samples=1)
            self.change("DELETE FROM player_indicator_snapshots WHERE player_id=1")
            with self.assertRaisesRegex(ValueError, "Incomplete"):
                checker.check(samples=1)


if __name__ == "__main__":
    unittest.main()
