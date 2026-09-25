"""팔로우 팀 조회는 열고, 최애팀 전용 저장 경계는 유지하는지 확인해요."""
from datetime import datetime
import unittest
from unittest.mock import patch

from fastapi import HTTPException

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.api.repos import posts_repo, community_repo
    from one_touch_loader.api.routes import attachments
    from one_touch_loader.api.services.community_periods import PostPeriod


class FollowedCommunityReadTests(unittest.TestCase):
    def setUp(self):
        self.user = {'user_id': 1, 'favorite_team_id': 83, 'username': 'viewer',
                     'first_name': 'First', 'last_name': 'Last', 'suspended_until': None}
        self.post = {'post_id': 91, 'team_id': 9, 'user_id': 2, 'state': 'active',
                     'body': 'Other team post', 'title': 'Title', 'username': 'author',
                     'created_at': datetime(2026, 9, 23)}
        self.patch(posts_repo, 'get_user', return_value=self.user)
        self.followed = self.patch(posts_repo, 'list_following_team_ids', return_value=[83, 9])
        self.patch(posts_repo, 'fetch_one_dict', side_effect=lambda *args: dict(self.post))
        self.patch(posts_repo, 'fetch_all_dict', return_value=[])
        self.visible_author = self.patch(posts_repo, 'require_visible_author')
        self.patch(community_repo, 'fetch_one_dict', return_value={'total': 3})
        self.patch(attachments, 'fetch_one_dict', return_value={
            'attachment_id': 7, 'post_id': 91, 'post_state': 'active', 'user_id': 2,
        })

    def patch(self, target, name, **kwargs):
        patcher = patch.object(target, name, **kwargs)
        mocked = patcher.start()
        self.addCleanup(patcher.stop)
        return mocked

    def read_operations(self):
        return [
            lambda: posts_repo.list_posts(1, 9, None, posts_repo.PostSort.newest, PostPeriod.all_time, 50, 0),
            lambda: posts_repo.get_post(1, 91),
            lambda: posts_repo.list_comments(1, 91, 0, 50),
            lambda: community_repo.get_rules(1, 9, 'ko'),
            lambda: community_repo.count_followers(1, 9),
            lambda: attachments._accessible_attachment(7, 1),
        ]

    def test_posts_comments_rules_followers_and_attachments_share_read_access(self):
        for operation in self.read_operations():
            with self.subTest(operation=operation):
                operation()
        self.visible_author.assert_called_with(1, 2)
        self.assertEqual(self.user['favorite_team_id'], 83)

    def test_unfollowed_team_is_denied_at_every_read_boundary(self):
        self.followed.return_value = [83]
        for operation in self.read_operations():
            with self.subTest(operation=operation), self.assertRaises(HTTPException) as raised:
                operation()
            self.assertEqual(raised.exception.status_code, 403)

    def test_read_access_keeps_author_blocking_and_profile_restrictions(self):
        self.visible_author.side_effect = HTTPException(404, 'Content not found')
        with self.assertRaises(HTTPException) as raised:
            posts_repo.get_post(1, 91)
        self.assertEqual(raised.exception.status_code, 404)
        self.user['username'] = None
        for operation in self.read_operations():
            with self.subTest(operation=operation), self.assertRaises(HTTPException) as raised:
                operation()
            self.assertEqual(raised.exception.status_code, 403)

    def test_following_does_not_allow_posts_comments_likes_or_reports(self):
        transaction = self.patch(posts_repo, 'transaction')
        cursor = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
        cursor.fetchone.return_value = self.post
        self.patch(posts_repo, 'lock_user', return_value=self.user)
        operations = [
            lambda: posts_repo.create_post(1, 9, 'general', 'Title', 'Body', []),
            lambda: posts_repo.create_comment(1, 91, 'Comment', None),
            lambda: posts_repo.set_like(1, 'post', 91, True),
            lambda: posts_repo.set_like(1, 'comment', 3, True),
            lambda: posts_repo.report_content(1, 'post', 91, 'Spam'),
        ]
        for operation in operations:
            with self.subTest(operation=operation), self.assertRaises(HTTPException) as raised:
                operation()
            self.assertEqual(raised.exception.status_code, 403)
        self.assertTrue(all(call.args[0].lstrip().startswith('SELECT')
                            for call in cursor.execute.call_args_list))


if __name__ == '__main__':
    unittest.main()
