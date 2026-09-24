"""같은 JSON을 FastAPI 응답과 Flutter 저장소에서 검증해요. 운영 DB는 사용하지 않아요."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

with patch('mysql.connector.pooling.MySQLConnectionPool') as pool:
    pool.return_value.get_connection.side_effect = AssertionError('Operational DB access in tests')
    from one_touch_loader.api.routes import catalog, search, players, competitions
    from one_touch_loader.api.repos import catalog_repo, search_repo, fixtures_repo
    from one_touch_loader.api.deps import get_user_id

FIXTURES = Path(__file__).resolve().parents[3] / 'frontend/test/fixtures'


def sample(name):
    return json.loads((FIXTURES / f'{name}.json').read_text())


class AppApiContractsTests(unittest.TestCase):
    def setUp(self):
        self.app = FastAPI()
        for module in (catalog, search, players, competitions):
            self.app.include_router(module.router, prefix='/v1')
        self.app.dependency_overrides[get_user_id] = lambda: 1
        self.client = TestClient(self.app)

    def test_shared_response_samples_and_openapi(self):
        cases = [
            (catalog, 'get_catalog', '/v1/catalog', 'api_catalog'),
            (search, 'search', '/v1/search?q=Example', 'api_search'),
            (players, 'get_current_ranking', '/v1/players/ranking-current', 'api_player_directory'),
            (players, 'get_player_detail', '/v1/players/9967153/detail', 'player_detail'),
        ]
        for module, name, url, fixture in cases:
            with self.subTest(url=url), patch.object(module, name, return_value=sample(fixture)):
                response = self.client.get(url)
                self.assertEqual(response.status_code, 200)
                # 응답 모델이 빼먹은 필드는 프런트와 공유하는 샘플 비교에서 잡혀요.
                expected = sample(fixture)
                self.assertEqual(expected, response.json())
        spec = self.app.openapi()
        for path in ['/v1/catalog', '/v1/search', '/v1/players/{player_id}/detail',
                     '/v1/players/ranking-current', '/v1/players/ones-to-watch',
                     '/v1/players/comparison-candidates', '/v1/players/{player_id}/club-history']:
            self.assertIn('$ref', spec['paths'][path]['get']['responses']['200']['content']['application/json']['schema'])

    def test_search_requires_auth_and_rejects_invalid_queries(self):
        with patch.object(search, 'search') as query:
            for suffix in ['?q=a&limit=0', '?q=a&limit=101', '?q=' + 'a' * 101, '']:
                self.assertEqual(self.client.get('/v1/search' + suffix).status_code, 422)
            self.app.dependency_overrides.clear()
            self.assertIn(self.client.get('/v1/search?q=a').status_code, (401, 403))
            self.assertIn(self.client.get('/v1/catalog').status_code, (401, 403))
            query.assert_not_called()

    def test_shared_bracket_response(self):
        with patch.object(competitions, 'find_bracket_season', return_value={'season_id': 100, 'name': '2026/2027'}), \
             patch.object(competitions, 'get_bracket', return_value=sample('api_bracket')):
            response = self.client.get('/v1/competitions/2/bracket?season_id=100')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), sample('api_bracket'))

    def test_catalog_reads_existing_columns_and_normalizes_booleans(self):
        data = sample('api_catalog')
        data['seasons'][0]['is_current'] = 1
        with patch.object(catalog_repo, 'fetch_all_dict', side_effect=data.values()) as fetch:
            result = catalog_repo.get_catalog()
            response = catalog.CatalogResponse.model_validate(result).model_dump()
        self.assertIs(response['seasons'][0]['is_current'], True)
        self.assertEqual(response['competitions'][1]['short_code'], 'UCL')
        self.assertIn('short_code', fetch.call_args_list[1].args[0])
        for call in fetch.call_args_list:
            sql = call.args[0]
            self.assertTrue(sql.lstrip().startswith('SELECT'))
            self.assertNotIn('starting_at', sql)
            self.assertNotIn('league_id', sql)

    def test_search_reuses_player_lookup_and_parameterizes_names(self):
        query = "이강인' OR 1=1"
        with patch.object(search_repo, 'korean_name_ids', return_value=(8,)), \
             patch.object(search_repo, 'fetch_all_dict', return_value=[] ) as teams, \
             patch.object(search_repo, 'list_player_comparison_candidates', return_value=[]) as player, \
             patch.object(search_repo, 'search_fixtures', return_value=[]) as fixtures:
            self.assertEqual(search_repo.search(query, 12), dict(players=[], teams=[], fixtures=[]))
            player.assert_called_once_with(query, limit=12)
            fixtures.assert_called_once_with(query, team_ids=(8,), limit=12)
            self.assertNotIn(query, teams.call_args.args[0])
            self.assertIn('%' + query + '%', teams.call_args.args[1])
        with patch.object(search_repo, 'fetch_all_dict') as fetch:
            self.assertEqual(search_repo.search('  ', 12), dict(players=[], teams=[], fixtures=[]))
            fetch.assert_not_called()

    def test_fixture_search_uses_same_status_and_bound_parameters(self):
        row = sample('api_search')['fixtures'][0]
        with patch.object(fixtures_repo, 'fetch_all_dict', return_value=[dict(row)]) as fetch:
            self.assertEqual(fixtures_repo.search_fixtures('Example', team_ids=(8,), limit=12), [row])
        sql, params = fetch.call_args.args
        self.assertEqual(sql.count('%s'), len(params))
        self.assertEqual(params[-3:], (8, 8, 12))


if __name__ == '__main__':
    unittest.main()
