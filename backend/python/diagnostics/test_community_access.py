import unittest

from fastapi import HTTPException

from one_touch_loader.api.services.community_access import require_favorite_team_access


class CommunityAccessTests(unittest.TestCase):
    def test_community_requires_its_team_to_be_the_home_favorite(self):
        require_favorite_team_access(6, (6,))
        with self.assertRaises(HTTPException) as raised:
            require_favorite_team_access(14, (6,))
        self.assertEqual(raised.exception.status_code, 403)

    def test_match_chat_accepts_either_participating_team(self):
        require_favorite_team_access(6, (6, 14))
        require_favorite_team_access(14, (6, 14))
        with self.assertRaises(HTTPException) as raised:
            require_favorite_team_access(503, (6, 14))
        self.assertEqual(raised.exception.status_code, 403)

    def test_missing_home_favorite_has_no_community_or_chat_access(self):
        for participants in ((6,), (6, 14)):
            with self.subTest(participants=participants):
                with self.assertRaises(HTTPException) as raised:
                    require_favorite_team_access(None, participants)
                self.assertEqual(raised.exception.status_code, 403)

    def test_updated_home_favorite_revokes_previous_team_access(self):
        require_favorite_team_access(6, (6,))
        require_favorite_team_access(6, (6, 14))
        for participants in ((6,), (6, 14)):
            with self.subTest(participants=participants):
                with self.assertRaises(HTTPException):
                    require_favorite_team_access(503, participants)
        require_favorite_team_access(503, (503,))


if __name__ == '__main__':
    unittest.main()
