"""선수 상세의 포지션, 누락, 순위, 시즌 범위와 읽기 전용 계약을 검증해요."""
from collections import defaultdict
from copy import deepcopy
from datetime import datetime
import json
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch

from one_touch_loader.core.player_detail import (
    build_career, dominant_position, match_cards, rank_categories, season_categories, stat_index, summarize,
)
from one_touch_loader.core.player_match_metrics import SUMMARY_METRICS

with patch("mysql.connector.pooling.MySQLConnectionPool") as pool:
    pool.return_value.get_connection.side_effect = AssertionError("Operational DB access in tests")
    from one_touch_loader.api.repos import player_detail_repo as repo
    from one_touch_loader.api.routes import players as routes
    from one_touch_loader.api.deps import get_user_id


def match(player=1, fixture=1, position=27, **overrides):
    return dict(player_id=player, fixture_id=fixture, team_id=8, match_position_id=position,
                starting_at=datetime(2026, 8, fixture), state_id=5, minutes_played=90, rating=7,
                lineup_type_id=11, home_team_id=8, away_team_id=9, home_score=2, away_score=1,
                season_id=1, season_name="2026/2027", competition_id=8,
                competition_name="Premier League", team_name="Team A", team_code="A",
                team_image=None, xg=0.5, round_name=str(fixture)) | overrides


def metrics(categories):
    return {m["code"]: m for c in categories for m in c["metrics"]}


class PlayerDetailMathTests(unittest.TestCase):
    def test_all_competition_appearances_decide_position_before_minutes(self):
        rows = [match(fixture=1, position=26, minutes_played=90),
                match(fixture=2, position=27, minutes_played=5),
                match(fixture=3, position=27, minutes_played=5, competition_id=2),
                match(fixture=4, position=25, state_id=2)]
        self.assertEqual(dominant_position(rows), 27)
        self.assertIsNone(dominant_position([]))

    def test_position_ties_use_minutes_then_latest_appearance(self):
        self.assertEqual(dominant_position([match(position=25), match(fixture=2, position=26)]), 26)
        self.assertEqual(dominant_position([match(position=25), match(fixture=2, position=26, minutes_played=20)]), 25)

    def test_summary_metrics_are_shared_for_every_position(self):
        for pos, expected in SUMMARY_METRICS.items():
            cards = match_cards([match()], pos, defaultdict(dict))
            self.assertEqual(tuple(m["code"] for m in cards[0]["metrics"]), expected)
            self.assertTrue(all(m["value"] is None for m in cards[0]["metrics"]))

    def test_missing_counts_are_not_season_zero_or_partial_sum(self):
        rows = [match(), match(fixture=2)]
        stats = stat_index([dict(fixture_id=1, team_id=8, player_id=1, stat_type_id=52, value=2)])
        goal = metrics(season_categories(27, rows, stats))["goals"]
        self.assertIsNone(goal["value"])
        self.assertIsNone(goal["rank_value"])
        self.assertEqual(goal["observed_matches"], 1)

    def test_percentages_use_summed_successes_and_attempts(self):
        stats = defaultdict(dict, {(1,8,1): {108: 2, 109: 1}, (2,8,1): {108: 8, 109: 8}})
        row = metrics(season_categories(27, [match(), match(fixture=2)], stats))["dribble_success_rate"]
        self.assertEqual(row["value"], 90)
        self.assertEqual(row["rank_value"], 90)
        self.assertIsNone(row["per90"])

    def test_count_per90_and_pair_successes_are_rank_values(self):
        stats = defaultdict(dict, {(1,8,1): {52: 1, 80: 30, 116: 20}})
        values = metrics(season_categories(27, [match(minutes_played=45)], stats))
        self.assertEqual(values["goals"]["per90"], 2)
        self.assertEqual(values["passes"]["per90"], 40)
        self.assertEqual(values["passes"]["denominator"], 30)

    def test_unknown_minutes_do_not_produce_per90(self):
        values = metrics(season_categories(27, [match(minutes_played=None)], defaultdict(dict, {(1,8,1): {52:1}})))
        self.assertIsNone(values["goals"]["per90"])

    def test_poor_player_still_gets_three_top_stats_and_ties_are_shared(self):
        def categories(goal, assist, shot, lost):
            return season_categories(27, [match(xg=goal)], defaultdict(dict, {(1,8,1): {52:goal,79:assist,42:shot,27273:lost}}))
        own = categories(0, 0, 0, 10)
        reference = [categories(5, 5, 10, 2), categories(3, 2, 6, 4)]
        top = rank_categories(own, reference, includes_player=False)
        self.assertEqual(len(top), 3)
        self.assertTrue(all(m["rank"] == 3 and m["reference_count"] == 3 for m in top))
        equal = categories(5, 5, 10, 2)
        self.assertTrue(all(m["rank"] == 1 for m in rank_categories(equal, reference)))

    def test_negative_metrics_rank_lower_values_first(self):
        own = season_categories(27, [match()], defaultdict(dict, {(1,8,1): {27273:2}}))
        reference = season_categories(27, [match()], defaultdict(dict, {(1,8,1): {27273:9}}))
        self.assertEqual(rank_categories(own, [reference], includes_player=False)[0]["rank"], 1)

    def test_no_reference_and_no_data_do_not_invent_rank(self):
        categories = season_categories(27, [match()], defaultdict(dict))
        self.assertEqual(rank_categories(categories, []), [])

    def test_career_groups_team_and_season_and_averages_known_ratings(self):
        rows = [match(rating=8), match(fixture=2, rating=None, competition_id=2),
                match(fixture=3, rating=6, team_id=9), match(fixture=4, state_id=2)]
        career = build_career(rows)
        self.assertEqual(len(career), 2)
        team = next(r for r in career if r["team_id"] == 8)
        self.assertEqual(team["appearances"], 2)
        self.assertEqual(team["rated_matches"], 1)
        self.assertEqual(team["rating"], 8)
        self.assertEqual(len(team["competitions"]), 2)

    def test_win_rate_uses_player_team_and_does_not_invent_missing_score(self):
        rows = [match(), match(fixture=2, team_id=9), match(fixture=3, home_score=None)]
        self.assertEqual(summarize(rows[:2])["win_rate"], 50)
        self.assertIsNone(summarize(rows)["win_rate"])


