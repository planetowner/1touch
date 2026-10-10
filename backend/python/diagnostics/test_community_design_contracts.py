"""디자인 변경으로 생긴 공개 범위와 팔로우 계약을 DB 연결 없이 확인해요."""
import unittest
from unittest.mock import patch
from fastapi import HTTPException

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.api.repos import posts_repo, community_profiles_repo as profiles
    from one_touch_loader.api import db


class CommunityDesignContracts(unittest.TestCase):
    def setUp(self):
        self.no_db = patch.object(db, 'get_conn', side_effect=AssertionError('External DB access is forbidden'))
        self.no_db.start()
        self.addCleanup(self.no_db.stop)

    def comment(self, **changes):
        return dict(user_id=8, username='member', display_name='Member', has_avatar=True,
                    body='Secret body', state='deleted', blocked=False, liked=True, like_count=5, **changes)

    def test_deleted_comment_preserves_author_but_not_body_or_actions(self):
        row = posts_repo._public_comment(self.comment())
        self.assertEqual((row['user_id'], row['display_name'], row['body']), (8, 'Member', ''))
        self.assertEqual(row['avatar_url'], '/v1/users/8/avatar')
        self.assertEqual((row['liked'], row['like_count']), (False, 0))

    def test_blocked_and_hidden_comments_still_mask_author(self):
        for state, blocked in [('hidden', False), ('deleted', True)]:
            row = self.comment()
            row.update(state=state, blocked=blocked)
            result = posts_repo._public_comment(row)
            self.assertIsNone(result['user_id'])
            self.assertIsNone(result['display_name'])
            self.assertIsNone(result['avatar_url'])
            self.assertEqual(result['body'], '')

    def test_deleted_post_reads_never_expose_drafts(self):
        with patch.object(posts_repo, 'fetch_one_dict', return_value={'team_id': 6}) as query:
            self.assertEqual(posts_repo._post_team(9), 6)
            sql = query.call_args.args[0]
            self.assertIn("state IN ('active','deleted')", sql)
            self.assertNotIn("'draft'", sql)

    def test_other_member_activity_uses_viewer_teams_and_blocking(self):
        sql, params = posts_repo._activity_filter(1, (6, 8), comments=True, author_id=7)
        self.assertEqual(params, (7, 6, 8, 1))
        self.assertIn('c.user_id=%s', sql)
        self.assertIn('p.team_id IN (%s,%s)', sql)
        self.assertIn('user_blocks', sql)

    def test_public_profile_returns_no_private_account_fields(self):
        with patch.object(profiles, 'get_user', return_value={'display_name': 'Viewer', 'suspended_until': None}), \
             patch.object(profiles, 'require_visible_author') as visible, \
             patch.object(profiles, 'fetch_one_dict', return_value={'user_id': 8, 'username': 'member', 'display_name': 'Member', 'has_avatar': True, 'following': 1}) as query:
            result = profiles.get_profile(1, 8)
            self.assertTrue(result['following'])
            self.assertFalse(result['is_self'])
            self.assertEqual(set(result), {'user_id','username','display_name','avatar_url','author_deleted','following','is_self'})
            visible.assert_called_once_with(1, 8)
            self.assertNotIn('email', query.call_args.args[0])

    def test_follow_rejects_self_and_blocked_users(self):
        with self.assertRaises(HTTPException) as error:
            profiles.set_following(1, 1, True)
        self.assertEqual(error.exception.status_code, 400)
        with patch.object(profiles, 'transaction') as transaction, \
             patch.object(profiles, 'lock_user', return_value={'display_name': 'Member', 'suspended_until': None}):
            cur = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
            cur.fetchone.return_value = {'blocked': 1}
            with self.assertRaises(HTTPException) as error:
                profiles.set_following(1, 8, True)
            self.assertEqual(error.exception.status_code, 404)
            self.assertEqual(cur.execute.call_count, 1)

    def test_follow_and_unfollow_share_sorted_member_locks(self):
        for following in (True, False):
            with patch.object(profiles, 'transaction') as transaction, \
                 patch.object(profiles, 'lock_user', return_value={'display_name': 'Member', 'suspended_until': None}) as lock:
                cur = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
                cur.fetchone.return_value = None
                profiles.set_following(8, 1, following)
                self.assertEqual([call.args[1] for call in lock.call_args_list], [1, 8])
                sql, args = cur.execute.call_args.args
                self.assertIn('ON DUPLICATE KEY' if following else 'DELETE FROM', sql)
                self.assertEqual(args, (8, 1))

if __name__ == '__main__':
    unittest.main()
