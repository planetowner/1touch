"""비교 후보는 포지션을 먼저 거르고, 선수 수와 무관하게 묶어서 조회해요."""
import unittest
from unittest.mock import MagicMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

with patch('mysql.connector.pooling.MySQLConnectionPool') as pool:
    pool.return_value.get_connection.side_effect = AssertionError('Operational DB access in tests')
    from one_touch_loader.api.repos import player_detail_repo as repo
    from one_touch_loader.api.routes import players as routes
    from one_touch_loader.api.deps import get_user_id


def candidate(pid):
    return dict(player_id=pid, name=f'Player {pid:03}', image=None)


def source_position(pid, position):
    return dict(player_id=pid,team_id=8,position_group_id=position)


class ComparisonCandidatesTests(unittest.TestCase):
    def page(self, candidates, appearances, **kwargs):
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        cur.fetchall.side_effect = [[{'name': '2026/2027'}], appearances]
        teams = {pid: dict(team_id=8, team_name='Club', jersey_number=9) for pid in range(1, 126)}
        with patch.object(repo, 'list_player_comparison_candidates', return_value=candidates) as lookup, \
             patch.object(repo, 'get_conn', return_value=conn), \
             patch.object(repo, 'get_current_player_teams', return_value=teams) as team_lookup, \
             patch.object(repo, 'get_player_detail') as detail:
            result = repo.get_player_comparison_candidates('', **kwargs)
        lookup.assert_called_once_with('', limit=None)
        detail.assert_not_called()
        conn.start_transaction.assert_called_once_with(readonly=True, consistent_snapshot=True)
        conn.rollback.assert_called_once()
        conn.commit.assert_not_called()
        conn.close.assert_called_once()
        return result, cur, team_lookup

    def test_filters_before_pagination_even_beyond_the_old_hundred_candidate_limit(self):
        candidates = [candidate(pid) for pid in range(1, 126)]
        positions = [source_position(pid, 25 if pid <= 100 else 27) for pid in range(1, 126)]
        first, cur, teams = self.page(candidates, positions, position='FW', excluded_id=102, limit=20)
        expected = [pid for pid in range(101, 122) if pid != 102]
        self.assertEqual([r['player_id'] for r in first['players']], expected)
        self.assertEqual(first['total'], 24)
        self.assertEqual(first['players'][0]['position_group'], 'FW')
        self.assertEqual(first['players'][0]['jersey_number'], 9)
        self.assertEqual(teams.call_args.args[1], expected)
        self.assertEqual(cur.execute.call_count, 2)
        second, _, _ = self.page(candidates, positions, position='FW', excluded_id=102, limit=20, offset=20)
        self.assertEqual([r['player_id'] for r in second['players']], [122, 123, 124, 125])
        self.assertEqual(second['total'], 24)

    def test_uses_provider_positions_without_requiring_appearances(self):
        positions = [source_position(1, 27), source_position(2, 26), source_position(3, None)]
        result, _, _ = self.page([candidate(pid) for pid in [1, 2, 3]], positions)
        self.assertEqual([row['position_group'] for row in result['players']], ['FW', 'MF', None])
        filtered, _, _ = self.page([candidate(pid) for pid in [1, 2, 3]], positions, position='FW')
        self.assertEqual([row['player_id'] for row in filtered['players']], [1])

    def test_out_of_range_page_has_total_but_no_team_ids_to_load(self):
        result, _, teams = self.page([candidate(1)], [source_position(1, 27)], limit=20, offset=20)
        self.assertEqual(result['players'], [])
        self.assertEqual(result['total'], 1)
        self.assertEqual(teams.call_args.args[1], [])

    def test_empty_search_skips_position_and_team_queries(self):
        with patch.object(repo, 'list_player_comparison_candidates', return_value=[]), \
             patch.object(repo, 'get_conn') as conn:
            result = repo.get_player_comparison_candidates('missing', limit=20)
        self.assertEqual(result, dict(players=[], season_name=None, total=0, limit=20, offset=0))
        conn.assert_not_called()

    def test_failed_position_query_releases_connection_and_propagates_error(self):
        conn = MagicMock()
        conn.cursor.return_value.__enter__.return_value.execute.side_effect = RuntimeError('query failed')
        with patch.object(repo, 'list_player_comparison_candidates', return_value=[candidate(1)]), \
             patch.object(repo, 'get_conn', return_value=conn), self.assertRaisesRegex(RuntimeError, 'query failed'):
            repo.get_player_comparison_candidates('')
        conn.rollback.assert_called_once()
        conn.close.assert_called_once()

    def test_unlimited_lookup_keeps_the_shared_name_order_without_a_hidden_cap(self):
        conn = MagicMock()
        cur = conn.cursor.return_value.__enter__.return_value
        with patch.object(repo, 'get_conn', return_value=conn), \
             patch.object(repo, 'korean_name_ids', return_value=(1,)):
            repo.list_player_comparison_candidates('선수', limit=None)
        sql, params = cur.execute.call_args.args
        self.assertIn('ORDER BY p.display_name,p.player_id', sql)
        self.assertNotIn('LIMIT', sql)
        self.assertEqual(params, ('%선수%', 1))

    def test_route_filters_pagination_and_auth_contract(self):
        app = FastAPI()
        app.include_router(routes.router)
        app.dependency_overrides[get_user_id] = lambda: 1
        client = TestClient(app)
        page = dict(players=[], season_name='2026/2027', total=0, limit=20, offset=40)
        with patch.object(routes, 'get_player_comparison_candidates', return_value=page) as lookup:
            response = client.get('/players/comparison-candidates?q=이름&position=FW&excluded_id=7&limit=20&offset=40')
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json(), page)
            lookup.assert_called_once_with('이름', position='FW', excluded_id=7, limit=20, offset=40)
            lookup.reset_mock()
            for query in ['position=CB', 'limit=0', 'limit=101', 'offset=-1', 'excluded_id=0', 'q=' + 'a' * 101]:
                self.assertEqual(client.get('/players/comparison-candidates?' + query).status_code, 422)
            app.dependency_overrides.clear()
            self.assertEqual(client.get('/players/comparison-candidates').status_code, 401)
            lookup.assert_not_called()


if __name__ == '__main__':
    unittest.main()
