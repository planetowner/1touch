"""실제 발송·운영 DB 접근 없이 알림 권한, 저장, 재시도와 공급자 응답을 검증해요."""
from contextlib import ExitStack
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
import re
import sqlite3
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from fastapi import HTTPException
from fastapi.testclient import TestClient
import requests
from diagnostics.point_test_support import create_point_tables

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.core import db
    from one_touch_loader.api.main import create_app
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.repos import notifications_repo as repo, posts_repo, betting_repo
    from one_touch_loader.api.services import push_sender
    from one_touch_loader.loaders import notification_push as push, notification_schedule as schedule, notifications as cli
    from one_touch_loader.loaders import live_fixtures_loader as live
from one_touch_loader.core.notifications import DEFAULTS, KINDS, NotificationEvent, fixture_events, state_event, message
from one_touch_loader.core.betting import betting_opens_at

NOW = datetime(2026, 9, 29, 12)
DEVICE = 'b9bfb4a4-3d26-4b8e-95fb-7dc4f16f9639'


def payload(state=1):
    return {'id': 500, 'state_id': state, 'participants': [
        {'id': 10, 'name': 'Home', 'meta': {'location': 'home'}},
        {'id': 20, 'name': 'Away', 'meta': {'location': 'away'}}],
        'scores': [{'participant_id': 10, 'type_id': 1525, 'score': {'goals': 1}},
                   {'participant_id': 20, 'type_id': 1525, 'score': {'goals': 0}}],
        'metadata': [{'type_id': 572, 'values': {'confirmed': True}}],
        'lineups': [{'type_id': 11, 'player_id': 100, 'player_name': 'Starter', 'team_id': 10},
                    {'type_id': 12, 'player_id': 200, 'player_name': 'Bench', 'team_id': 10}], 'events': []}


def event(code='goal', **changes):
    return {'id': 900, 'participant_id': 10, 'type': {'code': code}, 'player_id': 100,
            'related_player_id': 200, 'player_name': 'Primary', 'related_player_name': 'Related',
            'minute': 42, 'extra_minute': None, 'result': '1-0', 'injured': False, 'rescinded': None, **changes}


def fixture(start=None):
    return {'fixture_id': 500, 'state_id': 1, 'starting_at': start or NOW + timedelta(hours=24),
            'season_name': '2026/2027', 'competition_id': 8, 'stage_type_id': 223,
            'home_team_id': 10, 'away_team_id': 20, 'home_team_name': 'Home', 'away_team_name': 'Away'}


