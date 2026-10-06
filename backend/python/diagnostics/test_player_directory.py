from datetime import datetime, timedelta
from decimal import Decimal
from fractions import Fraction
import sqlite3
import unittest
from unittest.mock import MagicMock, patch

with patch('mysql.connector.pooling.MySQLConnectionPool') as pool:
    pool.return_value.get_connection.side_effect = AssertionError('Operational DB access in tests')
    from one_touch_loader.api.repos import player_directory_repo as repo
    from one_touch_loader.api.routes import players as routes
    from one_touch_loader.api.routes import users as user_routes
    from one_touch_loader.api.deps import get_user_id

from one_touch_loader.core.player_rating_percentile import HistoricalPercentile


def appearances(pid=1, recent=8, previous=6, current_matches=6):
    return [dict(player_id=pid, name=f'Player {pid}', image=None, fixture_id=i,
                 starting_at=datetime(2026, 9, 20) - timedelta(days=i), rating=recent if i < 3 else previous,
                 is_current_season=i < current_matches)
            for i in range(6)]


class PlayerDirectoryTests(unittest.TestCase):
    def test_following_route_batches_current_numbers_and_keeps_saved_order(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        app = FastAPI()
        app.include_router(user_routes.router)
        app.dependency_overrides[get_user_id] = lambda: 42
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        items = [dict(player_id=pid, name=f'Player {pid}', image_path=None) for pid in (2, 1, 3)]
        cur.fetchall.side_effect = [items, [
            dict(player_id=1, team_id=8, is_current=1, jersey_number=9),
            dict(player_id=1, team_id=9, is_current=1, jersey_number=17),
            dict(player_id=2, team_id=8, is_current=1, jersey_number=None),
            dict(player_id=2, team_id=8, is_current=0, jersey_number=10),
        ], [dict(player_id=1, team_id=9, starting_at=datetime(2026, 9, 20))]]
        with patch.object(repo, 'get_conn', return_value=conn):
            response = TestClient(app).get('/users/me/following/players')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['items'], [
            dict(item, jersey_number=number) for item, number in zip(items, (None, 17, None))])
        self.assertEqual(cur.execute.call_count, 3)
        self.assertEqual(cur.execute.call_args_list[0].args[1], (42,))
        self.assertIn('ORDER BY f.position', cur.execute.call_args_list[0].args[0])
        for call in cur.execute.call_args_list[1:]:
            self.assertEqual(call.args[1], (2, 1, 3))
        conn.start_transaction.assert_called_once_with(readonly=True, consistent_snapshot=True)
        conn.rollback.assert_called_once()
        conn.close.assert_called_once()
        conn.commit.assert_not_called()

    def test_following_query_count_does_not_grow_with_player_count(self):
        for count in (1, 20, 1000):
            with self.subTest(count=count):
                conn = MagicMock()
                cur = conn.cursor.return_value.__enter__.return_value
                cur.fetchall.side_effect = [[dict(player_id=pid) for pid in range(1, count + 1)], [], []]
                with patch.object(repo, 'get_conn', return_value=conn):
                    result = repo.get_following_players(42)
                self.assertEqual(len(result['items']), count)
                self.assertEqual(cur.execute.call_count, 3)
                conn.rollback.assert_called_once()

    def test_empty_following_list_skips_squad_queries(self):
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchall.return_value = []
        with patch.object(repo, 'get_conn', return_value=conn):
            self.assertEqual(repo.get_following_players(42), {'items': []})
        cur.execute.assert_called_once()

    def test_following_releases_connection_after_a_query_failure(self):
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchall.side_effect = [[dict(player_id=1)], RuntimeError('query failed')]
        with patch.object(repo, 'get_conn', return_value=conn), self.assertRaisesRegex(RuntimeError, 'query failed'):
            repo.get_following_players(42)
        conn.rollback.assert_called_once()
        conn.close.assert_called_once()
        conn.commit.assert_not_called()

    def test_transfer_ratings_are_weighted_and_ranked_once(self):
        rows = [dict(player_id=1, name='Transfer', rating_sum=Decimal(9), rated_matches=1),
                dict(player_id=1, name='Transfer', rating_sum=Decimal(63), rated_matches=9)]
        merged = repo.merge_current_scores(rows, HistoricalPercentile([Fraction(7), Fraction(8)]))
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]['rated_matches'], 10)
        self.assertEqual(merged[0]['rating_sum'], 72)
        self.assertEqual(merged[0]['percentile_score'], 50)
        self.assertEqual(rows[0]['rating_sum'], 9)

    def test_watch_compares_two_non_overlapping_windows_across_years(self):
        rows = appearances(current_matches=3) + appearances(2, recent=7, previous=6.5)
        for row, rating in zip(rows[:6], (9, 8, 7, 5, 6, 7)):
            row['rating'] = rating
        rows[5]['starting_at'] = datetime(2025, 12, 1)
        result = repo.watch_players(list(reversed(rows)))
        self.assertEqual([r['player_id'] for r in result], [1, 2])
        self.assertEqual((result[0]['recent_average'], result[0]['previous_average'], result[0]['change']), (8, 6, 2))

    def test_watch_requires_six_actual_appearances_all_rated(self):
        for unrated in range(6):
            with self.subTest(unrated=unrated):
                rows = appearances()
                rows[unrated]['rating'] = None
                rows += [dict(rows[-1], fixture_id=99, rating=6, starting_at=datetime(2024, 1, 1))]
                self.assertEqual(repo.watch_players(rows), [])
        self.assertEqual(repo.watch_players(appearances()[:5]), [])
        self.assertEqual(repo.watch_players(appearances(recent=5, previous=6)), [])
        self.assertEqual(repo.watch_players(appearances(recent=6, previous=6)), [])

    def test_watch_requires_all_three_latest_appearances_in_current_season(self):
        for current_matches in range(3):
            with self.subTest(current_matches=current_matches):
                self.assertEqual(repo.watch_players(appearances(current_matches=current_matches)), [])
        for older_match in range(3):
            with self.subTest(older_match=older_match):
                rows = appearances()
                rows[older_match]['is_current_season'] = False
                self.assertEqual(repo.watch_players(rows), [])

    def test_watch_ignores_appearances_before_the_latest_six(self):
        rows = appearances()
        rows.append(dict(rows[-1], fixture_id=99, rating=None,
                         starting_at=datetime(2024, 1, 1), is_current_season=False))
        self.assertEqual(repo.watch_players(rows), repo.watch_players(appearances()))

    def test_watch_orders_by_growth_then_recent_average_and_limits_to_ten(self):
        rows = appearances(1, recent=9, previous=7) + appearances(2, recent=8, previous=5)
        for pid in range(3, 13):
            rows += appearances(pid)
        self.assertEqual([r['player_id'] for r in repo.watch_players(rows)], [2, 1, *range(3, 11)])

    def test_watch_is_read_only_and_rolls_back(self):
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchall.side_effect = [appearances(), [], []]
        with patch.object(repo, 'get_conn', return_value=conn):
            result = repo.get_ones_to_watch()['items']
        self.assertEqual(len(result), 1)
        self.assertEqual({key: result[0][key] for key in ('jersey_number', 'team_id', 'team_name')},
                         dict(jersey_number=None, team_id=None, team_name=None))
        conn.start_transaction.assert_called_once_with(readonly=True)
        conn.rollback.assert_called_once()
        conn.commit.assert_not_called()
        sql = cur.execute.call_args_list[0].args[0]
        self.assertIn('ROW_NUMBER()', sql)
        self.assertNotIn('rating IS NOT NULL AND', sql)

    def test_watch_route_returns_current_squad_numbers_and_preserves_missing_numbers(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        app = FastAPI()
        app.include_router(routes.router)
        app.dependency_overrides[get_user_id] = lambda: 1
        client = TestClient(app)
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchall.side_effect = [
            appearances() + appearances(2, recent=7, previous=6.5),
            [dict(player_id=1, team_id=8, team_name='Former club', is_current=1, jersey_number=9),
             dict(player_id=1, team_id=9, team_name='Current club', is_current=1, jersey_number=17),
             dict(player_id=2, team_id=8, team_name='Other club', is_current=1, jersey_number=None),
             dict(player_id=2, team_id=8, team_name='Other club', is_current=0, jersey_number=10)],
            [dict(player_id=1, team_id=9, starting_at=datetime(2026, 9, 20)),
             dict(player_id=1, team_id=8, starting_at=datetime(2026, 8, 1))],
        ]
        with patch.object(repo, 'get_conn', return_value=conn):
            response = client.get('/players/ones-to-watch')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {
            'items': [dict(item, jersey_number=number, team_id=team_id, team_name=team_name)
                      for item, number, team_id, team_name in zip(
                          repo.watch_players(appearances() + appearances(2, recent=7, previous=6.5)),
                          (17, None), (9, 8), ('Current club', 'Other club'))],
            'scope': 'all_competitions_recent_6_appearances',
        })
        self.assertEqual(cur.execute.call_count, 3)
        for call in cur.execute.call_args_list[1:]:
            self.assertEqual(call.args[1], (1, 2))

    def test_watch_without_qualifying_players_skips_squad_queries(self):
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchall.return_value = appearances(recent=5, previous=6)
        with patch.object(repo, 'get_conn', return_value=conn):
            self.assertEqual(repo.get_ones_to_watch()['items'], [])
        cur.execute.assert_called_once()

    def test_route_filters_and_authentication(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        app = FastAPI()
        app.include_router(routes.router)
        app.dependency_overrides[get_user_id] = lambda: 1
        client = TestClient(app)
        with patch.object(routes, 'get_current_ranking', return_value={'season_name': None, 'leagues': [], 'items': [], 'total': 0, 'limit': 20, 'offset': 0, 'competition_id': 8, 'position': 'FW'}) as fn:
            self.assertEqual(client.get('/players/ranking-current?position=FW&competition_id=8').status_code, 200)
            fn.assert_called_once_with(8, 'FW', limit=20, offset=0)
            self.assertEqual(client.get('/players/ranking-current?position=ST').status_code, 422)
            self.assertEqual(client.get('/players/ranking-current?competition_id=999').status_code, 422)


class WatchSeasonQueryTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.row_factory = sqlite3.Row
        self.db.create_function('UTC_TIMESTAMP', 0, lambda: '2026-10-06 00:00:00')
        self.addCleanup(self.db.close)
        self.db.executescript('''
            CREATE TABLE competitions (competition_id INTEGER PRIMARY KEY,competition_type TEXT);
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY,competition_id INTEGER,name TEXT,is_current INTEGER);
            CREATE TABLE stages (stage_id INTEGER PRIMARY KEY,season_id INTEGER);
            CREATE TABLE team_squad_members (player_id INTEGER,season_id INTEGER);
            CREATE TABLE players (player_id INTEGER PRIMARY KEY,display_name TEXT,image_path TEXT);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY,stage_id INTEGER,starting_at TEXT,state_id INTEGER);
            CREATE TABLE fixture_lineups (fixture_id INTEGER,player_id INTEGER,team_id INTEGER,
                lineup_type_id INTEGER,minutes_played INTEGER,rating REAL);
            CREATE TABLE fixture_events (fixture_id INTEGER,team_id INTEGER,event_type_id INTEGER,
                player_id INTEGER,related_player_id INTEGER);
            INSERT INTO competitions VALUES (8,'league'),(999,'domestic_cup');
            INSERT INTO seasons VALUES (1,8,'2026/2027',1),(2,8,'2025/2026',0),
                (3,999,'2026/2027',1),(4,999,'2025/2026',1);
            INSERT INTO stages VALUES (1,1),(2,2),(3,3),(4,4);
        ''')

    def add_player(self, pid, stages):
        self.db.execute('INSERT INTO players VALUES (?,?,NULL)', (pid, f'Player {pid}'))
        self.db.execute('INSERT INTO team_squad_members VALUES (?,1)', (pid,))
        for i, stage in enumerate(stages):
            fid = pid * 10 + i
            played_at = datetime(2026, 9, 20) - timedelta(days=i)
            self.db.execute('INSERT INTO fixtures VALUES (?,?,?,5)', (fid, stage, played_at.isoformat(' ')))
            self.db.execute('INSERT INTO fixture_lineups VALUES (?,?,8,11,90,?)',
                            (fid, pid, 8 if i < 3 else 6))

    def watch(self):
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cursor = self.db.cursor()
        self.addCleanup(cursor.close)
        cur.execute.side_effect = cursor.execute
        cur.fetchall.side_effect = lambda: [dict(r) for r in cursor.fetchall()]
        teams = lambda fetch, ids: {pid: None for pid in ids}
        with patch.object(repo, 'get_conn', return_value=conn), patch.object(repo, 'get_current_player_teams', teams):
            return repo.get_ones_to_watch()['items']

    def test_current_season_is_shared_across_competitions_and_only_required_for_latest_three(self):
        self.add_player(1, [1, 3, 1, 2, 2, 2])
        self.add_player(2, [2, 2, 2, 2, 2, 2])
        self.add_player(3, [1, 1, 2, 2, 2, 2])
        # 지난 시즌 컵대회의 is_current가 남아 있어도 이번 시즌 경기로 보지 않아요.
        self.add_player(4, [1, 4, 1, 2, 2, 2])
        self.add_player(5, [1, 1, 1, 1, 1, 1])
        result = self.watch()
        self.assertEqual([r['player_id'] for r in result], [1, 5])
        self.assertTrue(all((r['recent_average'], r['previous_average'], r['change']) == (8, 6, 2)
                            for r in result))

    def test_unplayed_and_unfinished_matches_cannot_complete_the_current_window(self):
        for pid in range(1, 5):
            self.add_player(pid, [1, 1, 1, 2, 2, 2])
        self.db.execute('UPDATE fixture_lineups SET lineup_type_id=12,minutes_played=0,rating=NULL WHERE fixture_id=10')
        self.db.execute('UPDATE fixtures SET state_id=2 WHERE fixture_id=20')
        self.db.execute("UPDATE fixtures SET starting_at='2026-12-01 00:00:00' WHERE fixture_id=30")
        self.assertEqual([r['player_id'] for r in self.watch()], [4])


if __name__ == '__main__':
    unittest.main()
