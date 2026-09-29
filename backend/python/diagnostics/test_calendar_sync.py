"""실제 DB·Google 계정에 접근하지 않고 동기화와 권한 경계를 검사해요."""
from datetime import datetime, timedelta, timezone
import json
import os
import unittest
from unittest.mock import MagicMock, patch

from cryptography.fernet import Fernet
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
import requests

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.api.services import calendar_schedule as schedule, google_calendar as google
    from one_touch_loader.api.repos import calendar_repo as repo
    from one_touch_loader.api.routes import calendar as route

NOW = datetime(2026, 9, 29, 12, tzinfo=timezone.utc)
MATCH = schedule.CalendarMatch(123, 'Liverpool vs Arsenal', NOW + timedelta(days=1), 'Anfield')


def response(status=200, body=None):
    result = requests.Response()
    result.status_code = status
    result._content = json.dumps(body or {}).encode()
    return result


class CalendarScheduleTests(unittest.TestCase):
    def test_all_pages_and_teams_share_one_fixture_and_skip_missing_or_past_times(self):
        def row(i, start='2026-09-30 12:00:00'):
            return {'fixture_id': i, 'starting_at': start, 'home_team_name': 'Home', 'away_team_name': 'Away'}
        def page(team_id, **kwargs):
            if team_id == 9:
                return [row(1)]
            return [row(i) for i in range(1, 201)] if kwargs['offset'] == 0 else [row(201), row(202, None), row(203, '2026-09-01 00:00:00')]
        with patch.object(schedule, 'list_team_fixtures', side_effect=page) as load:
            matches = schedule.load_schedule([8, 9], NOW)
        self.assertEqual(len(matches), 201)
        self.assertEqual(len({m.fixture_id for m in matches}), 201)
        self.assertEqual(matches[0].end - matches[0].start, timedelta(hours=2))
        self.assertEqual(load.call_args_list[1].kwargs['offset'], 200)
        self.assertEqual(matches[0].start.utcoffset(), timedelta(0))

    def test_ics_has_stable_identity_updated_times_and_thirty_minute_alarm(self):
        first = schedule.render_icalendar('Liverpool', [MATCH], NOW)
        changed = schedule.CalendarMatch(MATCH.fixture_id, MATCH.title, MATCH.start + timedelta(hours=3), MATCH.location)
        second = schedule.render_icalendar('Liverpool', [changed], NOW + timedelta(hours=1))
        for document in (first, second):
            self.assertIn('UID:fixture-123@1touch.football\r\n', document)
            self.assertIn('TRIGGER:-PT30M\r\n', document)
        self.assertIn('DTSTART:20260930T150000Z', second)
        self.assertIn('DTEND:20260930T170000Z', second)

    def test_ics_escapes_and_folds_utf8_without_creating_extra_events(self):
        title = '대한민국' * 60 + ',;\\\nBEGIN:VEVENT'
        match = schedule.CalendarMatch(1, title, MATCH.start, 'Line1\r\nLine2')
        doc = schedule.render_icalendar(title, [match], NOW)
        self.assertTrue(all(len(line.encode()) <= 75 for line in doc.split('\r\n')))
        self.assertEqual(doc.split('\r\n').count('BEGIN:VEVENT'), 1)
        unfolded = doc.replace('\r\n ', '')
        self.assertIn('LOCATION:Line1\\nLine2', unfolded)
        self.assertIn('\\,\\;\\\\\\nBEGIN:VEVENT', unfolded)