class EventTests(unittest.TestCase):
    def test_confirmed_starting_lineup_is_pregame_only(self):
        f = payload()
        result = fixture_events(f, NOW)
        self.assertEqual([(x.kind, x.subjects) for x in result], [('player_starting_xi', (100,))])
        f['metadata'][0]['values']['confirmed'] = False
        self.assertEqual(fixture_events(f, NOW), [])
        f['metadata'][0]['values']['confirmed'] = True
        f['state_id'] = 2
        self.assertEqual(fixture_events(f, NOW), [])

    def test_goal_and_late_assist_share_source_but_have_distinct_keys(self):
        f = payload(2)
        f['events'] = [event(related_player_id=None)]
        first = fixture_events(f, NOW)
        f['events'][0]['related_player_id'] = 200
        second = fixture_events(f, NOW + timedelta(seconds=15))
        self.assertEqual({x.kind for x in first}, {'team_goal', 'player_goal'})
        self.assertEqual({x.key for x in second} - {x.key for x in first}, {'fixture:500:event:900:assist'})

    def test_own_goals_penalties_shootouts_and_rescinded_cards(self):
        expected = {'owngoal': {'team_goal'}, 'penalty': {'team_goal', 'player_goal'},
                    'pen_shootout_goal': set(), 'pen_shootout_miss': set(), 'missed_penalty': set(),
                    'yellowcard': {'player_yellow_card'}, 'redcard': {'player_red_card'},
                    'yellowredcard': {'player_red_card'}, 'VAR': set()}
        for code, kinds in expected.items():
            with self.subTest(code=code):
                f = payload(2)
                f['events'] = [event(code)]
                self.assertEqual({x.kind for x in fixture_events(f, NOW)}, kinds)
        f['events'] = [event('redcard', rescinded=True)]
        self.assertEqual(fixture_events(f, NOW), [])

    def test_real_injury_substitution_targets_outgoing_player(self):
        path = Path(__file__).parent / 'fixtures/sportmonks_2025_five_coach_duplicate_errors.json'
        cases = json.loads(path.read_text())['cases']
        original = next(e for c in cases for e in c['fixture']['events'] if e['id'] == 152218633)
        f = payload(2)
        f['events'] = [{**original, 'participant_id': 10}]
        results = {x.kind: x for x in fixture_events(f, NOW)}
        self.assertEqual(results['player_substitute'].subjects, (25217662,))
        self.assertEqual(results['player_injury'].subjects, (61780,))
        self.assertEqual(results['player_injury'].payload['player'], 'Leandro Trossard')
        f['events'][0]['injured'] = None
        self.assertNotIn('player_injury', {x.kind for x in fixture_events(f, NOW)})

    def test_state_transitions_and_two_followed_teams_share_one_event(self):
        for old, new, expected in [(1, 2, 'team_kickoff'), (2, 3, 'team_half_time'),
                                   (4, 5, 'team_full_time'), (6, 7, 'team_full_time'), (22, 8, 'team_full_time')]:
            result = state_event(payload(new), old, NOW)
            self.assertEqual(result.kind, expected)
            self.assertEqual(result.subjects, (10, 20))
        for old, new in [(2, 2), (3, 3), (3, 4), (5, 7), (1, 10), (2, 15)]:
            self.assertIsNone(state_event(payload(new), old, NOW))

    def test_all_registered_kinds_render_four_languages(self):
        for kind in KINDS:
            for locale in ('ko-KR', 'en-US', 'ja-JP', 'zh-Hans'):
                self.assertTrue(message(kind, {}, locale)['body'])

    def test_push_provider_receives_localized_copy_for_each_language(self):
        row = {'notification_id': 5, 'kind': 'player_starting_xi', 'expires_at': NOW + timedelta(minutes=5)}
        data = {'destination': '/match/500', 'player': 'Son'}
        expected = {
            'en-US': ('Player update', 'Son is in the starting lineup.'),
            'ko-KR': ('선수 소식', 'Son 선발 출전이 확정됐어요.'),
            'ja-JP': ('選手情報', 'Sonのスタメン出場が決まりました。'),
            'zh-Hans': ('球员动态', 'Son确认首发出场。'),
        }
        for locale, (title, body) in expected.items():
            with self.subTest(locale=locale):
                result = push_sender.fcm_message(row, 'test-token', locale, data, NOW)
                self.assertEqual(result['notification'], {'title': title, 'body': body})
                self.assertEqual(result['apns']['payload']['aps']['alert'], result['notification'])
        self.assertEqual(message(row['kind'], data, 'fr-FR'), message(row['kind'], data, 'en'))
        self.assertEqual(message(row['kind'], data, 'zh_CN'), message(row['kind'], data, 'zh-Hans'))

    def test_template_arguments_preserve_user_text_and_use_reminder_minutes(self):
        data = {'display_name': '{player}', 'comment_preview': 'Keep {score} as text', 'player': 'Son'}
        self.assertEqual(message('post_comment', data, 'ja')['body'], '{player}: Keep {score} as text')
        self.assertEqual(message('team_match_reminder', {'home_team': 'Home', 'away_team': 'Away',
                         'minutes_until_kickoff': 15}, 'en')['body'], 'Home vs Away starts in 15 minutes.')

    def test_community_notifications_show_display_name(self):
        data = {'username': 'john_doe', 'display_name': '불광동호날두', 'comment_preview': '좋아요'}
        for kind in ('post_reaction', 'post_comment'):
            body = message(kind, data, 'ko-KR')['body']
            self.assertIn('불광동호날두', body)
            self.assertNotIn('john_doe', body)

    def test_betting_boundary_is_shared_by_market_and_notification(self):
        f = fixture()
        self.assertEqual(betting_opens_at(f), NOW)
        self.assertEqual(betting_repo.market_unavailable_reason(f, NOW - timedelta(microseconds=1), {}), 'betting_not_open')
        self.assertIsNone(betting_repo.market_unavailable_reason(f, NOW, {}))
        self.assertEqual([e.kind for e in schedule.scheduled_events(f, NOW, {})], ['team_new_bets'])
        self.assertEqual(schedule.scheduled_events(f, NOW, None), [])
        self.assertEqual(schedule.scheduled_events(f, f['starting_at'], {}), [])
        self.assertEqual(schedule.scheduled_events({**f, 'state_id': 10}, NOW, {}), [])

    def test_reminder_does_not_require_betting_support_or_arrive_late(self):
        f = {**fixture(NOW + timedelta(hours=1)), 'competition_id': 999}
        events = schedule.scheduled_events(f, NOW, None)
        self.assertEqual([e.kind for e in events], ['team_match_reminder'])
        self.assertEqual(schedule.scheduled_events(f, NOW + timedelta(minutes=5), None), [])
        shifted = {**f, 'starting_at': f['starting_at'] + timedelta(hours=2)}
        self.assertNotEqual(events[0].key, schedule.scheduled_events(shifted, NOW + timedelta(hours=2), None)[0].key)


