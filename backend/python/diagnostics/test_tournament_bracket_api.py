import json
import sqlite3
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

with patch('mysql.connector.pooling.MySQLConnectionPool') as pool:
    pool.return_value.get_connection.side_effect = AssertionError('Operational DB access in isolated tests')
    from one_touch_loader.api.main import create_app
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.repos import tournament_bracket_repo as repo

from diagnostics.test_tournament_bracket import build, fixture


class BracketApiTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:', check_same_thread=False)
        self.addCleanup(self.db.close)
        self.db.row_factory = sqlite3.Row
        self.db.executescript('''
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY,competition_id INTEGER,name TEXT,is_current INTEGER);
            CREATE TABLE stages (stage_id INTEGER PRIMARY KEY,season_id INTEGER);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY,stage_id INTEGER);
            CREATE TABLE tournament_brackets (season_id INTEGER PRIMARY KEY,payload TEXT);
            INSERT INTO seasons VALUES (100,2,'2026/2027',1),(99,2,'2025/2026',0),(200,24,'2026/2027',1),
                (98,2,'2023/2024',0);
            INSERT INTO stages VALUES (4,100);
        ''')
        for name, method in (('fetch_all_dict', self.fetch_all), ('fetch_one_dict', self.fetch_one)):
            p = patch.object(repo, name, side_effect=method)
            p.start()
            self.addCleanup(p.stop)
        self.app = create_app()
        self.app.dependency_overrides[get_user_id] = lambda: 42
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)

    def fetch_all(self, sql, params=()):
        return [dict(r) for r in self.db.execute(sql.replace('%s', '?'), params)]

    def fetch_one(self, sql, params=()):
        rows = self.fetch_all(sql, params)
        return rows[0] if rows else None

    def save(self, bracket):
        self.db.execute('INSERT OR REPLACE INTO tournament_brackets VALUES (?,?)',
                        (bracket['season_id'], json.dumps(bracket)))

    def test_authenticated_response_has_results_slots_teams_and_live_detail_availability(self):
        bracket = build([fixture(1, 1, 2, score=(1, 1), penalties=(4, 3), state=8)])
        self.save(bracket)
        response = self.client.get('/v1/competitions/2/bracket')
        self.assertEqual(response.status_code, 200, response.text)
        body = response.json()
        self.assertEqual(body['champion_team_id'], 1)
        self.assertEqual(body['teams']['2']['name'], 'Team 2')
        f = body['stages'][0]['ties'][0]['fixtures'][0]
        self.assertEqual((f['home_score'], f['away_score']), (1, 1))
        self.assertEqual((f['home_penalty_score'], f['away_penalty_score']), (4, 3))
        self.assertFalse(f['detail_available'])
        self.db.execute('INSERT INTO fixtures VALUES (1,4)')
        body = self.client.get('/v1/competitions/2/bracket').json()
        self.assertTrue(body['stages'][0]['ties'][0]['fixtures'][0]['detail_available'])

    def test_collected_empty_bracket_is_different_from_uncollected(self):
        self.assertEqual(self.client.get('/v1/competitions/2/bracket').status_code, 503)
        self.save(build([]))
        response = self.client.get('/v1/competitions/2/bracket')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['status'], 'not_published')
        self.assertEqual(response.json()['stages'], [])

    def test_season_must_belong_to_competition_and_errors_are_explicit(self):
        for query, status in (('/2/bracket?season_id=200', 404), ('/24/bracket?season_id=100', 404),
                              ('/8/bracket', 400), ('/2/bracket?season_id=0', 422),
                              ('/2/bracket?season_id=98', 400)):
            self.assertEqual(self.client.get('/v1/competitions' + query).status_code, status)
        bracket = build([])
        bracket.update(season_id=99, season_name='2025/2026')
        self.save(bracket)
        self.assertEqual(self.client.get('/v1/competitions/2/bracket?season_id=99').json()['season_id'], 99)

    def test_token_is_required_and_contract_is_in_openapi(self):
        self.app.dependency_overrides.clear()
        self.assertEqual(self.client.get('/v1/competitions/2/bracket').status_code, 401)
        schema = self.client.get('/openapi.json').json()
        path = schema['paths']['/v1/competitions/{competition_id}/bracket']['get']
        self.assertEqual(path['security'], [{'HTTPBearer': []}])
        self.assertIn('TournamentBracketResponse', schema['components']['schemas'])


if __name__ == '__main__':
    unittest.main()