class GoogleCalendarTests(unittest.TestCase):
    def setUp(self):
        self.settings = patch.dict(os.environ, {
            'GOOGLE_CALENDAR_CLIENT_ID': 'our-web-client',
            'GOOGLE_CALENDAR_CLIENT_SECRET': 'test-secret',
            'CALENDAR_TOKEN_ENCRYPTION_KEY': Fernet.generate_key().decode(),
        })
        self.settings.start()
        self.addCleanup(self.settings.stop)
        session_patch = patch.object(google.requests, 'Session')
        self.session = session_patch.start().return_value
        self.addCleanup(session_patch.stop)
        self.client = google.GoogleCalendarClient('test-access-token')

    def test_code_exchange_checks_calendar_scope_and_expected_client(self):
        tokens = {'scope': google.CALENDAR_SCOPE + ' openid', 'id_token': 'signed', 'refresh_token': 'refresh'}
        with patch.object(google.requests, 'post', return_value=response(body=tokens)) as post, patch.object(google, '_verify_token', return_value={'sub': 'subject'}) as verify:
            self.assertEqual(google.exchange_code('one-time-code'), ('subject', tokens))
            self.assertEqual(verify.call_args.args[-1], 'our-web-client')
            self.assertEqual(post.call_args.kwargs['data']['redirect_uri'], '')
            post.return_value = response(body={'scope': 'openid'})
            with self.assertRaises(google.GoogleCalendarError) as error:
                google.exchange_code('code-without-calendar-consent')
            self.assertEqual(error.exception.code, 'calendar_permission_required')

    def test_revoked_refresh_token_requires_reconnection_without_exposing_tokens(self):
        encrypted = google.token_cipher().encrypt(b'private-refresh').decode()
        self.assertNotIn('private-refresh', encrypted)
        with patch.object(google.requests, 'post', return_value=response(400, {'error': 'invalid_grant'})):
            with self.assertRaises(google.GoogleCalendarError) as error:
                google.refresh_access(encrypted)
        self.assertEqual(str(error.exception), 'calendar_reconnect_required')
        self.assertNotIn('private-refresh', str(error.exception))

    def test_unchanged_events_are_not_rewritten_and_google_pagination_is_complete(self):
        existing = {'id': MATCH.event_id, **google.event_body(MATCH)}
        existing['start']['dateTime'] = '2026-09-30T12:00:00Z'
        self.session.request.side_effect = [response(body={'items': [existing], 'nextPageToken': 'next'}), response(body={})]
        self.assertEqual(self.client.sync('calendar@example.com', [MATCH], NOW), 1)
        self.assertEqual([c.args[0] for c in self.session.request.call_args_list], ['GET', 'GET'])
        self.assertEqual(self.session.request.call_args.kwargs['params']['pageToken'], 'next')

    def test_changed_kickoff_updates_same_event_with_duration_and_reminder(self):
        old = {'id': MATCH.event_id, **google.event_body(MATCH)}
        changed = schedule.CalendarMatch(123, MATCH.title, MATCH.start + timedelta(hours=2), MATCH.location)
        self.session.request.side_effect = [response(body={'items': [old]}), response()]
        self.client.sync('calendar@example.com', [changed], NOW)
        call = self.session.request.call_args
        self.assertEqual(call.args[0], 'PATCH')
        self.assertTrue(call.args[1].endswith('/onetouch123'))
        self.assertEqual(call.kwargs['json']['end']['dateTime'], '2026-09-30T16:00:00+00:00')
        self.assertEqual(call.kwargs['json']['reminders']['overrides'], [{'method': 'popup', 'minutes': 30}])

    def test_retry_after_partial_insert_reuses_id(self):
        self.session.request.side_effect = [response(body={}), response(409), response()]
        self.client.sync('calendar', [MATCH], NOW)
        calls = self.session.request.call_args_list
        self.assertEqual(calls[1].kwargs['json']['id'], 'onetouch123')
        self.assertEqual(calls[2].args[0], 'PATCH')
        self.assertTrue(calls[2].args[1].endswith('/onetouch123'))

    def test_cancelled_or_unsubscribed_future_events_are_removed_but_history_stays(self):
        events = [{'id': 'future', 'start': {'dateTime': (NOW + timedelta(days=1)).isoformat()}},
                  {'id': 'started', 'start': {'dateTime': (NOW - timedelta(minutes=30)).isoformat()}}]
        self.session.request.side_effect = [response(body={'items': events}), response(204)]
        self.client.sync('calendar', [], NOW)
        self.assertEqual(self.session.request.call_count, 2)
        self.assertTrue(self.session.request.call_args.args[1].endswith('/future'))

    def test_missing_calendar_is_not_reported_as_success(self):
        self.session.request.return_value = response(404)
        with self.assertRaises(google.GoogleCalendarError) as error:
            self.client.sync('deleted-calendar', [MATCH], NOW)
        self.assertEqual(error.exception.code, 'calendar_missing')


