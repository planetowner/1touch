"""운영 DB에 연결하지 않고 가입 입력의 중복 조회와 형식 검사를 확인해요."""
import sqlite3
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.api.repos import auth_repo
    from one_touch_loader.api.routes.auth import router


class RegistrationAvailabilityTests(unittest.TestCase):
    def setUp(self):
        self.database = sqlite3.connect(':memory:', check_same_thread=False)
        self.addCleanup(self.database.close)
        self.database.executescript('''
            CREATE TABLE users (user_id INTEGER PRIMARY KEY,
                username TEXT COLLATE NOCASE, display_name TEXT COLLATE NOCASE);
            CREATE TABLE user_email_credentials (user_id INTEGER PRIMARY KEY,
                email TEXT COLLATE NOCASE);
            INSERT INTO users VALUES (1, 'member', 'Supporter'), (2, 'social_only', '메이플123');
            INSERT INTO user_email_credentials VALUES (1, 'member@example.com');
        ''')
        self.lookup = self.enterContext(patch.object(auth_repo, 'fetch_one_dict',
            side_effect=lambda query, params: self.database.execute(query.replace('%s', '?'), params).fetchone()))
        self.limit = self.enterContext(patch.object(auth_repo, 'rate_limit'))
        app = FastAPI()
        app.include_router(router, prefix='/v1')
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def check(self, field, value):
        return self.client.post('/v1/auth/registration/availability', json={'field': field, 'value': value})

    def test_each_field_reports_existing_and_available_values(self):
        for field, existing, unused in (
            ('username', 'MEMBER', 'new_member'),
            ('display_name', 'SUPPORTER', 'NewMember'),
            ('email', 'MEMBER@EXAMPLE.COM', 'new@example.com'),
        ):
            with self.subTest(field=field):
                self.assertEqual(self.check(field, existing).json(), {'available': False})
                self.assertEqual(self.check(field, unused).json(), {'available': True})

    def test_social_accounts_also_reserve_username_and_nickname(self):
        self.assertEqual(self.check('username', 'social_only').json(), {'available': False})
        self.assertEqual(self.check('display_name', '메이플123').json(), {'available': False})

    def test_invalid_fields_and_values_are_rejected_without_lookup(self):
        for field, value in (
            ('password', 'Password123'), ('username; DROP TABLE users', 'member'),
            ('username', ''), ('username', '.member'), ('username', 'a' * 31),
            ('username', ' member'), ('username', 'member\n'),
            ('display_name', 'Member_Name'), ('display_name', 'abc'),
            ('display_name', '가' * 7), ('email', 'invalid'),
        ):
            with self.subTest(field=field, value=value):
                response = self.check(field, value)
                self.assertEqual(response.status_code, 422, response.text)
        self.lookup.assert_not_called()

    def test_email_normalization_matches_registration_and_lookup_does_not_write(self):
        changes = self.database.total_changes
        response = self.check('email', 'member@EXAMPLE.COM')
        self.assertEqual(response.json(), {'available': False})
        self.assertEqual(self.lookup.call_args.args[1], ('member@example.com',))
        self.assertEqual(self.database.total_changes, changes)
        self.limit.assert_called_once_with('registration-availability:testclient', 60, 60)


if __name__ == '__main__':
    unittest.main()
