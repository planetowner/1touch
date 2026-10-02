"""격리 MySQL에서 행 잠금 경쟁과 실제 ALTER의 기존 데이터 보존을 확인해요."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path
from threading import Barrier
from unittest.mock import patch

from diagnostics.test_user_community import CommunityDatabaseCase
from one_touch_loader.api.repos import posts_repo, points_repo


class CommunityPointConcurrencyTests(CommunityDatabaseCase):
    def setUp(self):
        super().setUp()
        clock = patch.object(posts_repo, 'utc_now', return_value=datetime(2026, 10, 2, 12))
        clock.start()
        self.addCleanup(clock.stop)

    def parallel(self, actions):
        barrier = Barrier(len(actions))
        def run(action):
            barrier.wait(timeout=10)
            return action()
        with ThreadPoolExecutor(max_workers=len(actions)) as executor:
            return list(executor.map(run, actions))

    def test_concurrent_publications_share_three_post_limit(self):
        self.parallel([self.post] * 6)
        self.assertEqual(points_repo.get_wallet(self.a)['balance'], 1300)
        self.assertEqual(self.execute("SELECT COUNT(*) AS n FROM user_point_entries WHERE kind='community_post' AND amount=100")[0]['n'], 3)

    def test_crossed_reactions_lock_users_in_same_order(self):
        other, _ = self.user('other', 6)
        first, second = self.post(), self.post(user_id=other)
        self.parallel([lambda: posts_repo.set_like(other, 'post', first, True),
                       lambda: posts_repo.set_like(self.a, 'post', second, True)])
        for user in (self.a, other):
            self.assertEqual(points_repo.get_wallet(user)['balance'], 1110)

    def test_concurrent_duplicate_comments_credit_once(self):
        other, _ = self.user('other', 6)
        post = self.post()
        self.parallel([lambda: posts_repo.create_comment(other, post, 'ㅋ', None)] * 2)
        self.assertEqual(points_repo.get_wallet(self.a)['balance'], 1110)
        self.assertEqual(self.execute('SELECT COUNT(*) AS n FROM post_comments')[0]['n'], 2)

    def test_concurrent_likes_share_post_limit(self):
        post = self.post()
        actors = [self.user(f'actor{i}', 6)[0] for i in range(21)]
        for actor in actors[:19]:
            posts_repo.set_like(actor, 'post', post, True)
        self.parallel([lambda actor=actor: posts_repo.set_like(actor, 'post', post, True) for actor in actors[19:]])
        self.assertEqual(points_repo.get_wallet(self.a)['balance'], 1300)

    def test_different_posts_share_daily_limit_under_concurrency(self):
        first, second = self.post(), self.post()
        now = datetime(2026, 10, 2, 12)
        self.execute('UPDATE user_point_wallets SET balance=1990 WHERE user_id=%s', (self.a,))
        self.execute('''INSERT INTO user_point_entries
            (user_id,request_id,request_hash,kind,amount,balance_after,created_at,post_id)
            VALUES (%s,'earlier-comments',%s,'community_comment',790,1990,%s,%s)''',
            (self.a, '0' * 64, now, first))
        actors = [self.user(f'actor{i}', 6)[0] for i in range(2)]
        self.parallel([lambda: posts_repo.set_like(actors[0], 'post', first, True),
                       lambda: posts_repo.set_like(actors[1], 'post', second, True)])
        self.assertEqual(points_repo.get_wallet(self.a)['balance'], 2000)
        self.assertEqual(sorted(row['amount'] for row in self.execute("SELECT amount FROM user_point_entries WHERE kind='community_like'")), [0, 10])


class CommunityPointMigrationTests(CommunityDatabaseCase):
    community_points_schema = False

    def test_additive_migration_preserves_wallets_and_ledger(self):
        now = datetime(2026, 10, 2, 12)
        self.execute('INSERT INTO user_point_wallets VALUES (%s,1000,%s,%s)', (self.a, now, now))
        self.execute('''INSERT INTO user_point_entries
            (user_id,request_id,request_hash,kind,amount,balance_after,created_at)
            VALUES (%s,'welcome',%s,'welcome',1000,1000,%s)''', (self.a, '0' * 64, now))
        tables = ('user_point_wallets', 'user_point_entries', 'users', 'posts')
        before = {table: self.execute(f'SELECT * FROM {table}') for table in tables}
        path = Path(__file__).resolve().parents[1] / 'one_touch_loader/sql/migrate_community_points.sql'
        for statement in path.read_text(encoding='utf-8').split(';'):
            if statement.strip():
                self.execute(statement)
        for table, rows in before.items():
            after = self.execute(f'SELECT * FROM {table}')
            self.assertEqual([{key: row[key] for key in rows[0]} for row in after] if rows else after, rows)
        self.post()
        self.assertEqual(points_repo.get_wallet(self.a)['balance'], 1100)