class SqliteCursor:
    """기존 저장 테스트처럼 SQL 문법만 바꾸고 실제 FK·트랜잭션으로 검증해요."""
    def __init__(self, connection, dictionary=False):
        self.raw = connection.cursor()
        self.dictionary = dictionary

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.raw.close()

    @property
    def rowcount(self):
        return self.raw.rowcount

    @property
    def lastrowid(self):
        return self.raw.lastrowid

    def execute(self, sql, params=()):
        sql = sql.replace('%s', '?').replace(' FOR UPDATE SKIP LOCKED', '').replace(' FOR UPDATE', '')
        sql = sql.replace('ON DUPLICATE KEY UPDATE notification_id=notification_id', 'ON CONFLICT DO NOTHING')
        sql = sql.replace('ON DUPLICATE KEY UPDATE user_id=VALUES(user_id)', 'ON CONFLICT DO NOTHING')
        sql = sql.replace('ON DUPLICATE KEY UPDATE', 'ON CONFLICT DO UPDATE SET')
        sql = re.sub(r'VALUES\((\w+)\)', r'excluded.\1', sql)
        sql = sql.replace('LEFT(c.body,60)', 'SUBSTR(c.body,1,60)')
        # SQLite 기본 빌드에는 DELETE LIMIT이 없어 같은 행 선택을 하위 조회로 표현해요.
        sql = re.sub(r'^DELETE FROM (\w+) WHERE (.+) LIMIT \?$',
                     r'DELETE FROM \1 WHERE rowid IN (SELECT rowid FROM \1 WHERE \2 LIMIT ?)', sql)
        return self.raw.execute(sql, params)

    def _row(self, row):
        if row is None or not self.dictionary:
            return row
        result = dict(zip([c[0] for c in self.raw.description], row))
        return {k: datetime.fromisoformat(v) if k.endswith('_at') and isinstance(v, str) else v for k, v in result.items()}

    def fetchone(self):
        return self._row(self.raw.fetchone())

    def fetchall(self):
        return [self._row(row) for row in self.raw.fetchall()]


class SqliteConnection:
    def __init__(self, connection):
        self.raw = connection

    def cursor(self, dictionary=False):
        return SqliteCursor(self.raw, dictionary)

    def commit(self):
        self.raw.commit()

    def rollback(self):
        self.raw.rollback()

    def close(self):
        pass


class RepositoryTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.db = sqlite3.connect(':memory:')
        self.addCleanup(self.db.close)
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.executescript('''
            CREATE TABLE users(user_id INTEGER PRIMARY KEY,username TEXT,display_name TEXT,favorite_team_id INTEGER,first_name TEXT DEFAULT 'First',last_name TEXT DEFAULT 'Last',suspended_until TEXT);
            CREATE TABLE teams(team_id INTEGER PRIMARY KEY,name TEXT);
            CREATE TABLE players(player_id INTEGER PRIMARY KEY);
            CREATE TABLE user_sessions(token_hash BLOB PRIMARY KEY,user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,expires_at TEXT);
            CREATE TABLE fixtures(fixture_id INTEGER PRIMARY KEY,starting_at TEXT,state_id INTEGER);
            CREATE TABLE user_following_teams(user_id INTEGER,team_id INTEGER);
            CREATE TABLE user_following_players(user_id INTEGER,player_id INTEGER);
            CREATE TABLE user_blocks(user_id INTEGER,blocked_user_id INTEGER);
            CREATE TABLE posts(post_id INTEGER PRIMARY KEY,user_id INTEGER,team_id INTEGER,state TEXT);
            CREATE TABLE post_comments(comment_id INTEGER PRIMARY KEY,post_id INTEGER,user_id INTEGER,reply_to_id INTEGER,body TEXT,created_at TEXT,state TEXT DEFAULT 'active');
            CREATE TABLE post_likes(post_id INTEGER,user_id INTEGER,PRIMARY KEY(post_id,user_id));
            INSERT INTO users(user_id,username,display_name,favorite_team_id) VALUES (1,'Owner','Owner',10),(2,'Actor','Actor',10),(3,'Other','Other',20);
            INSERT INTO teams VALUES (10,'Home'),(20,'Away');
            INSERT INTO players VALUES (100),(200);
            INSERT INTO fixtures VALUES (500,'2026-09-30 12:00:00',1);
            INSERT INTO user_following_teams VALUES (1,10),(1,20),(2,10);
            INSERT INTO user_following_players VALUES (1,100),(1,200);
            INSERT INTO posts VALUES (1,1,10,'active');
        ''')
        ddl = (Path(__file__).resolve().parents[1] / 'one_touch_loader/sql/create_notifications.sql').read_text()
        ddl = re.sub(r'--[^\n]*', '', ddl)
        ddl = re.sub(r'BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY', 'INTEGER PRIMARY KEY AUTOINCREMENT', ddl)
        ddl = re.sub(r'ENUM\([^)]*\)', 'TEXT', ddl)
        ddl = re.sub(r'CHARACTER SET \w+( COLLATE \w+)?', '', ddl)
        ddl = re.sub(r'UNIQUE KEY \w+ \(([^)]*)\)', r'UNIQUE (\1)', ddl)
        ddl = re.sub(r'\n\s+KEY \w+ \([^)]*\),', '', ddl)
        ddl = re.sub(r'\) ENGINE=InnoDB DEFAULT [^;]+;', ');', ddl)
        self.db.executescript(ddl)
        self.db.execute('ALTER TABLE posts ADD COLUMN created_at TEXT')
        self.db.execute('UPDATE posts SET created_at=?', (NOW,))
        create_point_tables(self.db)
        self.conn = SqliteConnection(self.db)
        self.stack.enter_context(patch.object(db, '_pool', SimpleNamespace(get_connection=lambda: self.conn)))
        for module in (repo, push, posts_repo):
            self.stack.enter_context(patch.object(module, 'utc_now', return_value=NOW))
        for user in (1, 2, 3):
            self.db.execute('INSERT INTO user_sessions VALUES (?,?,?)', (repo.token_hash(f'session{user}'), user, NOW + timedelta(days=1)))
        self.db.commit()

    def count(self, table):
        return self.db.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0]

    def register(self, user=1, device=DEVICE):
        repo.register_device(user, f'session{user}', device, {'token': 'private-token-' + device, 'platform': 'android', 'locale': 'ko'})

    def emit(self, kind='team_kickoff', subjects=(10, 20), key='source:1'):
        with db.transaction() as conn, conn.cursor(dictionary=True) as cur:
            repo.enqueue(cur, NotificationEvent(key, kind, subjects, {'destination': '/match/500', 'home_team': 'Home', 'away_team': 'Away'},
                                               NOW + timedelta(minutes=5), 500), NOW)

    def test_preferences_partial_bulk_updates_validate_all_subjects_before_writing(self):
        repo.update_preferences(1, 'team', {'goal': False}, [10])
        self.assertFalse(repo.preference_snapshot(1)['teams']['10']['goal'])
        self.assertTrue(repo.preference_snapshot(1)['teams']['20']['goal'])
        with self.assertRaises(HTTPException):
            repo.update_preferences(1, 'team', {'new_bets': False}, [10, 999])
        self.assertTrue(repo.preference_snapshot(1)['teams']['10']['new_bets'])
        repo.update_preferences(1, 'team', {'substitution': True})
        self.assertTrue(all(x['substitution'] for x in repo.preference_snapshot(1)['teams'].values()))
        self.assertFalse(repo.preference_snapshot(1)['teams']['10']['goal'])
        with self.assertRaises(HTTPException):
            repo.update_preferences(1, 'community', {'new_bets': True})

    def test_following_both_teams_and_repeated_collection_deliver_once_per_device(self):
        self.register()
        self.emit()
        self.emit()
        self.assertEqual(self.count('user_notifications'), 2)
        self.assertEqual(self.count('notification_push_deliveries'), 1)
        sender = Mock()
        self.assertEqual(push.dispatch(apply=True, sender=sender)['sent'], 1)
        self.assertEqual(push.dispatch(apply=True, sender=sender)['sent'], 0)
        self.assertEqual(sender.send.call_count, 1)
        self.assertEqual(repo.list_community(1)['items'], [])

    def test_unfollowing_or_disabling_before_dispatch_suppresses_push(self):
        self.register()
        self.emit(subjects=(10,))
        repo.update_preferences(1, 'team', {'kickoff': False}, [10])
        sender = Mock()
        self.assertEqual(push.dispatch(apply=True, sender=sender)['skipped'], 1)
        sender.send.assert_not_called()
        self.emit(key='source:2', subjects=(20,))
        self.db.execute('DELETE FROM user_following_teams WHERE user_id=1 AND team_id=20')
        self.db.commit()
        self.assertEqual(push.dispatch(apply=True, sender=sender)['skipped'], 1)

    def test_multidevice_success_is_not_repeated_when_another_device_fails(self):
        self.register()
        self.register(device='c9bfb4a4-3d26-4b8e-95fb-7dc4f16f9639')
        self.emit()
        sender = Mock()
        sender.send.side_effect = [None, push_sender.PushError('fcm_unavailable', retryable=True)]
        self.assertEqual(push.dispatch(apply=True, sender=sender), {'apply': True, 'sent': 1, 'skipped': 0, 'failed': 0, 'retry': 1})
        sender.send.side_effect = None
        with patch.object(push, 'utc_now', return_value=NOW + timedelta(seconds=61)):
            self.assertEqual(push.dispatch(apply=True, sender=sender)['sent'], 1)
        self.assertEqual(sender.send.call_count, 3)

    def test_repeated_device_registration_keeps_pending_and_logout_removes_it(self):
        self.register()
        self.emit()
        self.register()
        self.assertEqual(self.count('notification_push_deliveries'), 1)
        self.db.execute('DELETE FROM user_sessions WHERE user_id=1')
        self.db.commit()
        self.assertEqual(self.count('user_push_devices'), 0)
        self.assertEqual(self.count('notification_push_deliveries'), 0)

    def test_device_account_change_does_not_send_previous_users_messages(self):
        self.register()
        self.emit()
        self.register(user=3)
        sender = Mock()
        self.assertEqual(push.dispatch(apply=True, sender=sender)['sent'], 0)
        sender.send.assert_not_called()

    def test_expired_session_and_expired_notification_are_not_sent(self):
        self.register()
        self.emit()
        self.db.execute('UPDATE user_sessions SET expires_at=? WHERE user_id=1', (NOW,))
        self.db.commit()
        self.assertEqual(push.dispatch(apply=True, sender=Mock())['skipped'], 1)
        self.db.execute('UPDATE user_sessions SET expires_at=? WHERE user_id=1', (NOW + timedelta(days=1),))
        self.db.commit()
        self.emit(key='source:2')
        with patch.object(push, 'utc_now', return_value=NOW + timedelta(minutes=6)):
            self.assertEqual(push.dispatch(apply=True, sender=Mock())['skipped'], 1)

    def test_unregistered_device_removed_but_configuration_error_preserves_queue(self):
        self.register()
        self.emit()
        sender = Mock()
        sender.send.side_effect = push_sender.PushError('fcm_permission_denied')
        with self.assertRaises(push_sender.PushError):
            push.dispatch(apply=True, sender=sender)
        self.assertEqual(self.db.execute('SELECT attempts FROM notification_push_deliveries').fetchone()[0], 0)
        sender.send.side_effect = push_sender.PushError('fcm_unregistered')
        self.assertEqual(push.dispatch(apply=True, sender=sender)['skipped'], 1)
        self.assertEqual(self.count('user_push_devices'), 0)

    def test_first_live_snapshot_is_baseline_and_var_removes_pending_goal(self):
        self.register()
        f = payload(2)
        f['events'] = [event()]
        with db.transaction() as conn:
            repo.capture_fixture(conn, f, NOW)
        self.assertEqual(self.count('user_notifications'), 0)
        f['events'].append(event(id=901))
        with db.transaction() as conn:
            repo.capture_fixture(conn, f, NOW + timedelta(seconds=15))
        before = self.count('user_notifications')
        self.assertGreater(before, 0)
        with db.transaction() as conn:
            repo.capture_fixture(conn, f, NOW + timedelta(seconds=30))
        self.assertEqual(self.count('user_notifications'), before)
        f['events'].pop()
        with db.transaction() as conn:
            repo.capture_fixture(conn, f, NOW + timedelta(seconds=45))
        sender = Mock()
        with patch.object(push, 'utc_now', return_value=NOW + timedelta(seconds=46)):
            self.assertGreater(push.dispatch(apply=True, sender=sender)['skipped'], 0)
        sender.send.assert_not_called()

    def test_lineups_and_phase_share_snapshot_and_reject_older_capture(self):
        f = payload()
        with db.transaction() as conn:
            repo.capture_fixture(conn, f, NOW)
        self.assertEqual(self.count('user_notifications'), 1)
        f['state_id'] = 2
        with db.transaction() as conn:
            repo.capture_fixture(conn, f, NOW + timedelta(seconds=15))
            self.assertFalse(repo.capture_fixture(conn, payload(), NOW))
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM user_notifications WHERE kind='team_kickoff'").fetchone()[0], 2)
        self.assertEqual(self.db.execute('SELECT state_id FROM notification_fixture_state').fetchone()[0], 2)

    def test_community_write_and_notification_roll_back_together(self):
        self.register()
        with self.assertRaises(RuntimeError), db.transaction() as conn, conn.cursor(dictionary=True) as cur:
            cur.execute('INSERT INTO post_likes VALUES (%s,%s)', (1, 2))
            repo.notify_post(cur, {'post_id': 1, 'user_id': 1}, 2)
            raise RuntimeError('write failed')
        self.assertEqual(self.count('post_likes'), 0)
        self.assertEqual(self.count('user_notifications'), 0)

    def test_real_post_like_and_comment_hooks_create_inbox_and_push(self):
        self.register()
        posts_repo.set_like(2, 'post', 1, True)
        posts_repo.set_like(2, 'post', 1, True)
        comment_id = posts_repo.create_comment(2, 1, 'Hello', None)
        self.assertEqual(comment_id, 1)
        self.assertEqual(self.count('user_notifications'), 2)
        self.assertEqual(self.count('notification_push_deliveries'), 2)
        inbox = repo.list_community(1, limit=1)
        self.assertEqual(inbox['unread_count'], 2)
        self.assertEqual(inbox['items'][0]['comment_preview'], 'Hello')
        self.assertIsNotNone(inbox['next_before_id'])
        self.assertEqual(len(repo.list_community(1, before_id=inbox['next_before_id'])['items']), 1)
        repo.mark_read(3, 999)
        self.assertEqual(repo.list_community(1)['unread_count'], 2)
        repo.mark_read(1, 999)
        self.assertEqual(repo.list_community(1)['unread_count'], 0)
        sender = Mock()
        self.assertEqual(push.dispatch(apply=True, sender=sender)['sent'], 2)
        self.assertEqual(sender.send.call_args.args[3]['comment_preview'], 'Hello')

    def test_self_reactions_blocked_actors_unlikes_and_deleted_comments(self):
        self.register()
        posts_repo.set_like(1, 'post', 1, True)
        posts_repo.create_comment(1, 1, 'Self', None)
        self.assertEqual(self.count('user_notifications'), 0)
        posts_repo.set_like(2, 'post', 1, True)
        posts_repo.set_like(2, 'post', 1, False)
        self.assertEqual(repo.list_community(1)['items'], [])
        comment_id = posts_repo.create_comment(2, 1, 'Private', None)
        self.db.execute("UPDATE post_comments SET state='deleted' WHERE comment_id=?", (comment_id,))
        self.db.execute('INSERT INTO user_blocks VALUES (1,2)')
        self.db.commit()
        self.assertEqual(repo.list_community(1)['unread_count'], 0)
        sender = Mock()
        push.dispatch(apply=True, sender=sender)
        sender.send.assert_not_called()

    def test_readonly_push_does_not_construct_sender_or_mutate(self):
        self.register()
        self.emit()
        with patch.object(push, 'PushSender') as sender:
            self.assertEqual(push.dispatch(), {'apply': False, 'pending': 1})
        sender.assert_not_called()
        self.assertEqual(self.db.execute('SELECT status FROM notification_push_deliveries').fetchone()[0], 'pending')