class PlayerDetailRepositoryTests(unittest.TestCase):
    def test_missing_player_is_readonly_and_rolls_back(self):
        conn = MagicMock()
        conn.cursor.return_value.__enter__.return_value.fetchall.return_value = []
        with patch.object(repo, 'get_conn', return_value=conn), patch.object(repo, 'get_player_club_history', return_value={'clubs': []}):
            self.assertIsNone(repo.get_player_detail(5))
        conn.start_transaction.assert_called_once_with(readonly=True, consistent_snapshot=True)
        conn.rollback.assert_called_once()
        conn.commit.assert_not_called()
        conn.close.assert_called_once()

    def test_analysis_reference_threshold_and_team_denominator(self):
        own = [match(fixture=i, minutes_played=20) for i in range(1,6)]
        peer = [match(player=2, fixture=i) for i in range(1,6)]
        short_peer = [match(player=3, fixture=i, minutes_played=89) for i in range(1,6)]
        queries = []
        def fetch(sql, params):
            queries.append((sql, params))
            if sql.startswith(repo.MATCH_SELECT): return own + peer + short_peer
            if sql.startswith('SELECT fl.player_id'): return own + peer + short_peer
            if 'FROM fixture_player_stats' in sql:
                self.assertEqual(set(params[1:]), {1,2})
                return [dict(fixture_id=i, team_id=8, player_id=p,stat_type_id=52,value=0) for p in (1,2) for i in range(1,6)]
            if 'SELECT f.fixture_id' in sql: return [match(fixture=i) for i in range(1,9)]
            raise AssertionError(sql)
        data = repo._analysis(fetch, 1, {'season_id':1,'season_name':'2026/2027'}, [], [], datetime(2026,9,21))
        self.assertEqual(data['reference_players'], 1)
        self.assertEqual(data['team_matches'], 8)
        self.assertEqual(data['starting_rate'], 62.5)
        self.assertEqual(data['top_stats'][0]['reference_count'], 2)
        self.assertEqual(len(data['performance']), 5)

    def test_api_requires_auth_and_validates_season(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        app=FastAPI();app.include_router(routes.router)
        client=TestClient(app)
        with patch.object(routes,'get_player_detail') as get:
            self.assertIn(client.get('/players/1/detail').status_code, (401,403,422))
            get.assert_not_called()
            app.dependency_overrides[get_user_id]=lambda:1
            get.return_value=json.loads((Path(__file__).resolve().parents[3] / 'frontend/test/fixtures/player_detail.json').read_text())
            get.return_value['player_id']=1
            self.assertEqual(client.get('/players/1/detail?season_id=5').json()['player_id'], 1)
            get.assert_called_with(1,5)
            get.side_effect=ValueError('Player has no record for this league season')
            self.assertEqual(client.get('/players/1/detail?season_id=6').status_code,404)
            self.assertEqual(client.get('/players/1/detail?season_id=-1').status_code,422)


if __name__ == '__main__':
    unittest.main()
