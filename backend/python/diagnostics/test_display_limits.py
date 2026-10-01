"""운영 DB 없이 안내 값과 서버 검증이 같은 규칙을 쓰는지 확인해요."""
from datetime import datetime, timedelta
import unittest
from unittest.mock import Mock, patch

from fastapi import HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.api.main import create_app
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.repos import betting_repo, community_repo, posts_repo
    from one_touch_loader.api.routes import posts, teams, users
    from one_touch_loader.api.services import profile_changes
from one_touch_loader.api.schemas.betting import BettingMarketResponse
from one_touch_loader.core.betting import betting_opens_at


class DisplayLimitTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app()
        self.app.dependency_overrides[get_user_id] = lambda: 1
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)

    def test_attachment_limit_matches_validation_for_drafts_and_posts(self):
        response = self.client.get('/v1/posts/limits')
        self.assertEqual(response.status_code, 200, response.text)
        count = response.json()['max_attachments']
        self.assertEqual(count, posts_repo.MAX_ATTACHMENTS)
        for model in (posts.DraftBody, posts.PostBody):
            model(title='Title', attachment_ids=list(range(1, count + 1)))
            with self.assertRaises(ValidationError):
                model(title='Title', attachment_ids=list(range(1, count + 2)))
        with patch.object(posts_repo, 'MAX_ATTACHMENTS', 3):
            self.assertEqual(self.client.get('/v1/posts/limits').json(), {'max_attachments': 3})
            with self.assertRaises(HTTPException) as raised:
                posts_repo._set_attachments(Mock(), 1, 1, [1, 2, 3, 4])
            self.assertEqual(raised.exception.detail, "Use up to 3 different attachments")

    def test_both_profile_routes_return_the_actual_shared_change_rule(self):
        available = datetime(2026, 10, 7, 12)
        with patch.object(profile_changes, 'MAX_CHANGES', 3), \
             patch.object(profile_changes, 'CHANGE_WINDOW', timedelta(days=7)):
            error = profile_changes.ProfileChangeLimitError(available)
            cases = [
                (users, 'update_profile', '/v1/users/me/profile', {'username': 'user', 'display_name': 'NewName', 'first_name': 'New', 'last_name': 'Name'}),
                (teams, 'set_following_and_favorite', '/v1/users/me/following/teams', {'teamIds': [6], 'favoriteTeamId': 6}),
            ]
            for module, function, path, body in cases:
                with self.subTest(path=path), patch.object(module, function, side_effect=error):
                    response = self.client.put(path, json=body)
                    self.assertEqual(response.status_code, 409, response.text)
                    detail = response.json()['detail']
                    self.assertEqual(detail['max_changes'], 3)
                    self.assertEqual(detail['window_days'], 7)
                    self.assertEqual(detail['available_at'], '2026-10-07T12:00:00Z')
            cursor = Mock()
            cursor.fetchall.return_value = [{'changed_at': available - timedelta(days=7)}] * 3
            with self.assertRaises(profile_changes.ProfileChangeLimitError) as raised:
                profile_changes.check_change_limit(cursor, 1, 'display_name', available)
            self.assertEqual(cursor.execute.call_args.args[1][-1], 3)
            self.assertEqual(raised.exception.detail(), error.detail())

    def test_market_exposes_the_server_stake_unit_and_opening_time(self):
        now = datetime(2026, 9, 30, 12)
        fixture = {'fixture_id': 500, 'starting_at': now + timedelta(hours=25),
                   'state_id': 1, 'season_name': '2026/2027', 'competition_id': 8, 'stage_type_id': 223}
        with patch.object(betting_repo, 'fetch_one_dict', side_effect=[fixture, None]), \
             patch.object(betting_repo, 'fetch_all_dict', return_value=[]), \
             patch.object(betting_repo, '_prediction', return_value=None), \
             patch.object(betting_repo, 'get_wallet', return_value={'balance': 0, 'initialized': False, 'welcome_points': 1000}), \
             patch.object(betting_repo, 'utc_now', return_value=now), \
             patch.object(betting_repo, 'STAKE_UNIT', 25):
            market = BettingMarketResponse(**betting_repo.get_market(1, 500))
        self.assertEqual(market.stake_unit, 25)
        self.assertEqual(market.opens_at, betting_opens_at(fixture).isoformat(timespec='microseconds') + 'Z')
        self.assertEqual(market.unavailable_reason, 'betting_not_open')

    def test_community_rules_keep_membership_check_and_return_message_keys(self):
        with patch.object(community_repo, 'community_user') as access:
            response = self.client.get('/v1/community/rules?team_id=6')
        self.assertEqual(response.status_code, 200, response.text)
        access.assert_called_once_with(1, 6, read_only=True)
        rules = response.json()['rules']
        self.assertEqual(set(rules), {'title', 'items'})
        self.assertEqual(rules['title'], 'Community Ground Rules')
        self.assertEqual(rules['items'][0]['body'], 'Disagree with the take, not the person.')
        self.assertEqual(len(rules['items']), 5)
