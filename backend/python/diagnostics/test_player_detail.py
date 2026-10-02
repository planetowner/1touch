"""선수 상세의 포지션, 누락, 순위, 시즌 범위와 읽기 전용 계약을 검증해요."""
from collections import defaultdict
from copy import deepcopy
from datetime import datetime
import json
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch

from one_touch_loader.core.player_detail import (
    build_career, current_player_team, dominant_position, match_cards, rank_categories, season_categories,
    minimum_reference_minutes, stat_index, summarize,
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
    def test_reference_minutes_follow_league_progress_with_floor_rounding_and_cap(self):
        cases = ((0, 20, 45), (1, 20, 45), (10, 20, 45), (20, 20, 90),
                 (36, 18, 180), (50, 20, 225), (69, 20, 311), (70, 20, 315),
                 (99, 20, 446), (100, 20, 450), (380, 20, 450))
        for completed, teams, expected in cases:
            with self.subTest(completed=completed, teams=teams):
                self.assertEqual(minimum_reference_minutes(completed, teams), expected)

    def test_current_team_uses_latest_appearance_to_resolve_a_transfer(self):
        roster = [dict(team_id=8, is_current=1, jersey_number=9),
                  dict(team_id=9, is_current=1, jersey_number=17)]
        self.assertIs(current_player_team(roster, [match(team_id=9, fixture=2), match()]), roster[1])

    def test_current_team_keeps_roster_priority_without_a_matching_appearance(self):
        roster = [dict(team_id=8, is_current=1, jersey_number=None),
                  dict(team_id=9, is_current=1, jersey_number=17),
                  dict(team_id=8, is_current=0, jersey_number=10)]
        for matches in ([], [match(team_id=99)]):
            with self.subTest(matches=matches):
                self.assertIs(current_player_team(roster, matches), roster[0])
        self.assertIsNone(current_player_team(roster[2:], [match()]))

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
        self.assertIsNone(goal["per90"])
        self.assertIsNone(goal["rank_value"])
        self.assertEqual(goal["observed_matches"], 1)

    def test_per90_keeps_minutes_from_zero_event_matches(self):
        minutes = [45, 85, 77, 81, 66, 61, 86]
        values = [1, 3, 2, None, None, 5, 4]
        rows = [match(fixture=i, position=26, minutes_played=minute)
                for i, minute in enumerate(minutes, 1)]
        stats = stat_index([dict(fixture_id=i, team_id=8, player_id=1,
                                stat_type_id=117, value=value)
                            for i, value in enumerate(values, 1) if value is not None])
        for row in rows:
            stats[(row["fixture_id"], 8, 1)][120] = 50
        metric = metrics(season_categories(26, rows, stats))["key_passes"]
        self.assertEqual(metric["value"], 15)
        self.assertAlmostEqual(metric["per90"], 15 * 90 / 501)
        self.assertEqual((metric["observed_matches"], metric["total_matches"]), (7, 7))
        self.assertEqual(metric["rank_value"], metric["per90"])

    def test_unknown_minutes_prevent_per90_but_not_season_totals(self):
        rows = [match(fixture=1, minutes_played=45), match(fixture=2),
                match(fixture=3, minutes_played=None), match(fixture=4)]
        stats = defaultdict(dict, {(1, 8, 1): {52: 2}, (2, 8, 1): {52: 0},
                                  (3, 8, 1): {52: 10}, (4, 8, 1): {120: 30}})
        metric = metrics(season_categories(27, rows, stats))["goals"]
        self.assertIsNone(metric["per90"])
        self.assertEqual(metric["value"], 12)
        self.assertEqual(metric["rank_value"], 12)
        self.assertEqual(metric["observed_matches"], 4)

    def test_pair_per90_counts_successes_even_when_attempts_are_missing(self):
        rows = [match(fixture=1, minutes_played=45), match(fixture=2), match(fixture=3)]
        stats = defaultdict(dict, {(1, 8, 1): {116: 20, 80: 30},
                                  (2, 8, 1): {116: 10}, (3, 8, 1): {116: 0, 80: 50}})
        metric = metrics(season_categories(27, rows, stats))["passes"]
        self.assertAlmostEqual(metric["per90"], 30 * 90 / 225)
        self.assertEqual(metric["observed_matches"], 2)
        self.assertEqual(metric["numerator"], 30)
        self.assertIsNone(metric["denominator"])

    def test_xg_requires_complete_data_and_preserves_zero(self):
        rows = [match(fixture=1, minutes_played=45, xg=0.5),
                match(fixture=2, xg=None), match(fixture=3, xg=0)]
        metric = metrics(season_categories(27, rows, defaultdict(dict)))["xg"]
        self.assertIsNone(metric["value"])
        self.assertIsNone(metric["per90"])
        self.assertEqual(metric["observed_matches"], 2)
        rows[1]["xg"] = 0
        complete = metrics(season_categories(27, rows, defaultdict(dict)))["xg"]
        self.assertAlmostEqual(complete["per90"], 0.5 * 90 / 225)

    def test_no_observations_or_zero_minutes_do_not_produce_per90(self):
        for rows, stats in (([], defaultdict(dict)),
                            ([match()], defaultdict(dict)),
                            ([match(minutes_played=0)], defaultdict(dict, {(1, 8, 1): {52: 0}}))):
            with self.subTest(rows=rows):
                metric = metrics(season_categories(27, rows, stats))["goals"]
                self.assertIsNone(metric["per90"])
                self.assertEqual(metric["rank_value"], metric["value"])

    def test_sparse_zero_and_uncollected_or_unsupported_metrics_stay_distinct(self):
        rows = [match(), match(fixture=2)]
        stats = defaultdict(dict, {(1, 8, 1): {120: 50}, (2, 8, 1): {120: 60}})
        values = metrics(season_categories(26, rows, stats))
        for code in ("goals", "assists", "tackles", "interceptions", "key_passes", "fouls_drawn", "shots"):
            with self.subTest(code=code):
                self.assertEqual(values[code]["value"], 0)
                self.assertEqual(values[code]["per90"], 0)
        self.assertIsNone(values["final_third_passes"]["value"])
        stats[(2, 8, 1)] = {1490: 1}
        values = metrics(season_categories(26, rows, stats))
        self.assertIsNone(values["goals"]["value"])
        self.assertIsNone(values["key_passes"]["per90"])

    def test_pedri_and_bellingham_season_regression(self):
        # 운영 DB와 Sportmonks의 26/27 라리가 7경기 응답을 대조한 값이에요.
        cases = (
            ([45, 85, 77, 81, 66, 61, 86],
             {52: [None, None, None, 1, None, None, None],
              79: [None, 1, None, None, None, None, None],
              78: [1, 2, 1, 3, 1, None, 2], 100: [None, None, None, 1, None, None, 1],
              117: [1, 3, 2, None, None, 5, 4], 96: [None, 1, 2, None, 2, None, None],
              42: [None, None, 2, 2, None, None, 2]},
             {"goals": 1, "assists": 1, "tackles": 1.80, "interceptions": .36,
              "key_passes": 2.69, "fouls_drawn": .90, "shots": 1.08}),
            ([80, 78, 87, 90, 90, 22, 82],
             {52: [1, None, 1, None, 1, None, None],
              79: [None, 2, None, None, None, None, None],
              78: [2, 2, 2, 1, 1, None, 4], 100: [None, None, None, 1, 1, None, 1],
              117: [2, 4, 1, 3, 2, 2, 3], 96: [None, 4, 3, 3, 2, 2, 3],
              42: [2, 1, 5, 3, 4, 1, None]},
             {"goals": 3, "assists": 2, "tackles": 2.04, "interceptions": .51,
              "key_passes": 2.89, "fouls_drawn": 2.89, "shots": 2.72}),
        )
        for minutes, recorded, expected in cases:
            rows = [match(fixture=i, position=26, minutes_played=minute)
                    for i, minute in enumerate(minutes, 1)]
            stats = defaultdict(dict, {(i, 8, 1): {120: 50, **{
                type_id: values[i - 1] for type_id, values in recorded.items() if values[i - 1] is not None}}
                for i in range(1, 8)})
            result = metrics(season_categories(26, rows, stats))
            for code, value in expected.items():
                with self.subTest(minutes=minutes, code=code):
                    metric = result[code]
                    displayed = metric["value"] if code in {"goals", "assists"} else metric["per90"]
                    self.assertEqual(round(displayed, 2), value)
                    self.assertEqual(metric["rank_value"], displayed)

    def test_goals_and_assists_rank_by_total_instead_of_per90(self):
        own = season_categories(26, [match(minutes_played=90)],
                                defaultdict(dict, {(1, 8, 1): {52: 2, 79: 2}}))
        peer = season_categories(26, [match(minutes_played=30)],
                                 defaultdict(dict, {(1, 8, 1): {52: 1, 79: 1}}))
        rank_categories(own, [peer], includes_player=False)
        for code in ("goals", "assists"):
            self.assertEqual(metrics(own)[code]["rank"], 1)

    def test_mbappe_recoveries_and_dribbles_keep_all_seven_matches(self):
        # 26/27 라리가 7경기: 볼 회수는 2경기, 드리블 성공은 엘체전에서 생략됐어요.
        recoveries = [None, 3, None, 3, 1, 2, 3]
        attempts = [4, 4, 8, 10, 7, 3, 5]
        successes = [3, 3, 7, 5, 4, None, 3]
        rows = [match(fixture=i) for i in range(1, 8)]
        stats = defaultdict(dict)
        for i, (recovery, attempt, success) in enumerate(zip(recoveries, attempts, successes), 1):
            stats[(i, 8, 1)] = {120: 50, 108: attempt}
            if recovery is not None:
                stats[(i, 8, 1)][27271] = recovery
            if success is not None:
                stats[(i, 8, 1)][109] = success
        recorded = {i: {27271, 108, 109} for i in range(1, 8)}
        values = metrics(season_categories(27, rows, stats, recorded))
        self.assertAlmostEqual(values["ball_recoveries"]["per90"], 12 / 7)
        self.assertEqual(values["dribble_success_rate"]["value"], 61)
        self.assertEqual(values["dribble_success_rate"]["numerator"], 25)
        self.assertEqual(values["dribble_success_rate"]["denominator"], 41)
        self.assertEqual(values["ball_recoveries"]["observed_matches"], 7)
        # 경기 전체의 수집 여부가 없으면 추가 지표를 임의로 0으로 만들지 않아요.
        self.assertIsNone(metrics(season_categories(27, rows, stats))["ball_recoveries"]["value"])
        stats[(6, 8, 1)][109] = None
        self.assertIsNone(metrics(season_categories(27, rows, stats, recorded))["dribble_success_rate"]["value"])

    def test_clean_sheet_is_included_even_when_both_keepers_concede_zero(self):
        rows = [match(position=24, home_score=0, away_score=0), match(fixture=2, position=24)]
        stats = defaultdict(dict, {(1, 8, 1): {120: 37}, (2, 8, 1): {120: 30, 1535: 1}})
        values = metrics(season_categories(24, rows, stats))
        self.assertEqual(values["goals_conceded"]["value"], 1)
        self.assertEqual(values["goals_conceded"]["per90"], 0.5)
        stats[(1, 8, 1)][1535] = None
        self.assertIsNone(metrics(season_categories(24, rows, stats))["goals_conceded"]["value"])

    def test_match_cards_share_collected_zero_and_unknown_rules(self):
        rows = [match(position=24)]
        stats = defaultdict(dict, {(1, 8, 1): {120: 30, 116: None}})
        card = match_cards(rows, 24, stats, {1: {57, 123, 116}})[0]
        self.assertEqual([m["value"] for m in card["metrics"]], [0, 0, None])
        self.assertTrue(all(m["value"] is None for m in match_cards(rows, 24, defaultdict(dict))[0]["metrics"]))

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
        peer = [match(player=2, fixture=i, minutes_played=72) for i in range(1,6)]
        short_peer = [match(player=3, fixture=i, minutes_played=72 if i < 5 else 71) for i in range(1,6)]
        queries = []
        def fetch(sql, params):
            queries.append((sql, params))
            if sql.startswith('SELECT DISTINCT fixture_id,stat_type_id'):
                self.assertEqual(params, (1, 2, 3, 4, 5))
                self.assertIn('stat_value IS NOT NULL', sql)
                self.assertNotIn('player_id IN', sql)
                return [dict(fixture_id=1, stat_type_id=27271)]
            if sql.startswith(repo.MATCH_SELECT): return own + peer + short_peer
            if sql.startswith('SELECT fl.player_id'): return own + peer + short_peer
            if 'FROM team_seasons' in sql:
                self.assertEqual(params, (1,))
                return [dict(team_count=2)]
            if 'FROM fixture_player_stats' in sql:
                self.assertEqual(set(params[1:]), {1,2})
                return [dict(fixture_id=i, team_id=8, player_id=p,stat_type_id=52,value=0) for p in (1,2) for i in range(1,6)]
            if 'SELECT f.fixture_id' in sql: return [match(fixture=i) for i in range(1,9)]
            raise AssertionError(sql)
        data = repo._analysis(fetch, 1, {'season_id':1,'season_name':'2026/2027'}, [], [], datetime(2026,9,21))
        self.assertEqual(data['reference_minimum_minutes'], 360)
        self.assertEqual(data['reference_players'], 1)
        self.assertEqual(data['team_matches'], 8)
        self.assertEqual(data['starting_rate'], 62.5)
        self.assertEqual(data['top_stats'][0]['reference_count'], 2)
        self.assertEqual(len(data['performance']), 5)

    def test_early_season_top_stats_use_the_same_threshold_for_player_and_peers(self):
        own = [match(fixture=i, minutes_played=minute)
               for i, minute in enumerate((90, 90, 90, 25), 1)]
        peer = [match(player=2, fixture=i, minutes_played=45) for i in range(1,5)]
        short_peer = [match(player=3, fixture=i, minutes_played=45 if i < 4 else 44) for i in range(1,5)]
        other_position = [match(player=4, fixture=i, position=26) for i in range(1,5)]
        rows = own + peer + short_peer + other_position
        fixtures = [match(fixture=i) for i in range(1,5)]
        now = datetime(2026,9,21)

        def fetch(sql, params):
            if sql.startswith('SELECT f.fixture_id'):
                self.assertEqual(params, (1, now))
                self.assertIn(f'f.state_id IN ({repo.COMPLETED})', sql)
                self.assertIn('f.starting_at<=%s', sql)
                return fixtures
            if 'FROM team_seasons' in sql: return [dict(team_count=2)]
            if sql.startswith(repo.MATCH_SELECT) or sql.startswith('SELECT fl.player_id'): return rows
            if sql.startswith('SELECT DISTINCT fixture_id,stat_type_id'): return []
            if 'FROM fixture_player_stats' in sql:
                self.assertEqual(params, (1, 1, 2))
                return [dict(fixture_id=r['fixture_id'], team_id=8, player_id=r['player_id'],
                             stat_type_id=120, value=30) for r in own + peer]
            raise AssertionError(sql)

        for player_id in (1, 2):
            with self.subTest(player_id=player_id):
                data = repo._analysis(fetch, player_id, {'season_id':1,'season_name':'2026/2027'}, [], [], now)
                self.assertEqual(data['reference_minimum_minutes'], 180)
                self.assertEqual(data['reference_players'], 2)
                self.assertEqual(len(data['top_stats']), 3)
                self.assertTrue(all(m['reference_count'] == 2 for m in data['top_stats']))

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
            response = client.get('/players/1/detail?season_id=5').json()
            self.assertEqual(response['player_id'], 1)
            self.assertEqual(response['profile']['nationality_id'], 712)
            self.assertEqual(response['profile']['nationality'], 'South Korea')
            get.assert_called_with(1,5)
            get.side_effect=ValueError('Player has no record for this league season')
            self.assertEqual(client.get('/players/1/detail?season_id=6').status_code,404)
            self.assertEqual(client.get('/players/1/detail?season_id=-1').status_code,422)


if __name__ == '__main__':
    unittest.main()
