"""이름 컬럼이 없는 메모리 DB에서 실제 가입·프로필 SQL과 API를 확인해요."""
import sqlite3
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from mysql.connector import IntegrityError
from diagnostics.test_notifications import SqliteConnection

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.core import db
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.repos import auth_repo, users_repo
    from one_touch_loader.api.routes import auth, users


class NicknameOnlyTests(unittest.TestCase):
    def setUp(self):
        self.raw = sqlite3.connect(':memory:', check_same_thread=False)
        self.addCleanup(self.raw.close)
        self.raw.executescript('''
            CREATE TABLE users (user_id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE, display_name TEXT COLLATE NOCASE UNIQUE,
                favorite_team_id INTEGER, suspended_until TEXT, created_at TEXT NOT NULL);
            CREATE TABLE user_email_credentials (user_id INTEGER PRIMARY KEY,
                email TEXT UNIQUE, password_hash TEXT);
            CREATE TABLE user_social_identities (provider TEXT, subject TEXT, user_id INTEGER,
                PRIMARY KEY(provider, subject));
            CREATE TABLE user_avatars (user_id INTEGER PRIMARY KEY);
            CREATE TABLE user_profile_changes (change_id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, change_type TEXT, changed_at TEXT);
        ''')
        conn = SqliteConnection(self.raw)
        self.enterContext(patch.object(db, '_pool', SimpleNamespace(get_connection=lambda: conn)))
        self.enterContext(patch.object(auth_repo, '_create_session',
            side_effect=lambda cur, user_id: {'access_token': f'session-{user_id}'}))
        self.enterContext(patch.object(auth_repo, 'rate_limit'))
        self.user_id = 1
        app = FastAPI()
        app.include_router(auth.router, prefix='/v1')
        app.include_router(users.router, prefix='/v1')
        app.dependency_overrides[get_user_id] = lambda: self.user_id
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def social_signup(self):
        auth_repo.login_social('google', 'social-subject')
        self.user_id = self.raw.execute('SELECT user_id FROM user_social_identities').fetchone()[0]

    def email_signup(self):
        with patch.object(auth_repo, '_consume_code', return_value='member@example.com'):
            response = self.client.post('/v1/auth/email/register', json={
                'challenge_id': 'c' * 43, 'code': '123456', 'password': 'Password123',
                'username': 'member', 'display_name': 'Member'})
        self.assertEqual(response.status_code, 201, response.text)
        self.user_id = self.raw.execute('SELECT user_id FROM user_email_credentials').fetchone()[0]

    def test_social_signup_saves_only_nickname_and_keeps_identity_on_next_login(self):
        self.social_signup()
        self.assertFalse(self.client.get('/v1/users/me').json()['onboarding_complete'])
        response = self.client.put('/v1/users/me/profile', json={'display_name': 'Supporter'})
        self.assertEqual(response.status_code, 200, response.text)
        account = response.json()
        self.assertIsNone(account['username'])
        self.assertIsNone(account['email'])
        self.assertEqual(account['display_name'], 'Supporter')
        self.assertNotIn('first_name', account)
        self.assertNotIn('last_name', account)
        self.assertFalse(account['onboarding_complete'])
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM user_email_credentials').fetchone()[0], 0)
        self.raw.execute('UPDATE users SET favorite_team_id=6')
        self.raw.commit()
        self.assertTrue(self.client.get('/v1/users/me').json()['onboarding_complete'])
        users_repo.require_profile(users_repo.get_user(self.user_id))
        self.assertEqual(auth_repo.login_social('google', 'social-subject')['access_token'], f'session-{self.user_id}')
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM users').fetchone()[0], 1)
        self.assertIsNone(self.client.get('/v1/users/me').json()['username'])

    def test_email_signup_and_id_edit_work_without_personal_names(self):
        self.email_signup()
        response = self.client.put('/v1/users/me/profile', json={'username': 'new_id', 'display_name': 'Member'})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['username'], 'new_id')
        self.assertEqual(auth_repo.login_password('new_id', 'Password123')['access_token'], f'session-{self.user_id}')
        self.assertEqual(auth_repo.login_password('member@example.com', 'Password123')['access_token'], f'session-{self.user_id}')
        response = self.client.put('/v1/users/me/profile', json={'display_name': 'Member'})
        self.assertEqual(response.json()['username'], 'new_id')

    def test_social_profile_cannot_acquire_an_email_login_id(self):
        self.social_signup()
        response = self.client.put('/v1/users/me/profile', json={'username': 'chosen_id', 'display_name': 'Member'})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertIsNone(response.json()['username'])

    def test_missing_nickname_blocks_completion_and_community_writes(self):
        self.social_signup()
        for body in ({}, {'display_name': ''}, {'display_name': 'Bad_Name'}):
            self.assertEqual(self.client.put('/v1/users/me/profile', json=body).status_code, 422)
        with self.assertRaises(HTTPException) as error:
            users_repo.require_profile(users_repo.get_user(self.user_id))
        self.assertEqual(error.exception.status_code, 403)

    def test_both_signup_and_profile_use_existing_nickname_conflict_response(self):
        self.social_signup()
        with patch.object(users_repo, 'lock_user', side_effect=IntegrityError(errno=1062)):
            response = self.client.put('/v1/users/me/profile', json={'display_name': 'Member'})
        self.assertEqual(response.status_code, 409)
        with patch.object(auth_repo, '_consume_code', side_effect=IntegrityError(errno=1062)):
            response = self.client.post('/v1/auth/email/register', json={
                'challenge_id': 'c' * 43, 'code': '123456', 'password': 'Password123',
                'username': 'member', 'display_name': 'Member'})
        self.assertEqual(response.status_code, 409)

    def test_email_signup_still_requires_a_login_id(self):
        response = self.client.post('/v1/auth/email/register', json={
            'challenge_id': 'c' * 43, 'code': '123456', 'password': 'Password123', 'display_name': 'Member'})
        self.assertEqual(response.status_code, 422)

    def test_social_nickname_uses_the_existing_change_limit(self):
        self.social_signup()
        for nickname in ('FirstName', 'SecondName', 'ThirdName'):
            response = self.client.put('/v1/users/me/profile', json={'display_name': nickname})
            self.assertEqual(response.status_code, 200, response.text)
        response = self.client.put('/v1/users/me/profile', json={'display_name': 'FourthName'})
        self.assertEqual(response.status_code, 409, response.text)
        self.assertEqual(response.json()['detail']['max_changes'], 2)
        self.assertIsNone(self.client.get('/v1/users/me').json()['username'])


if __name__ == '__main__':
    unittest.main()