class ApiAndSenderTests(unittest.TestCase):
    def test_routes_require_session_and_reject_untyped_or_unknown_settings(self):
        app = create_app()
        client = TestClient(app)
        self.assertEqual(client.get('/v1/users/me/notifications').status_code, 401)
        self.assertEqual(client.put('/v1/users/me/push-devices/' + DEVICE, json={}).status_code, 401)
        app.dependency_overrides[get_user_id] = lambda: 1
        for values in ({'goal': 'false'}, {'goal': 1}, {'goal': None}, {}):
            self.assertEqual(client.patch('/v1/users/me/notification-preferences/team', json={'preferences': values}).status_code, 422)
        self.assertEqual(client.patch('/v1/users/me/notification-preferences/community', json={'preferences': {'new_bets': True}}).status_code, 422)
        for path in ('/v1/users/me/notifications?limit=101', '/v1/users/me/notifications?before_id=-1'):
            self.assertEqual(client.get(path).status_code, 422)

    def test_lock_screen_private_payload_has_content_and_navigation(self):
        row = {'notification_id': 5, 'kind': 'team_goal', 'expires_at': NOW + timedelta(minutes=5)}
        result = push_sender.fcm_message(row, 'device-token', 'ko', {'destination': '/match/500', 'player': 'Player'}, NOW)
        self.assertEqual(result['android']['notification']['visibility'], 'PRIVATE')
        self.assertEqual(result['android']['notification']['channel_id'], 'team_updates')
        self.assertEqual(result['apns']['payload']['aps']['category'], 'ONETOUCH_PRIVATE')
        self.assertEqual(result['data']['notification_id'], '5')
        self.assertIn('Player', result['notification']['body'])
        self.assertEqual(result['android']['ttl'], '300s')

    def test_error_classification_does_not_expose_response_or_delete_invalid_argument_token(self):
        sender = push_sender.PushSender.__new__(push_sender.PushSender)
        sender.project, sender.session = 'touch-42626', Mock()
        sender._access_token = Mock(return_value='oauth-private')
        row = {'notification_id': 5, 'kind': 'team_goal', 'expires_at': NOW + timedelta(minutes=5)}
        for status, code, retryable in [(400, 'fcm_invalid_message', False), (403, 'fcm_permission_denied', False), (429, 'fcm_unavailable', True), (503, 'fcm_unavailable', True)]:
            response = requests.Response()
            response.status_code, response._content = status, b'{"error":{"message":"private-token"}}'
            response.headers['Retry-After'] = '120'
            sender.session.post.return_value = response
            with self.assertRaises(push_sender.PushError) as error:
                sender.send(row, 'private-token', 'en', {'destination': '/match/500'}, NOW)
            self.assertEqual(error.exception.code, code)
            self.assertEqual(error.exception.retryable, retryable)
            self.assertNotIn('private-token', str(error.exception))

    def test_oauth_is_scoped_and_reused_for_multiple_messages(self):
        with patch.dict('os.environ', {'FCM_PROJECT_ID': 'touch-42626', 'FCM_CLIENT_EMAIL': 'account@example.test', 'FCM_PRIVATE_KEY': 'fake-key'}), \
             patch.object(push_sender.jwt, 'encode', return_value='assertion') as encode, patch.object(push_sender.requests, 'Session') as session:
            response = Mock(status_code=200)
            response.json.return_value = {'access_token': 'private-access', 'expires_in': 3600}
            session.return_value.post.return_value = response
            sender = push_sender.PushSender()
            self.assertEqual(sender._access_token(), 'private-access')
            self.assertEqual(sender._access_token(), 'private-access')
            self.assertEqual(session.return_value.post.call_count, 1)
            self.assertEqual(encode.call_args.args[0]['scope'], 'https://www.googleapis.com/auth/firebase.messaging')

    def test_cli_defaults_to_readonly_and_errors_only_include_safe_code(self):
        for task, function in [('schedule', 'run_schedule'), ('push', 'dispatch')]:
            with patch.object(cli, function, return_value={}) as action, patch('sys.stdout', new=io.StringIO()):
                cli.run_cli([task])
            action.assert_called_once_with(apply=False)
        with patch.object(cli, 'dispatch', side_effect=push_sender.PushError('fcm_not_configured')), \
             patch('sys.stderr', new=io.StringIO()) as output, self.assertRaises(SystemExit):
            cli.run_cli(['push', '--apply'])
        self.assertIn('fcm_not_configured', output.getvalue())


if __name__ == '__main__':
    unittest.main()