class CalendarRepositoryTests(unittest.TestCase):
    def setUp(self):
        self.cur = MagicMock()
        self.conn = MagicMock()
        self.conn.cursor.return_value.__enter__.return_value = self.cur
        transaction = patch.object(repo, 'transaction')
        transaction.start().return_value.__enter__.return_value = self.conn
        self.addCleanup(transaction.stop)
        self.connection = {'google_subject': 'same-user', 'refresh_token': 'encrypted', 'calendar_id': 'calendar', 'last_error': None}

    def test_new_connection_encrypts_refresh_token_and_saves_created_calendar(self):
        self.cur.fetchone.return_value = None
        cipher = Fernet(Fernet.generate_key())
        tokens = {'access_token': 'access', 'refresh_token': 'private-refresh'}
        with patch.object(google, 'configured'), patch.object(repo, 'lock_user'), patch.object(google, 'exchange_code', return_value=('same-user', tokens)), patch.object(google, 'token_cipher', return_value=cipher), patch.object(google, 'GoogleCalendarClient') as client:
            client.return_value.create_calendar.return_value = 'new-calendar'
            repo.connect(7, 'code')
        saved = self.cur.execute.call_args.args[1]
        self.assertEqual((saved[0], saved[1], saved[3]), (7, 'same-user', 'new-calendar'))
        self.assertNotEqual(saved[2], 'private-refresh')
        self.assertEqual(cipher.decrypt(saved[2].encode()), b'private-refresh')
        client.assert_called_once_with('access')
        client.return_value.close.assert_called_once()

    def test_reconnect_preserves_calendar_and_refresh_token_when_google_omits_new_token(self):
        self.cur.fetchone.return_value = self.connection
        with patch.object(google, 'configured'), patch.object(repo, 'lock_user'), patch.object(google, 'exchange_code', return_value=('same-user', {})), patch.object(google, 'GoogleCalendarClient') as client:
            repo.connect(7, 'code')
        self.assertEqual(self.cur.execute.call_args.args[1], (7, 'same-user', 'encrypted', 'calendar'))
        client.assert_not_called()

    def test_connect_rejects_switching_google_accounts_without_disconnect(self):
        self.cur.fetchone.return_value = self.connection
        with patch.object(google, 'configured'), patch.object(repo, 'lock_user'), patch.object(google, 'exchange_code', return_value=('other-user', {})):
            with self.assertRaises(google.GoogleCalendarError) as error:
                repo.connect(7, 'code')
        self.assertEqual(error.exception.code, 'calendar_account_mismatch')

    def test_sync_records_reconnect_error_for_app_and_scheduled_retry(self):
        self.cur.fetchone.return_value = self.connection
        self.cur.fetchall.return_value = [{'team_id': 8}]
        with patch.object(repo, 'load_schedule', return_value=[MATCH]), patch.object(google, 'refresh_access', side_effect=google.GoogleCalendarError('calendar_reconnect_required', 409)), patch.object(repo, 'execute') as save_error:
            with self.assertRaises(google.GoogleCalendarError):
                repo.sync_user(7)
        self.assertEqual(save_error.call_args.args[1], ('calendar_reconnect_required', 7))

    def test_missing_connection_cannot_create_a_subscription(self):
        self.cur.fetchone.return_value = None
        with patch.object(repo, 'get_team', return_value={'team_id': 8}), patch.object(repo, 'sync_user') as sync:
            with self.assertRaises(google.GoogleCalendarError):
                repo.set_subscription(7, 8, True)
        sync.assert_not_called()


class CalendarRouteTests(unittest.TestCase):
    def setUp(self):
        self.app = FastAPI()
        self.app.include_router(route.router, prefix='/v1')
        self.client = TestClient(self.app)

    def test_feed_is_public_and_contains_no_user_data(self):
        with patch.object(route, 'get_team', return_value={'name': 'Liverpool'}), patch.object(route, 'load_schedule', return_value=[MATCH]):
            result = self.client.get('/v1/calendars/teams/8.ics')
        self.assertEqual(result.status_code, 200)
        self.assertTrue(result.headers['content-type'].startswith('text/calendar'))
        self.assertIn('BEGIN:VCALENDAR', result.text)
        self.assertNotIn('refresh_token', result.text)
        self.assertIn('max-age=300', result.headers['cache-control'])

    def test_mutations_require_login_and_use_authenticated_user(self):
        self.assertEqual(self.client.put('/v1/users/me/calendar/teams/8').status_code, 401)
        self.app.dependency_overrides[route.get_user_id] = lambda: 7
        with patch.object(repo, 'set_subscription', return_value=2) as subscribe:
            result = self.client.put('/v1/users/me/calendar/teams/8', json={'user_id': 999})
        subscribe.assert_called_once_with(7, 8, True)
        self.assertEqual(result.json(), {'synced_matches': 2})

    def test_provider_errors_return_codes_without_credentials(self):
        self.app.dependency_overrides[route.get_user_id] = lambda: 7
        with patch.object(repo, 'connect', side_effect=google.GoogleCalendarError('calendar_reconnect_required', 409)):
            result = self.client.post('/v1/users/me/calendar/google', json={'server_auth_code': 'sensitive-code'})
        self.assertEqual(result.status_code, 409)
        self.assertNotIn('sensitive-code', result.text)


if __name__ == '__main__':
    unittest.main()
