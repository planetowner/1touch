"""홈의 조회 팀 선택이 최애팀 저장과 분리되는지 확인해요."""
import unittest
from unittest.mock import patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.api.routes import home as home_route
    from one_touch_loader.api.services import home_service
    from one_touch_loader.api.repos import teams_repo


class HomeTeamSelectionTests(unittest.TestCase):
    def setUp(self):
        self.teams = [
            {'team_id': 83, 'name': 'FC Barcelona'},
            {'team_id': 9, 'name': 'Manchester City'},
        ]
        self.repositories = {}
        for name, result in {
            'list_following_team_ids': [83, 9],
            'get_teams': self.teams,
            'get_favorite_team_id': 83,
            'get_team_next_fixture': None,
            'get_team_last_fixture': None,
            'list_team_fixtures': [],
            'get_team_highlights': None,
            'get_current_team_standing': None,
        }.items():
            patcher = patch.object(home_service, name, return_value=result)
            self.repositories[name] = patcher.start()
            self.addCleanup(patcher.stop)
        write_patcher = patch.object(teams_repo, 'set_following_and_favorite')
        self.save_preferences = write_patcher.start()
        self.addCleanup(write_patcher.stop)

    def load(self, team_id=None):
        return home_service.build_home_payload(
            user_id=7, start_date='2026-09-01', end_date='2026-09-30',
            viewer_country='KR', team_id=team_id,
        )

    def test_omitting_team_uses_the_saved_favorite(self):
        self.assertEqual(self.load()['favorite_team'], self.teams[0])
        self.repositories['get_favorite_team_id'].assert_called_once_with(7)
        self.save_preferences.assert_not_called()

    def test_repeated_switches_query_all_content_without_saving_preferences(self):
        for team_id in [9, 83, 9]:
            payload = self.load(team_id)
            self.assertEqual(payload['favorite_team']['team_id'], team_id)
            self.assertEqual(payload['following_teams'], self.teams)
            self.repositories['get_team_next_fixture'].assert_called_with(team_id)
            self.repositories['get_team_last_fixture'].assert_called_with(team_id)
            self.repositories['list_team_fixtures'].assert_called_with(
                team_id, status=None, start_date='2026-09-01', end_date='2026-09-30',
                limit=200, offset=0,
            )
            self.repositories['get_team_highlights'].assert_called_with(team_id, 'KR')
            self.repositories['get_current_team_standing'].assert_called_with(team_id)
        self.repositories['get_favorite_team_id'].assert_not_called()
        self.save_preferences.assert_not_called()
        self.assertEqual(self.load()['favorite_team']['team_id'], 83)

    def test_rejects_a_team_outside_the_followed_list(self):
        with self.assertRaises(HTTPException) as raised:
            self.load(503)
        self.assertEqual(raised.exception.status_code, 400)
        self.repositories['get_team_next_fixture'].assert_not_called()
        self.save_preferences.assert_not_called()

    def test_home_route_preserves_position_and_movement_for_the_viewed_team(self):
        self.repositories['get_current_team_standing'].side_effect = lambda team_id: {
            'team_id': team_id, 'position': 2 if team_id == 9 else 1,
            'rank_delta': -1 if team_id == 9 else 2,
            'matches_played': 5, 'won': 4, 'draw': 0, 'lost': 1,
            'goals_for': 12, 'goals_against': 5, 'goal_diff': 7,
            'points': 12, 'last5_form': ['W', 'W', 'W', 'L', 'W'],
        }
        app = FastAPI()
        app.include_router(home_route.router, prefix='/v1')
        app.dependency_overrides[home_route.get_user_id] = lambda: 7
        with TestClient(app) as client:
            for team_id, position, delta in [(9, 2, -1), (83, 1, 2)]:
                response = client.get('/v1/home', params={'team_id': team_id})
                self.assertEqual(response.status_code, 200)
                standing = response.json()['standing']
                self.assertEqual(standing['team_id'], team_id)
                self.assertEqual(standing['position'], position)
                self.assertEqual(standing['rank_delta'], delta)

    def test_get_route_passes_the_selected_team_to_the_shared_home_query(self):
        app = FastAPI()
        app.include_router(home_route.router, prefix='/v1')
        app.dependency_overrides[home_route.get_user_id] = lambda: 7
        with TestClient(app) as client:
            for team_id in [9, 83, 9]:
                response = client.get('/v1/home', params={
                    'team_id': team_id, 'viewer_country': 'KR',
                    'start': '2026-09-01', 'end': '2026-09-30',
                })
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()['favorite_team']['team_id'], team_id)
            self.assertEqual(client.get('/v1/home').json()['favorite_team']['team_id'], 83)
            self.assertEqual(client.get('/v1/home?team_id=503').status_code, 400)
            self.assertEqual(client.get('/v1/home?team_id=0').status_code, 422)
        self.save_preferences.assert_not_called()


if __name__ == '__main__':
    unittest.main()
