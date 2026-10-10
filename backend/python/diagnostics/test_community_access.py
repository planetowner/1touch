import unittest

from fastapi import HTTPException

from one_touch_loader.api.services.community_access import (
    require_favorite_team_access, require_community_read_access, require_followed_team_access,
)


class CommunityAccessTests(unittest.TestCase):
    def test_community_participation_requires_its_team_to_be_the_home_favorite(self):
        require_favorite_team_access(6, (6,))
        with self.assertRaises(HTTPException) as raised:
            require_favorite_team_access(14, (6,))
        self.assertEqual(raised.exception.status_code, 403)

    def test_followed_teams_can_be_read_but_do_not_grant_write_access(self):
        require_community_read_access(6, [6, 503], 503)
        require_community_read_access(6, [6, 503], 6)
        for favorite, followed, team in [(6, [6, 503], 14), (None, [503], 503)]:
            with self.subTest(team=team), self.assertRaises(HTTPException) as raised:
                require_community_read_access(favorite, followed, team)
            self.assertEqual(raised.exception.status_code, 403)
        with self.assertRaises(HTTPException):
            require_favorite_team_access(6, (503,))

    def test_unfollowing_revokes_read_access_without_changing_the_favorite(self):
        require_community_read_access(6, [6, 503], 503)
        with self.assertRaises(HTTPException):
            require_community_read_access(6, [6], 503)

    def test_match_chat_accepts_any_followed_participating_team(self):
        for followed in ([6], [14], [503, 591, 1000, 2000, 6]):
            with self.subTest(followed=followed):
                require_followed_team_access(followed, (6, 14))
        for followed in ([], [503, 591]):
            with self.subTest(followed=followed), self.assertRaises(HTTPException) as raised:
                require_followed_team_access(followed, (6, 14))
            self.assertEqual(raised.exception.status_code, 403)

    def test_missing_home_favorite_has_no_community_participation_access(self):
        with self.assertRaises(HTTPException) as raised:
            require_favorite_team_access(None, (6,))
        self.assertEqual(raised.exception.status_code, 403)

    def test_updated_home_favorite_only_revokes_community_participation(self):
        require_favorite_team_access(6, (6,))
        with self.assertRaises(HTTPException):
            require_favorite_team_access(503, (6,))
        require_favorite_team_access(503, (503,))
        require_followed_team_access([503, 6], (6, 14))


if __name__ == '__main__':
    unittest.main()
