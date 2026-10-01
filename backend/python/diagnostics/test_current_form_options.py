"""시즌 이름 필터와 기존 Current Form 응답 계약을 검증해요."""
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

with patch('mysql.connector.pooling.MySQLConnectionPool') as pool:
    pool.return_value.get_connection.side_effect = AssertionError('Operational DB access in tests')
    from one_touch_loader.api.repos import points_pace_repo as repo
    from one_touch_loader.api.routes import teams as routes
    from one_touch_loader.api.deps import get_user_id


class CurrentFormOptionsTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(routes.router, prefix='/v1')
        app.dependency_overrides[get_user_id] = lambda: 1
        self.client = TestClient(app)

    def test_route_forwards_season_search_and_pagination_without_response_changes(self):
        rows = [dict(team_id=83, team_name='Barcelona', team_short_code='BAR',
                     team_logo=None, competition_id=564, season_id=23621,
                     season_name='2024/2025', rounds_available=38, latest_round=38)]
        with patch.object(routes, 'get_team', return_value={'team_id': 83}), \
             patch.object(routes, 'list_current_form_options', return_value=rows) as query:
            result = self.client.get('/v1/teams/83/current-form/options', params={
                'season_name': '2024/2025', 'search': 'Barcelona', 'limit': 17, 'offset': 34,
            })
            self.assertEqual(result.status_code, 200)
            self.assertEqual(result.json(), {'items': rows, 'limit': 17})
            query.assert_called_once_with(search='Barcelona', limit=17, offset=34, season_name='2024/2025')

    def test_omitting_season_keeps_the_legacy_defaults(self):
        with patch.object(routes, 'get_team', return_value={'team_id': 83}), \
             patch.object(routes, 'list_current_form_options', return_value=[]) as query:
            result = self.client.get('/v1/teams/83/current-form/options')
            self.assertEqual(result.json(), {'items': [], 'limit': 200})
            query.assert_called_once_with(search=None, limit=200, offset=0, season_name=None)

    def test_validates_parameters_and_missing_team(self):
        with patch.object(routes, 'get_team', return_value=None), \
             patch.object(routes, 'list_current_form_options') as query:
            for params in [{'season_name': ''}, {'season_name': 'x' * 101},
                           {'limit': 0}, {'limit': 1001}, {'offset': -1}]:
                self.assertEqual(self.client.get('/v1/teams/83/current-form/options', params=params).status_code, 422)
            self.assertEqual(self.client.get('/v1/teams/83/current-form/options').status_code, 404)
            query.assert_not_called()

    def test_filters_by_name_before_grouping_and_pagination_with_korean_search(self):
        with patch.object(repo, 'fetch_all_dict', return_value=[]) as fetch, \
             patch.object(repo, 'korean_name_ids', return_value=(8,)):
            repo.list_current_form_options(search=' 리버풀 ', limit=17, offset=34, season_name='2024/2025')
        sql, params = fetch.call_args.args
        self.assertIn('s.competition_id IN (8, 82, 301, 384, 564)', sql)
        self.assertLess(sql.index('AND s.name = %s'), sql.index('GROUP BY'))
        self.assertLess(sql.index('GROUP BY'), sql.index('LIMIT %s OFFSET %s'))
        self.assertNotIn('s.season_id = %s', sql)
        self.assertNotIn('2024/2025', sql)
        self.assertEqual(params, ('2024/2025', '리버풀', '리버풀', '리버풀', 8, 17, 34))

    def test_omitting_season_keeps_sql_parameters_and_result_rules(self):
        with patch.object(repo, 'fetch_all_dict', return_value=[]) as fetch, \
             patch.object(repo, 'korean_name_ids', return_value=()):
            repo.list_current_form_options(search=None, limit=200, offset=200)
        sql, params = fetch.call_args.args
        self.assertNotIn('AND s.name = %s', sql)
        self.assertIn(repo.ELIGIBLE_RESULT_SQL, sql)
        self.assertIn("r.name REGEXP '^[0-9]+$'", sql)
        self.assertIn('ORDER BY s.name DESC, t.name ASC, t.team_id, s.season_id', sql)
        self.assertEqual(params, ('', '', '', 200, 200))


if __name__ == '__main__':
    unittest.main()
