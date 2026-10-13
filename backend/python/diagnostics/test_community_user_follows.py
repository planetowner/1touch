"""팔로우 API와 기존 DDL을 메모리 DB에서 실행해 운영 데이터를 바꾸지 않고 검증해요."""
from datetime import datetime, timedelta
import sqlite3
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from diagnostics.test_notifications import SqliteConnection

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.core import db
    from one_touch_loader.api import deps
    from one_touch_loader.api.repos import community_profiles_repo as profiles
    from one_touch_loader.api.routes import users
    from diagnostics import migrate_community_user_follows as migration


# SQLite는 MySQL의 ADD KEY를 지원하지 않아 실제 마이그레이션에서 컬럼 추가문만 실행해요.
ORDER_COLUMN_SQL = migration.ORDER_SQL_PATH.read_text(encoding='utf-8').split(',\n', 1)[0] + ';'


class CommunityUserFollowTests(unittest.TestCase):
    def setUp(self):
        self.raw = sqlite3.connect(':memory:', check_same_thread=False)
        self.addCleanup(self.raw.close)
        self.raw.execute('PRAGMA foreign_keys=ON')
        self.raw.executescript('''
            CREATE TABLE users (user_id INTEGER PRIMARY KEY, username TEXT, display_name TEXT,
                suspended_until TEXT, email TEXT DEFAULT 'private@example.com');
            CREATE TABLE user_avatars (user_id INTEGER PRIMARY KEY);
            CREATE TABLE user_blocks (user_id INTEGER, blocked_user_id INTEGER);
            INSERT INTO users (user_id,username,display_name) VALUES
                (1,'viewer','Viewer'), (2,'friend','Friend'), (3,'blocked','Blocked'),
                (4,NULL,'Social'), (5,'other','Other');
            INSERT INTO user_avatars VALUES (2);
            INSERT INTO user_blocks VALUES (1,3), (4,1);
        ''')
        # 엔진 설정만 제외하고 배포에 쓰는 실제 제약조건을 실행해요.
        self.raw.execute(migration.SQL_PATH.read_text(encoding='utf-8').split(' ENGINE=')[0])
        self.raw.execute(ORDER_COLUMN_SQL)
        self.raw.executescript('''
            INSERT INTO user_following_users (user_id,followed_user_id) VALUES (2,1),(3,1),(4,1),(1,2),(1,3),
                (1,4),(2,4),(3,4),(4,2);
        ''')
        conn = SqliteConnection(self.raw)
        self.enterContext(patch.object(db, '_pool', SimpleNamespace(get_connection=lambda: conn)))
        self.enterContext(patch.object(deps, 'session_user', side_effect=self.session_user))
        app = FastAPI()
        app.include_router(users.router, prefix='/v1')
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def session_user(self, token):
        if token != 'viewer-session':
            raise HTTPException(401, 'Invalid session')
        return {'user_id': 1}

    def request(self, method, path, **kwargs):
        return self.client.request(method, '/v1/users/' + path,
                                   headers={'Authorization': 'Bearer viewer-session'}, **kwargs)

    def get(self, path, **params):
        response = self.request('GET', path, params=params)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_counts_and_lists_share_visibility_and_both_profile_routes(self):
        for author in ('me', '1', '2', '4', '5'):
            counts = self.get(f'{author}/follow/counts')
            for direction, field in (('followers', 'follower_count'), ('following', 'following_count')):
                items = self.get(f'{author}/{direction}')['items']
                self.assertEqual(counts[field], len(items))
                self.assertNotIn(3, [row['user_id'] for row in items])
        self.assertEqual(self.get('me/follow/counts'), {'follower_count': 2, 'following_count': 2})
        self.assertEqual(self.get('5/follow/counts'), {'follower_count': 0, 'following_count': 0})
        for suffix in ('follow/counts', 'followers', 'following'):
            self.assertEqual(self.get('me/' + suffix), self.get('1/' + suffix))

    def test_list_profiles_reuse_public_fields_and_viewer_follow_state(self):
        items = self.get('4/followers')['items']
        self.assertEqual([row['user_id'] for row in items], [2, 1])
        for row in items:
            self.assertEqual(row, self.get(f"{row['user_id']}/community"))
            self.assertEqual(set(row), {'user_id', 'username', 'display_name', 'avatar_url',
                                        'author_deleted', 'following', 'is_self'})
        self.assertTrue(items[1]['is_self'])
        self.assertFalse(items[1]['following'])
        self.assertTrue(items[0]['following'])
        self.assertEqual(items[0]['avatar_url'], '/v1/users/2/avatar')
        self.raw.execute('DELETE FROM user_following_users WHERE user_id=1 AND followed_user_id=2')
        self.raw.commit()
        self.assertFalse(self.get('4/followers')['items'][0]['following'])
        social = self.get('me/following')['items'][0]
        self.assertEqual(social['user_id'], 4)
        self.assertIsNone(social['username'])
        self.assertIsNone(social['avatar_url'])

    def test_blocking_is_viewer_specific_and_does_not_remove_saved_relations(self):
        # 상대가 나를 차단해도 내 조회에는 영향을 주지 않는 기존 규칙을 유지해요.
        self.assertEqual([row['user_id'] for row in self.get('me/following')['items']], [4, 2])
        self.raw.execute('DELETE FROM user_blocks WHERE user_id=1 AND blocked_user_id=3')
        self.raw.commit()
        self.assertEqual(self.get('me/follow/counts'), {'follower_count': 3, 'following_count': 3})
        self.assertEqual([row['user_id'] for row in self.get('me/following')['items']], [4, 3, 2])

    def test_filtering_precedes_pagination_and_pages_have_stable_order(self):
        for direction in ('followers', 'following'):
            for offset, expected in enumerate((4, 2)):
                page = self.get('me/' + direction, limit=1, offset=offset)
                self.assertEqual([row['user_id'] for row in page['items']], [expected])
                self.assertEqual((page['limit'], page['offset']), (1, offset))
            self.assertEqual(self.get('me/' + direction, limit=1, offset=2)['items'], [])

    def test_counts_cover_all_pages_and_my_routes_ignore_supplied_owner(self):
        self.raw.executemany('INSERT INTO users(user_id,display_name) VALUES (?,?)',
                             [(i, f'Member{i}') for i in range(100, 220)])
        self.raw.executemany('INSERT INTO user_following_users (user_id,followed_user_id) VALUES (?,?)',
                             [(1, i) for i in range(100, 220)] + [(i, 1) for i in range(100, 220)])
        self.raw.commit()
        self.assertEqual(self.get('me/follow/counts', user_id=5, author_id=5, limit=1, offset=1000),
                         {'follower_count': 122, 'following_count': 122})
        for direction in ('followers', 'following'):
            first = self.get('me/' + direction, user_id=5, author_id=5)
            self.assertEqual((len(first['items']), first['limit'], first['offset']), (50, 50, 0))
            pages = [self.get('me/' + direction, offset=i)['items'] for i in (0, 50, 100)]
            ids = [row['user_id'] for page in pages for row in page]
            self.assertEqual(len(ids), 122)
            self.assertEqual(ids, sorted(set(ids), reverse=True))

    def test_sort_uses_relationship_time_in_all_four_lists_before_pagination(self):
        self.raw.executescript('INSERT INTO user_following_users (user_id,followed_user_id) VALUES (1,5),(5,1)')
        for owner, member, when in (
            (1, 2, '2026-01-01 12:00:00'), (1, 4, '2026-01-03 12:00:00'),
            (1, 5, '2026-01-02 12:00:00'), (2, 1, '2026-01-03 12:00:00'),
            (4, 1, '2026-01-01 12:00:00'), (5, 1, '2026-01-02 12:00:00'),
            (1, 3, '2026-01-04 12:00:00'), (3, 1, '2026-01-04 12:00:00'),
        ):
            self.raw.execute('UPDATE user_following_users SET created_at=? WHERE user_id=? AND followed_user_id=?',
                             (when, owner, member))
        self.raw.commit()
        for owner in ('me', '1'):
            for direction, newest in (('followers', [2, 5, 4]), ('following', [4, 5, 2])):
                for sort, expected in (('newest', newest), ('oldest', newest[::-1])):
                    with self.subTest(owner=owner, direction=direction, sort=sort):
                        path = f'{owner}/{direction}'
                        items = self.get(path, sort=sort)['items']
                        self.assertEqual([row['user_id'] for row in items], expected)
                        pages = [self.get(path, sort=sort, limit=1, offset=i)['items'][0]['user_id']
                                 for i in range(3)]
                        self.assertEqual(pages, expected)
                        self.assertEqual(self.get(path, sort=sort, limit=1, offset=3)['items'], [])
                self.assertEqual(self.get(path), self.get(path, sort='newest'))

    def test_same_microsecond_uses_member_id_and_unknown_times_are_older(self):
        for direction, owner_column in (('followers', 'followed_user_id'), ('following', 'user_id')):
            self.raw.execute(f'UPDATE user_following_users SET created_at=? WHERE {owner_column}=1',
                             ('2026-01-01 00:00:00.123456',))
        self.raw.commit()
        for direction in ('followers', 'following'):
            for sort, expected in (('newest', [4, 2]), ('oldest', [2, 4])):
                self.assertEqual([row['user_id'] for row in self.get('me/' + direction, sort=sort)['items']], expected)
        self.raw.execute('UPDATE user_following_users SET created_at=NULL WHERE user_id=4 OR followed_user_id=4')
        self.raw.commit()
        for direction in ('followers', 'following'):
            for sort, expected in (('newest', [2, 4]), ('oldest', [4, 2])):
                self.assertEqual([row['user_id'] for row in self.get('me/' + direction, sort=sort)['items']], expected)

    def test_first_follow_time_survives_retries_and_refollow_gets_a_new_time(self):
        first = datetime(2026, 1, 1, 0, 0, 0, 123456)
        later = first + timedelta(microseconds=1)
        last = first + timedelta(microseconds=2)
        with patch.object(profiles, 'utc_now', return_value=first):
            self.assertEqual(self.request('PUT', '5/follow').status_code, 200)
        with patch.object(profiles, 'utc_now', return_value=later):
            self.assertEqual(self.request('PUT', '5/follow').status_code, 200)
        def saved_time():
            return datetime.fromisoformat(self.raw.execute('SELECT created_at FROM user_following_users '
                                                          'WHERE user_id=1 AND followed_user_id=5').fetchone()[0])
        self.assertEqual(saved_time(), first)
        self.raw.execute('UPDATE user_following_users SET created_at=? WHERE user_id=1 AND followed_user_id=2', (later,))
        self.raw.commit()
        self.assertEqual([row['user_id'] for row in self.get('me/following')['items']], [2, 5, 4])
        self.assertEqual(self.request('DELETE', '5/follow').status_code, 200)
        with patch.object(profiles, 'utc_now', return_value=last):
            self.assertEqual(self.request('PUT', '5/follow').status_code, 200)
        self.assertEqual(saved_time(), last)
        self.assertEqual([row['user_id'] for row in self.get('me/following')['items']], [5, 2, 4])

    def test_repeating_a_legacy_follow_does_not_invent_its_time(self):
        self.assertEqual(self.request('PUT', '2/follow').status_code, 200)
        self.assertIsNone(self.raw.execute('SELECT created_at FROM user_following_users '
                                          'WHERE user_id=1 AND followed_user_id=2').fetchone()[0])

    def test_invalid_sort_is_rejected_in_all_four_lists(self):
        for owner in ('me', '2'):
            for direction in ('followers', 'following'):
                for sort in ('', 'asc', 'desc', 'newest DESC', 'oldest; DROP TABLE users'):
                    response = self.request('GET', f'{owner}/{direction}', params={'sort': sort})
                    self.assertEqual(response.status_code, 422)

    def test_follow_and_unfollow_are_idempotent_and_use_session_owner(self):
        for _ in range(2):
            response = self.request('PUT', '5/follow', params={'user_id': 2}, json={'user_id': 2})
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual(response.json(), {'ok': True})
        self.assertTrue(self.get('5/community')['following'])
        self.assertEqual(self.get('5/follow/counts')['follower_count'], 1)
        self.assertEqual(self.get('me/follow/counts')['following_count'], 3)
        self.assertEqual([row['user_id'] for row in self.get('5/followers')['items']], [1])
        for _ in range(2):
            response = self.request('DELETE', '5/follow')
            self.assertEqual(response.status_code, 200, response.text)
        self.assertFalse(self.get('5/community')['following'])
        self.assertEqual(self.get('5/follow/counts')['follower_count'], 0)
        self.assertEqual(self.get('me/follow/counts')['following_count'], 2)

    def test_reads_hide_blocked_and_missing_owners(self):
        for author in (3, 999):
            for suffix in ('follow/counts', 'followers', 'following'):
                self.assertEqual(self.request('GET', f'{author}/{suffix}').status_code, 404)

    def test_writes_reject_self_blocked_and_missing_targets(self):
        for method in ('PUT', 'DELETE'):
            for author, status in ((1, 400), (3, 404), (999, 404)):
                with self.subTest(method=method, author=author):
                    self.assertEqual(self.request(method, f'{author}/follow').status_code, status)

    def test_all_endpoints_require_bearer_authentication(self):
        cases = [('GET', f'{author}/{suffix}') for author in ('me', '2')
                 for suffix in ('follow/counts', 'followers', 'following')]
        cases += [('PUT', '2/follow'), ('DELETE', '2/follow')]
        for method, path in cases:
            for headers in ({}, {'X-User-Id': '1'}, {'Authorization': 'Bearer invalid'}):
                self.assertEqual(self.client.request(method, '/v1/users/' + path, headers=headers).status_code, 401)

    def test_read_permissions_preserve_profile_and_suspension_rules(self):
        for changes in ({'display_name': None}, {'suspended_until': datetime.now() + timedelta(days=1)}):
            user = {'display_name': 'Viewer', 'suspended_until': None, **changes}
            with patch.object(profiles, 'get_user', return_value=user):
                for author in ('me', '2'):
                    for suffix in ('follow/counts', 'followers', 'following'):
                        self.assertEqual(self.request('GET', f'{author}/{suffix}').status_code, 403)

    def test_pagination_and_target_ids_are_validated(self):
        for author in ('me', '2'):
            for direction in ('followers', 'following'):
                for params in ({'limit': 0}, {'limit': 101}, {'limit': 'bad'}, {'offset': -1}):
                    self.assertEqual(self.request('GET', f'{author}/{direction}', params=params).status_code, 422)
        for author in ('0', '-1', 'bad'):
            for suffix in ('follow/counts', 'followers', 'following'):
                self.assertEqual(self.request('GET', f'{author}/{suffix}').status_code, 422)
            for method in ('PUT', 'DELETE'):
                self.assertEqual(self.request(method, f'{author}/follow').status_code, 422)

    def test_missing_session_owner_still_returns_unauthorized(self):
        self.raw.execute('DELETE FROM users WHERE user_id=1')
        self.raw.commit()
        for method in ('PUT', 'DELETE'):
            self.assertEqual(self.request(method, '2/follow').status_code, 401)

    def test_existing_ddl_rejects_duplicate_self_and_orphan_relations(self):
        for pair in ((1, 2), (1, 1), (1, 999), (999, 1)):
            with self.subTest(pair=pair), self.assertRaises(sqlite3.IntegrityError):
                self.raw.execute('INSERT INTO user_following_users (user_id,followed_user_id) VALUES (?,?)', pair)
            self.raw.rollback()

    def test_deleting_user_cascades_both_directions_and_updates_counts(self):
        self.raw.execute('DELETE FROM users WHERE user_id=2')
        self.raw.commit()
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM user_following_users '
                                         'WHERE user_id=2 OR followed_user_id=2').fetchone()[0], 0)
        self.assertEqual(self.get('me/follow/counts'), {'follower_count': 1, 'following_count': 1})
        self.assertEqual(self.get('4/follow/counts'), {'follower_count': 1, 'following_count': 1})

    def test_query_failures_are_not_reported_as_zero_or_empty_results(self):
        with patch.object(profiles, 'get_profile'), \
             patch.object(profiles, 'fetch_one_dict', side_effect=RuntimeError('database unavailable')), \
             patch.object(profiles, 'fetch_all_dict', side_effect=RuntimeError('database unavailable')):
            for suffix in ('follow/counts', 'followers', 'following'):
                with self.assertRaisesRegex(RuntimeError, 'database unavailable'):
                    self.get('me/' + suffix)


