from datetime import datetime, timedelta
from decimal import Decimal
from fractions import Fraction
import unittest
from unittest.mock import MagicMock, patch

with patch('mysql.connector.pooling.MySQLConnectionPool') as pool:
    pool.return_value.get_connection.side_effect = AssertionError('Operational DB access in tests')
    from one_touch_loader.api.repos import player_directory_repo as repo
    from one_touch_loader.api.routes import players as routes
    from one_touch_loader.api.deps import get_user_id

from one_touch_loader.core.player_rating_percentile import HistoricalPercentile


def appearances(pid=1, recent=8, previous=6):
    return [dict(player_id=pid, name=f'Player {pid}', image=None, fixture_id=i,
                 starting_at=datetime(2026, 9, 20) - timedelta(days=i), rating=recent if i < 5 else previous)
            for i in range(10)]


class PlayerDirectoryTests(unittest.TestCase):
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
        rows = appearances() + appearances(2, recent=7, previous=6.5)
        rows[9]['starting_at'] = datetime(2025, 12, 1)
        result = repo.watch_players(list(reversed(rows)))
        self.assertEqual([r['player_id'] for r in result], [1, 2])
        self.assertEqual((result[0]['recent_average'], result[0]['previous_average'], result[0]['change']), (8, 6, 2))

    def test_watch_requires_ten_actual_appearances_all_rated(self):
        rows = appearances()
        rows[3]['rating'] = None
        rows += [dict(rows[-1], fixture_id=99, starting_at=datetime(2024, 1, 1))]
        self.assertEqual(repo.watch_players(rows), [])
        self.assertEqual(repo.watch_players(appearances()[:9]), [])
        self.assertEqual(repo.watch_players(appearances(recent=5, previous=6)), [])

    def test_watch_is_read_only_and_rolls_back(self):
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchall.return_value = appearances()
        with patch.object(repo, 'get_conn', return_value=conn):
            self.assertEqual(len(repo.get_ones_to_watch()['items']), 1)
        conn.start_transaction.assert_called_once_with(readonly=True)
        conn.rollback.assert_called_once()
        conn.commit.assert_not_called()
        sql = cur.execute.call_args.args[0]
        self.assertIn('ROW_NUMBER()', sql)
        self.assertNotIn('rating IS NOT NULL AND', sql)

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


if __name__ == '__main__':
    unittest.main()
