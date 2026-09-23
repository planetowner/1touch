"""운영 DB에 연결하지 않고 실제 로그인 SELECT와 비밀번호 검증을 실행해요."""
from contextlib import contextmanager
import sqlite3
import unittest
from unittest.mock import patch

from fastapi import HTTPException
from fastapi.testclient import TestClient

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.api.repos import auth_repo
    from one_touch_loader.api.main import create_app
    from one_touch_loader.api.schemas.users import PasswordLoginBody


class PasswordLoginTests(unittest.TestCase):
    def setUp(self):
        self.database = sqlite3.connect(':memory:', check_same_thread=False)
        self.database.row_factory = sqlite3.Row
        self.addCleanup(self.database.close)
        self.database.executescript('''
            CREATE TABLE users (user_id INTEGER PRIMARY KEY, username TEXT COLLATE NOCASE);
            CREATE TABLE user_email_credentials (user_id INTEGER PRIMARY KEY, email TEXT COLLATE NOCASE, password_hash TEXT);
            INSERT INTO users VALUES (1, 'member'), (2, 'social-only');
        ''')
        self.database.execute('INSERT INTO user_email_credentials VALUES (?,?,?)',
                              (1, 'member@example.com', auth_repo.PASSWORDS.hash('Password123')))
        self.rate_limit = self.enterContext(patch.object(auth_repo, 'rate_limit'))
        self.session = self.enterContext(patch.object(auth_repo, '_create_session',
            side_effect=lambda cur, user_id: {'access_token': f'session-{user_id}'}))
        self.enterContext(patch.object(auth_repo, 'transaction', self.transaction))

    @contextmanager
    def transaction(self):
        yield self

    @contextmanager
    def cursor(self, dictionary=False):
        yield self

    def execute(self, query, params):
        # 잠금 문법만 제외하고 저장소의 실제 WHERE 조건을 검사해요.
        self.result = self.database.execute(query.replace('%s', '?').replace(' FOR UPDATE', ''), params)

    def fetchall(self):
        return self.result.fetchall()

    def test_email_and_username_return_the_same_account(self):
        for identifier in ('member', ' member@example.com ', 'MEMBER@EXAMPLE.COM'):
            with self.subTest(identifier=identifier):
                self.assertEqual(auth_repo.login_password(identifier, 'Password123'), {'access_token': 'session-1'})

    def test_wrong_password_missing_account_and_social_only_account_do_not_create_session(self):
        for identifier, password in [('member', 'WrongPassword123'), ('missing', 'Password123'), ('social-only', 'Password123')]:
            with self.subTest(identifier=identifier), self.assertRaises(HTTPException) as error:
                auth_repo.login_password(identifier, password)
            self.assertEqual(error.exception.status_code, 401)
        self.session.assert_not_called()

    def test_email_shaped_username_does_not_hide_another_members_email(self):
        self.database.execute('INSERT INTO users VALUES (?,?)', (3, 'member@example.com'))
        self.database.execute('INSERT INTO user_email_credentials VALUES (?,?,?)',
                              (3, 'third@example.com', auth_repo.PASSWORDS.hash('OtherPassword123')))
        self.assertEqual(auth_repo.login_password('member@example.com', 'Password123')['access_token'], 'session-1')
        self.assertEqual(auth_repo.login_password('member@example.com', 'OtherPassword123')['access_token'], 'session-3')
        self.database.execute('UPDATE user_email_credentials SET password_hash=? WHERE user_id=3',
                              (auth_repo.PASSWORDS.hash('Password123'),))
        with self.assertRaises(HTTPException):
            auth_repo.login_password('member@example.com', 'Password123')

    def test_http_contract_accepts_email_in_the_existing_username_field(self):
        response = TestClient(create_app()).post('/v1/auth/login', json={
            'username': 'member@example.com', 'password': 'Password123'})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['access_token'], 'session-1')
        long_email = 'a' * 60 + '@example.com'
        self.assertEqual(PasswordLoginBody(username=long_email, password='Password123').username, long_email)


if __name__ == '__main__':
    unittest.main()