class FollowMigrationTests(unittest.TestCase):
    def test_inspection_never_writes_and_apply_only_runs_pending_steps(self):
        for table_exists, order_exists in ((False, False), (True, False), (True, True)):
            for apply in (False, True):
                states = [{'present': 1} if exists else None for exists in (table_exists, order_exists)]
                with self.subTest(table=table_exists, order=order_exists, apply=apply), \
                     patch.object(migration, 'fetch_one_dict', side_effect=states), \
                     patch.object(migration, 'transaction') as transaction:
                    self.assertEqual(migration.migrate(apply=apply), order_exists or apply)
                    pending = [path.read_text(encoding='utf-8')
                               for exists, path in ((table_exists, migration.SQL_PATH), (order_exists, migration.ORDER_SQL_PATH))
                               if not exists]
                    if apply and pending:
                        cur = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
                        self.assertEqual([call.args[0] for call in cur.execute.call_args_list], pending)
                    else:
                        transaction.assert_not_called()

    def test_failed_ddl_is_not_reported_as_ready(self):
        with patch.object(migration, 'fetch_one_dict', side_effect=[{'present': 1}, None]), \
             patch.object(migration, 'transaction') as transaction:
            cur = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
            cur.execute.side_effect = RuntimeError('ALTER failed')
            with self.assertRaisesRegex(RuntimeError, 'ALTER failed'):
                migration.migrate(apply=True)

    def test_adding_timestamp_preserves_legacy_relations_without_backfilling(self):
        raw = sqlite3.connect(':memory:')
        self.addCleanup(raw.close)
        raw.execute('CREATE TABLE user_following_users (user_id INTEGER, followed_user_id INTEGER)')
        raw.executemany('INSERT INTO user_following_users VALUES (?,?)', [(1, 2), (2, 1)])
        raw.execute(ORDER_COLUMN_SQL)
        self.assertEqual(raw.execute('SELECT * FROM user_following_users ORDER BY user_id').fetchall(),
                         [(1, 2, None), (2, 1, None)])


if __name__ == '__main__':
    unittest.main()
