"""소셜 인증은 모의 처리하고 연결·재로그인·해제는 메모리 DB로 확인해요."""
import sqlite3
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from mysql.connector import IntegrityError
from diagnostics.test_notifications import SqliteConnection, SqliteCursor

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.core import db
    from one_touch_loader.api.repos import auth_repo, users_repo
    from one_touch_loader.api.routes import auth, users
    from one_touch_loader.api.services import social_login
    from one_touch_loader.api.services.auth_security import PASSWORDS


class IdentityCursor(SqliteCursor):
    def execute(self, sql, params=()):
        try:
            return super().execute(sql.replace('INSERT IGNORE', 'INSERT OR IGNORE'), params)
        except sqlite3.IntegrityError as exc:
            # 공급자 ID와 회원별 공급자의 고유 키 위반을 MySQL과 같은 오류로 전달해요.
            if exc.sqlite_errorcode in (sqlite3.SQLITE_CONSTRAINT_PRIMARYKEY, sqlite3.SQLITE_CONSTRAINT_UNIQUE):
                raise IntegrityError(errno=1062) from exc
            raise


class IdentityConnection(SqliteConnection):
    def cursor(self, dictionary=False):
        return IdentityCursor(self.raw, dictionary)


class SocialAccountLinkingTests(unittest.TestCase):
    def setUp(self):
        self.raw = sqlite3.connect(':memory:', check_same_thread=False)
        self.addCleanup(self.raw.close)
        self.raw.executescript('''
            PRAGMA foreign_keys=ON;
            CREATE TABLE users (user_id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE, display_name TEXT UNIQUE, favorite_team_id INTEGER,
                suspended_until TEXT, created_at TEXT NOT NULL);
            CREATE TABLE user_email_credentials (user_id INTEGER PRIMARY KEY REFERENCES users,
                email TEXT UNIQUE, password_hash TEXT);
            CREATE TABLE user_social_identities (provider TEXT, subject TEXT,
                user_id INTEGER REFERENCES users, PRIMARY KEY(provider,subject), UNIQUE(user_id,provider));
            CREATE TABLE user_sessions (token_hash BLOB PRIMARY KEY,
                user_id INTEGER REFERENCES users, expires_at TEXT);
            CREATE TABLE user_avatars (user_id INTEGER PRIMARY KEY);
            CREATE TABLE social_webhook_receipts (provider TEXT, event_hash BLOB, PRIMARY KEY(provider,event_hash));
            INSERT INTO users VALUES (1,'member','Member',6,NULL,'2026-10-02T00:00:00');
        ''')
        self.raw.execute('INSERT INTO user_email_credentials VALUES (1,?,?)',
                         ('member@example.com', PASSWORDS.hash('Password123')))
        self.raw.commit()
        connection = IdentityConnection(self.raw)
        self.enterContext(patch.object(db, '_pool', SimpleNamespace(get_connection=lambda: connection)))
        self.enterContext(patch.object(auth_repo, 'rate_limit'))
        self.google = self.enterContext(patch.object(social_login, 'google_subject', return_value='google-member'))
        self.apple = self.enterContext(patch.object(social_login, 'apple_subject', return_value='apple-member'))
        app = FastAPI()
        app.include_router(auth.router, prefix='/v1')
        app.include_router(users.router, prefix='/v1')
        self.client = TestClient(app)
        self.addCleanup(self.client.close)
        self.session = auth_repo.login_password('member', 'Password123')['access_token']
        self.headers = {'Authorization': f'Bearer {self.session}'}

    def connect(self, provider, *, headers=None):
        proof = {'id_token': 'google-proof'} if provider == 'google' else {
            'code': 'apple-proof', 'client_id': 'com.onetouch.football', 'nonce': 'a' * 32}
        return self.client.put(f'/v1/users/me/social-accounts/{provider}', json=proof,
                               headers=self.headers if headers is None else headers)

    def test_email_google_and_apple_logins_reach_the_same_existing_user(self):
        for provider in ('google', 'apple'):
            response = self.connect(provider)
            self.assertEqual(response.status_code, 200, response.text)
            self.assertIn(provider, response.json()['social_accounts'])
            token = auth_repo.login_social(provider, f'{provider}-member')['access_token']
            self.assertEqual(auth_repo.session_user(token)['user_id'], 1)
        self.google.assert_called_once_with('google-proof')
        self.apple.assert_called_once_with('apple-proof', 'com.onetouch.football', 'a' * 32)
        self.assertEqual(auth_repo.session_user(self.session)['user_id'], 1)
        password_token = auth_repo.login_password('member@example.com', 'Password123')['access_token']
        self.assertEqual(auth_repo.session_user(password_token)['user_id'], 1)
        account = self.client.get('/v1/users/me', headers=self.headers).json()
        self.assertEqual(set(account['social_accounts']), {'google', 'apple'})
        self.assertEqual((account['username'], account['display_name'], account['email']),
                         ('member', 'Member', 'member@example.com'))
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM users').fetchone()[0], 1)

    def test_connection_is_idempotent_and_does_not_issue_a_session(self):
        for _ in range(2):
            self.assertEqual(self.connect('google').status_code, 200)
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM user_social_identities').fetchone()[0], 1)
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM user_sessions').fetchone()[0], 1)

    def test_identity_owned_by_another_user_is_not_moved_or_merged(self):
        other = auth_repo.login_social('google', 'google-member')['access_token']
        other_id = auth_repo.session_user(other)['user_id']
        response = self.connect('google')
        self.assertEqual(response.status_code, 409, response.text)
        self.assertEqual(auth_repo.session_user(other)['user_id'], other_id)
        self.assertEqual(self.raw.execute('SELECT user_id FROM user_social_identities').fetchone()[0], other_id)
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM users').fetchone()[0], 2)

    def test_another_identity_of_the_same_provider_does_not_replace_the_first(self):
        self.assertEqual(self.connect('google').status_code, 200)
        self.google.return_value = 'different-google-member'
        response = self.connect('google')
        self.assertEqual(response.status_code, 409, response.text)
        self.assertEqual(self.raw.execute('SELECT subject FROM user_social_identities').fetchone()[0], 'google-member')

    def test_linking_requires_a_valid_current_session_and_provider_proof(self):
        for provider in ('google', 'apple'):
            with self.subTest(provider=provider):
                self.assertEqual(self.connect(provider, headers={}).status_code, 401)
                self.assertEqual(self.connect(provider, headers={'Authorization': 'Bearer expired'}).status_code, 401)
                verifier = self.google if provider == 'google' else self.apple
                verifier.assert_not_called()
                verifier.side_effect = HTTPException(401, 'Invalid provider token')
                self.assertEqual(self.connect(provider).status_code, 401)
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM user_social_identities').fetchone()[0], 0)

    def test_profile_includes_linked_providers_after_reopening(self):
        account = self.client.get('/v1/users/me', headers=self.headers).json()
        self.assertEqual(account['social_accounts'], [])
        self.assertEqual(self.connect('apple').status_code, 200)
        account = self.client.get('/v1/users/me', headers=self.headers).json()
        self.assertEqual(account['social_accounts'], ['apple'])

    def test_revocation_preserves_the_email_account_and_requires_a_new_login(self):
        self.assertEqual(self.connect('apple').status_code, 200)
        with patch.object(users_repo, '_delete_account_rows') as delete:
            users_repo.delete_social_account('apple', 'apple-member', 'revoked-1')
            users_repo.delete_social_account('apple', 'apple-member', 'revoked-1')
        delete.assert_not_called()
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM users').fetchone()[0], 1)
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM user_social_identities').fetchone()[0], 0)
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM social_webhook_receipts').fetchone()[0], 1)
        self.assertEqual(self.client.get('/v1/users/me', headers=self.headers).status_code, 401)
        token = auth_repo.login_password('member', 'Password123')['access_token']
        self.assertEqual(auth_repo.session_user(token)['user_id'], 1)

    def test_revocation_preserves_another_social_login_method(self):
        self.assertEqual(self.connect('google').status_code, 200)
        self.assertEqual(self.connect('apple').status_code, 200)
        self.raw.execute('DELETE FROM user_email_credentials')
        self.raw.commit()
        with patch.object(users_repo, '_delete_account_rows') as delete:
            users_repo.delete_social_account('apple', 'apple-member', 'revoked-2')
        delete.assert_not_called()
        self.assertEqual(self.raw.execute('SELECT provider FROM user_social_identities').fetchall(), [('google',)])
        token = auth_repo.login_social('google', 'google-member')['access_token']
        self.assertEqual(auth_repo.session_user(token)['user_id'], 1)

    def test_revocation_of_the_last_method_keeps_the_existing_deletion_rule(self):
        self.assertEqual(self.connect('apple').status_code, 200)
        self.raw.execute('DELETE FROM user_email_credentials')
        self.raw.commit()
        with patch.object(users_repo, '_delete_account_rows') as delete:
            users_repo.delete_social_account('apple', 'apple-member', 'revoked-3')
        delete.assert_called_once()
        self.assertEqual(delete.call_args.args[1], 1)

    def test_failed_revocation_rolls_back_the_identity_and_receipt(self):
        self.assertEqual(self.connect('apple').status_code, 200)
        self.raw.execute('DELETE FROM user_email_credentials')
        self.raw.commit()
        with patch.object(users_repo, '_delete_account_rows', side_effect=RuntimeError('storage failed')):
            with self.assertRaisesRegex(RuntimeError, 'storage failed'):
                users_repo.delete_social_account('apple', 'apple-member', 'revoked-4')
        self.assertEqual(self.raw.execute('SELECT subject FROM user_social_identities').fetchall(), [('apple-member',)])
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM social_webhook_receipts').fetchone()[0], 0)
        self.assertEqual(auth_repo.session_user(self.session)['user_id'], 1)


if __name__ == '__main__':
    unittest.main()
