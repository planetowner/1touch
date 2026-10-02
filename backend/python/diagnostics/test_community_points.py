"""실제 저장 SQL로 적립·권한·중복 요청·롤백을 운영 DB 없이 확인해요."""
from contextlib import ExitStack
from datetime import datetime, timedelta
import sqlite3
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from diagnostics.point_test_support import create_point_tables
from diagnostics.test_notifications import SqliteConnection

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.core import db
    from one_touch_loader.api.repos import posts_repo, points_repo, betting_repo
    from one_touch_loader.api.routes import betting
    from one_touch_loader.api.deps import get_user_id


class CommunityPointRepositoryTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.raw = sqlite3.connect(':memory:', check_same_thread=False)
        self.addCleanup(self.raw.close)
        self.raw.execute('PRAGMA foreign_keys=ON')
        self.raw.executescript('''
            CREATE TABLE users (user_id INTEGER PRIMARY KEY, username TEXT DEFAULT 'User',
                display_name TEXT DEFAULT 'User',
                favorite_team_id INTEGER DEFAULT 6, suspended_until TEXT);
            CREATE TABLE user_blocks (user_id INTEGER, blocked_user_id INTEGER);
            CREATE TABLE posts (post_id INTEGER PRIMARY KEY AUTOINCREMENT,
                team_id INTEGER, user_id INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
                category TEXT, title TEXT, body TEXT, created_at TEXT, state TEXT, edited_at TEXT);
            CREATE TABLE post_comments (comment_id INTEGER PRIMARY KEY AUTOINCREMENT,
                post_id INTEGER REFERENCES posts(post_id), user_id INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
                reply_to_id INTEGER, body TEXT, created_at TEXT, state TEXT DEFAULT 'active', edited_at TEXT);
            CREATE TABLE post_likes (post_id INTEGER REFERENCES posts(post_id),
                user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE, PRIMARY KEY(post_id,user_id));
            CREATE TABLE comment_likes (comment_id INTEGER, user_id INTEGER, PRIMARY KEY(comment_id,user_id));
            CREATE TABLE post_attachments (attachment_id INTEGER, post_id INTEGER, position INTEGER, object_key TEXT);
        ''')
        create_point_tables(self.raw)
        self.raw.executemany('INSERT INTO users(user_id) VALUES (?)', [(i,) for i in range(1, 102)])
        self.raw.commit()
        conn = SqliteConnection(self.raw)
        self.stack.enter_context(patch.object(db, '_pool', SimpleNamespace(get_connection=lambda: conn)))
        self.now = datetime(2026, 10, 2, 12)
        for module in (posts_repo, points_repo):
            self.stack.enter_context(patch.object(module, 'utc_now', side_effect=lambda: self.now))
        self.stack.enter_context(patch.object(posts_repo, 'notify_post'))
        app = FastAPI()
        app.include_router(betting.router, prefix='/v1')
        app.dependency_overrides[get_user_id] = lambda: 1
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def post(self, user=1, *, draft=False):
        return posts_repo.create_post(user, 6, 'general', 'Title', 'Body', [], draft=draft)

    def comment(self, post, user=2, body='ㅋ', reply=None):
        return posts_repo.create_comment(user, post, body, reply)

    def like(self, post, user=2, liked=True):
        posts_repo.set_like(user, 'post', post, liked)

    def balance(self, user=1):
        return points_repo.get_wallet(user)['balance']

    def entries(self, kind=None):
        sql = 'SELECT * FROM user_point_entries' + (' WHERE kind=%s' if kind else '')
        with SqliteConnection(self.raw).cursor(dictionary=True) as cur:
            cur.execute(sql, (kind,) if kind else ())
            return cur.fetchall()

    def test_example_earns_430_in_shared_wallet(self):
        first, second = self.post(), self.post()
        for actor in range(2, 17):
            self.like(first if actor < 10 else second, actor)
        for actor in range(2, 10):
            self.comment(second, actor)
        self.assertEqual(self.balance(), 1430)
        self.assertEqual(sum(e['amount'] for e in self.entries()), self.balance())
        self.assertEqual(betting_repo.get_wallet(1)['balance'], 1430)

    def test_only_first_three_publications_count_and_deletion_does_not_reset(self):
        posts = [self.post() for _ in range(4)]
        posts_repo.delete_post(1, posts[0])
        self.post()
        self.assertEqual(self.balance(), 1300)
        self.assertEqual([e['amount'] for e in self.entries('community_post')], [100, 100, 100, 0, 0])
        self.now += timedelta(days=1)
        self.post()
        self.assertEqual(self.balance(), 1400)

    def test_drafts_award_only_when_published_and_edits_never_award(self):
        draft = self.post(draft=True)
        self.assertFalse(points_repo.get_wallet(1)['initialized'])
        self.now += timedelta(days=6)
        posts_repo.publish_draft(1, draft)
        self.assertEqual(self.balance(), 1100)
        posts_repo.update_post(1, draft, 'general', 'Edited', 'New', [])
        with self.assertRaises(HTTPException):
            posts_repo.publish_draft(1, draft)
        self.like(draft)
        self.assertEqual(self.balance(), 1110)

    def test_self_and_comment_likes_do_not_award(self):
        post = self.post()
        self.like(post, 1)
        comment = self.comment(post, 1)
        posts_repo.set_like(2, 'comment', comment, True)
        self.assertEqual(self.balance(), 1100)
        self.assertEqual(len(self.entries()), 2)

    def test_short_comments_replies_edits_and_recreation(self):
        post = self.post()
        original = self.comment(post)
        self.comment(post, reply=original)
        posts_repo.change_comment(2, original, '수정한 댓글')
        posts_repo.change_comment(2, original, None)
        self.comment(post)
        self.assertEqual(self.balance(), 1110)
        self.assertEqual(len(self.entries('community_comment')), 1)
        second = self.post()
        self.comment(second)
        self.assertEqual(self.balance(), 1220)

    def test_like_limit_and_repeat_after_unlike(self):
        post = self.post()
        self.like(post)
        self.like(post)
        self.like(post, liked=False)
        self.like(post)
        for actor in range(3, 23):
            self.like(post, actor)
        self.assertEqual(self.balance(), 1300)
        self.assertEqual(len(self.entries('community_like')), 21)
        self.assertEqual(self.entries('community_like')[-1]['amount'], 0)

    def test_quality_counts_likes_over_twenty_and_unique_commenters(self):
        post = self.post()
        for actor in range(2, 26):
            self.like(post, actor)
        self.assertEqual(self.entries('community_quality'), [])
        self.comment(post, 2)
        self.assertEqual(self.balance(), 1510)
        self.comment(post, 2)
        self.like(post, 26)
        self.like(post, 2, liked=False)
        self.like(post, 2)
        self.assertEqual(len(self.entries('community_quality')), 1)

    def test_duplicate_deleted_and_self_comments_do_not_fill_quality_threshold(self):
        post = self.post()
        for actor in range(2, 25):
            self.like(post, actor)
        deleted = self.comment(post, 2)
        posts_repo.change_comment(2, deleted, None)
        self.comment(post, 3)
        self.comment(post, 3)
        self.comment(post, 1)
        self.assertEqual(self.entries('community_quality'), [])
        self.comment(post, 4)
        self.assertEqual(len(self.entries('community_quality')), 1)

    def test_old_post_discounts_all_interactions_and_keeps_twenty_like_limit(self):
        post = self.post()
        self.now += timedelta(days=7)
        for actor in range(2, 27):
            self.like(post, actor)
        self.comment(post)
        self.assertEqual(self.balance(), 1305)
        self.assertEqual(self.entries('community_quality')[0]['amount'], 100)
        self.assertEqual(sum(e['amount'] for e in self.entries('community_like')), 100)

    def test_daily_cap_covers_all_posts_but_excludes_welcome_and_betting(self):
        first, second, third = self.post(), self.post(), self.post()
        # 첫 글 댓글 25개와 보너스로 450점, 다음 글 댓글 24개로 240점을 더 받아요.
        for actor in range(2, 27):
            self.comment(first, actor)
        for actor in range(2, 26):
            self.comment(second, actor)
        self.assertEqual(self.balance(), 1990)
        with db.transaction() as conn, conn.cursor(dictionary=True) as cur:
            cur.execute('UPDATE user_point_wallets SET balance=balance+5000 WHERE user_id=1')
            points_repo.record_entry(cur, 1, None, 'bet-test', '0' * 64, 'bet_win', 5000, 6990, 1, self.now)
        self.comment(second, 26)
        self.like(third, 2)
        self.assertEqual(self.balance(), 7000)
        self.assertEqual(self.entries('community_quality')[-1]['amount'], 0)
        self.now += timedelta(days=1)
        self.like(third, 2, liked=False)
        self.like(third, 2)
        self.comment(second, 26)
        self.assertEqual(self.balance(), 7000)
        self.like(third, 3)
        self.assertEqual(self.balance(), 7010)

    def test_bonus_uses_only_remaining_daily_allowance(self):
        first, second = self.post(), self.post()
        for actor in range(2, 27):
            self.comment(first, actor)
        for actor in range(2, 27):
            self.comment(second, actor)
        self.assertEqual(self.balance(), 2000)
        self.assertEqual([e['amount'] for e in self.entries('community_quality')], [200, 100])

    def test_recipient_country_controls_midnight_and_sender_country_does_not(self):
        points_repo.initialize_wallet(1, 'KR')
        points_repo.initialize_wallet(2, 'US')
        for _ in range(3):
            self.post()
        self.now = datetime(2026, 10, 2, 14, 59, 59)
        self.post()
        self.assertEqual(self.balance(), 1300)
        self.now = datetime(2026, 10, 2, 15)
        post = self.post()
        self.like(post)
        self.assertEqual(self.balance(), 1410)
        self.assertEqual(self.entries('community_post')[-1]['amount'], 100)

    def test_country_update_preserves_balance_and_existing_entries(self):
        self.post()
        before = self.entries()
        points_repo.initialize_wallet(1, 'CN')
        points_repo.initialize_wallet(1)
        self.assertEqual(self.entries(), before)
        self.assertEqual(self.balance(), 1100)
        self.assertEqual(self.raw.execute('SELECT country_code FROM user_point_wallets WHERE user_id=1').fetchone()[0], 'CN')

    def test_failed_ledger_write_rolls_back_post_wallet_and_interaction(self):
        with patch.object(points_repo, 'record_entry', side_effect=RuntimeError('ledger failed')):
            with self.assertRaises(RuntimeError):
                self.post()
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM posts').fetchone()[0], 0)
        self.assertEqual(self.balance(), 0)
        post = self.post()
        with patch.object(points_repo, 'record_entry', side_effect=RuntimeError('ledger failed')):
            for operation in (lambda: self.like(post), lambda: self.comment(post)):
                with self.assertRaises(RuntimeError):
                    operation()
        self.assertEqual(self.balance(), 1100)
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM post_likes').fetchone()[0], 0)
        self.assertEqual(self.raw.execute('SELECT COUNT(*) FROM post_comments').fetchone()[0], 0)

    def test_hidden_deleted_draft_and_other_team_posts_cannot_earn(self):
        for state in ('hidden', 'deleted', 'draft'):
            post = self.post()
            self.raw.execute('UPDATE posts SET state=? WHERE post_id=?', (state, post))
            self.raw.commit()
            for operation in (lambda: self.like(post), lambda: self.comment(post)):
                with self.assertRaises(HTTPException) as error:
                    operation()
                self.assertEqual(error.exception.status_code, 404)
        post = self.post()
        self.raw.execute('UPDATE users SET favorite_team_id=99 WHERE user_id=2')
        self.raw.commit()
        with self.assertRaises(HTTPException) as error:
            self.like(post)
        self.assertEqual(error.exception.status_code, 403)
        self.assertEqual(self.entries('community_like'), [])

    def test_deleted_author_gets_no_wallet_and_deletion_preserves_other_awards(self):
        post = self.post()
        self.like(post)
        self.raw.execute('DELETE FROM users WHERE user_id=2')
        self.raw.commit()
        self.assertEqual(self.balance(), 1110)
        self.raw.execute('DELETE FROM users WHERE user_id=1')
        self.raw.commit()
        self.like(post, 3)
        self.comment(post, 3)
        self.assertEqual(self.balance(), 0)
        self.assertEqual(self.entries(), [])

    def test_wallet_and_history_api_and_country_validation(self):
        self.assertEqual(self.client.post('/v1/users/me/points/initialize', json={'country_code': 'kr'}).status_code, 200)
        self.assertEqual(self.raw.execute('SELECT country_code FROM user_point_wallets WHERE user_id=1').fetchone()[0], 'KR')
        self.post()
        response = self.client.get('/v1/users/me/points/entries').json()
        self.assertEqual(response['items'][0]['kind'], 'community_post')
        self.assertEqual(response['items'][0]['post_id'], 1)
        self.assertEqual(self.client.get('/v1/users/me/points').json()['balance'], 1100)
        self.assertEqual(self.client.post('/v1/users/me/points/initialize').json()['balance'], 1100)
        for invalid in ('K', 'KOR', '12', ''):
            self.assertEqual(self.client.post('/v1/users/me/points/initialize', json={'country_code': invalid}).status_code, 422)


if __name__ == '__main__':
    unittest.main()
