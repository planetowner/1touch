"""폼·가성비의 비교 범위, 누락값, 시간 범위와 읽기 전용 API를 검증해요."""
from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
import math
import re
import sqlite3
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
    from one_touch_loader.api.repos import player_indicators_repo as repo
    from one_touch_loader.api.routes import players as route
    from one_touch_loader.api.deps import get_user_id


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
        self.assertEqual(items[-1]["form"]["grade"], "Excellent")

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


class ReadOnlyRepositoryTests(unittest.TestCase):
    def setUp(self):
        for name, value in (('_snapshot_inputs', None), ('_snapshot', {}), ('_snapshot_expires_at', 0)):
            patcher = patch.object(repo, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.db = sqlite3.connect(":memory:", detect_types=sqlite3.PARSE_DECLTYPES)
        self.db.row_factory = sqlite3.Row
        self.db.create_function("REGEXP", 2, lambda pattern, value: re.search(pattern, value) is not None)
        self.db.executescript("""
          CREATE TABLE seasons (season_id INTEGER,competition_id INTEGER,name TEXT,is_current INTEGER);
          CREATE TABLE team_squad_members (player_id INTEGER,team_id INTEGER,season_id INTEGER,position_group_id INTEGER,squad_role TEXT);
          CREATE TABLE player_wages (player_id INTEGER,team_id INTEGER,season_id INTEGER,estimated_weekly_gross_eur INTEGER);
          CREATE TABLE stages (stage_id INTEGER,season_id INTEGER);
          CREATE TABLE rounds (round_id INTEGER,name TEXT);
          CREATE TABLE fixtures (fixture_id INTEGER,stage_id INTEGER,round_id INTEGER,state_id INTEGER,
              starting_at TIMESTAMP,home_team_id INTEGER,away_team_id INTEGER);
          CREATE TABLE fixture_lineups (fixture_id INTEGER,player_id INTEGER,team_id INTEGER,minutes_played INTEGER,rating REAL);
          INSERT INTO seasons VALUES (1,8,'2026/2027',1),(2,8,'2025/2026',0),(3,999,'2026/2027',1);
          INSERT INTO team_squad_members VALUES (1,8,1,25,'prospect'),(2,8,2,25,NULL),(3,8,3,25,NULL);
          INSERT INTO player_wages VALUES (1,8,1,10000);
          INSERT INTO stages VALUES (1,1),(2,2),(3,3);
          INSERT INTO rounds VALUES (1,'1'),(2,'Play-offs');
        """)
        # 정상 경기, 진행 중, 과거 시즌, 미래 시각, 플레이오프, 다른 대회를 섞어요.
        for fid, stage, rnd, state, day in [(1,1,1,5,-1),(2,1,1,2,-1),(3,2,1,5,-1),
                                           (4,1,1,5,1),(5,1,2,5,-1),(6,3,1,5,-1)]:
            self.db.execute("INSERT INTO fixtures VALUES (?,?,?,?,?,?,?)",
                            (fid,stage,rnd,state,NOW+timedelta(days=day),8,9))
            self.db.execute("INSERT INTO fixture_lineups VALUES (?,1,8,90,7)", (fid,))
        self.db.commit()
        self.addCleanup(self.db.close)
        patcher = patch.object(repo, "get_conn", return_value=self)
        patcher.start()
        self.addCleanup(patcher.stop)

    def start_transaction(self, **kwargs):
        self.assertEqual(kwargs, dict(readonly=True, consistent_snapshot=True))

    def rollback(self):
        self.db.rollback()

    def close(self):
        pass

    def cursor(self, **kwargs):
        owner = self
        class Cursor:
            def __enter__(self):
                self.cursor = owner.db.cursor()
                return self
            def __exit__(self, *args):
                self.cursor.close()
            def execute(self, sql, params=()):
                owner.assertTrue(sql.strip().startswith("SELECT"))
                self.cursor.execute(sql.replace("%s", "?"), params)
            def fetchall(self):
                return [dict(r) for r in self.cursor.fetchall()]
        return Cursor()

    def test_real_queries_only_select_completed_current_league_matches(self):
        result = repo.get_current_player_indicators(1, as_of=NOW)
        self.assertEqual(result["form"]["rated_matches"], 1)
        self.assertEqual(result['squad_role'], 'prospect')
        self.assertEqual(result["cost_effectiveness"]["minutes_played"], 90)
        self.assertEqual(result["cost_effectiveness"]["available_minutes"], 90)
        self.assertIsNone(repo.get_current_player_indicators(2, as_of=NOW))
        self.assertIsNone(repo.get_current_player_indicators(3, as_of=NOW))

    def test_route_requires_auth_and_preserves_response_contract(self):
        app = FastAPI()
        app.include_router(route.router, prefix="/v1")
        with TestClient(app) as client:
            self.assertEqual(client.get("/v1/players/1/indicators").status_code, 401)
            app.dependency_overrides[get_user_id] = lambda: 1
            result = repo.get_current_player_indicators(1, as_of=NOW)
            with patch.object(route, "get_current_player_indicators", return_value=result):
                response = client.get("/v1/players/1/indicators")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()['squad_role'], 'prospect')
            self.assertIsNone(response.json()["cost_effectiveness"]["grade"])
            self.assertEqual(response.json()["comparison_scope"], "current_season_big_five_all_positions")
            with patch.object(route, "get_current_player_indicators", return_value=None):
                self.assertEqual(client.get("/v1/players/2/indicators").status_code, 404)

    def test_one_snapshot_is_shared_between_players_and_expires(self):
        clock = [600]
        with patch.object(repo, 'monotonic', side_effect=lambda: clock[0]), \
                patch.object(repo, '_read_current_inputs', wraps=repo._read_current_inputs) as read, \
                patch.object(repo, '_build_current_snapshot', wraps=repo._build_current_snapshot) as build:
            self.assertEqual(repo.get_current_player_indicators(1)['player_id'], 1)
            self.assertIsNone(repo.get_current_player_indicators(2))
            self.assertEqual((read.call_count, build.call_count), (1, 1))
            clock[0] = 660
            repo.get_current_player_indicators(1)
            self.assertEqual((read.call_count, build.call_count), (2, 1))

    def test_cache_reloads_changed_minutes_ratings_wages_roles_and_roster(self):
        clock = [0]
        with patch.object(repo, 'monotonic', side_effect=lambda: clock[0]), \
                patch.object(repo, 'datetime', wraps=datetime) as dates, \
                patch.object(repo, '_build_current_snapshot', wraps=repo._build_current_snapshot) as build:
            dates.now.return_value = NOW
            repo.get_current_player_indicators(1)
            updates = [
                ('UPDATE fixture_lineups SET minutes_played=30 WHERE fixture_id=1',
                 lambda r: self.assertEqual(r['cost_effectiveness']['minutes_played'], 30)),
                ('UPDATE fixture_lineups SET rating=NULL WHERE fixture_id=1',
                 lambda r: self.assertEqual(r['form']['rated_matches'], 0)),
                ('UPDATE player_wages SET estimated_weekly_gross_eur=20000 WHERE player_id=1',
                 lambda r: self.assertEqual(r['cost_effectiveness']['actual_weekly_wage_eur'], 20000)),
                ("UPDATE team_squad_members SET squad_role='crucial' WHERE player_id=1",
                 lambda r: self.assertEqual(r['squad_role'], 'crucial')),
                ('UPDATE fixtures SET state_id=2 WHERE fixture_id=1',
                 lambda r: self.assertEqual(r['cost_effectiveness']['available_minutes'], 0)),
                ('DELETE FROM team_squad_members WHERE player_id=1', self.assertIsNone),
            ]
            for count, (sql, check) in enumerate(updates, 2):
                self.db.execute(sql)
                self.db.commit()
                clock[0] += 61
                check(repo.get_current_player_indicators(1))
                self.assertEqual(build.call_count, count)

    def test_explicit_cutoff_bypasses_cached_current_snapshot(self):
        with patch.object(repo, '_cached_current_snapshot', return_value={1: {'cached': True}}) as cached:
            result = repo.get_current_player_indicators(1, as_of=NOW)
        cached.assert_not_called()
        self.assertEqual(result['form']['rated_matches'], 1)


class SnapshotCacheTests(unittest.TestCase):
    def setUp(self):
        for name, value in (('_snapshot_inputs', None), ('_snapshot', {}), ('_snapshot_expires_at', 0)):
            patcher = patch.object(repo, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_expiry_starts_after_slow_calculation_finishes(self):
        clock = [0]
        def build(*args, **kwargs):
            clock[0] += 314
            return {1: {'player_id': 1}}
        with patch.object(repo, 'monotonic', side_effect=lambda: clock[0]), \
                patch.object(repo, '_read_current_inputs', return_value=([], [], [], None)) as read, \
                patch.object(repo, '_build_current_snapshot', side_effect=build) as calculate:
            repo.get_current_player_indicators(1)
            clock[0] = 373
            repo.get_current_player_indicators(1)
            self.assertEqual((read.call_count, calculate.call_count), (1, 1))
            clock[0] = 374
            repo.get_current_player_indicators(1)
            self.assertEqual((read.call_count, calculate.call_count), (2, 1))

    def test_concurrent_requests_share_one_calculation(self):
        entered, release, second_started = Event(), Event(), Event()
        def build(*args, **kwargs):
            entered.set()
            if not release.wait(5):
                raise AssertionError('Test did not release snapshot calculation')
            return {1: {'player_id': 1}}
        def second():
            second_started.set()
            return repo.get_current_player_indicators(1)
        with patch.object(repo, '_read_current_inputs', return_value=([], [], [], None)) as read, \
                patch.object(repo, '_build_current_snapshot', side_effect=build) as calculate, \
                ThreadPoolExecutor(max_workers=2) as workers:
            first = workers.submit(repo.get_current_player_indicators, 1)
            self.assertTrue(entered.wait(5))
            other = workers.submit(second)
            self.assertTrue(second_started.wait(5))
            release.set()
            self.assertIs(first.result(timeout=5), other.result(timeout=5))
        self.assertEqual((read.call_count, calculate.call_count), (1, 1))

    def test_calibration_change_recalculates_and_failure_is_retried(self):
        clock = [0]
        inputs = ([], [], [], {'applies_to_season': '2026/2027', 'decay_per_day': 0})
        with patch.object(repo, 'monotonic', side_effect=lambda: clock[0]), \
                patch.object(repo, '_read_current_inputs', side_effect=lambda _: deepcopy(inputs)), \
                patch.object(repo, '_build_current_snapshot', return_value={1: {'player_id': 1}}) as build:
            repo.get_current_player_indicators(1)
            inputs[3]['decay_per_day'] = 0.1
            clock[0] = 61
            build.side_effect = RuntimeError('model failed')
            with self.assertRaisesRegex(RuntimeError, 'model failed'):
                repo.get_current_player_indicators(1)
            build.side_effect = None
            repo.get_current_player_indicators(1)
            self.assertEqual(build.call_count, 3)


if __name__ == "__main__":
    unittest.main()
