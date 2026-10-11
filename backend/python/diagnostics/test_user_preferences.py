from datetime import datetime, timedelta, timezone
import unittest
from unittest.mock import Mock

from one_touch_loader.api.services.user_preferences import (
    favorite_changed_at_after_update,
    validate_team_selection,
)
from one_touch_loader.api.services.profile_changes import (
    ProfileChangeLimitError, check_change_limit,
)


class TeamSelectionTests(unittest.TestCase):
    leagues = {6: 8, 14: 8, 503: 82, 591: 301, 109: 384, 83: 564}

    def test_one_team_and_one_from_each_league_are_allowed(self):
        validate_team_selection([6], 6, self.leagues)
        validate_team_selection([6, 503, 591, 109, 83], 83, self.leagues)

    def test_empty_selection_and_missing_home_team_are_rejected(self):
        with self.assertRaises(ValueError):
            validate_team_selection([], 6, self.leagues)
        with self.assertRaises(ValueError):
            validate_team_selection([6, 503], 83, self.leagues)

    def test_same_league_and_repeated_team_are_rejected(self):
        with self.assertRaises(ValueError):
            validate_team_selection([6, 14], 6, self.leagues)
        with self.assertRaises(ValueError):
            validate_team_selection([6, 6], 6, self.leagues)

    def test_team_outside_current_league_candidates_is_rejected(self):
        with self.assertRaises(ValueError):
            validate_team_selection([6, 999], 6, self.leagues)


class FavoriteTeamChangeTests(unittest.TestCase):
    now = datetime(2026, 9, 10, 12, tzinfo=timezone.utc)

    def test_initial_selection_does_not_use_first_change(self):
        self.assertIsNone(favorite_changed_at_after_update(None, None, 6, self.now))
        self.assertEqual(favorite_changed_at_after_update(6, None, 503, self.now), self.now)

    def test_two_changes_are_allowed_then_oldest_expires_after_14_days(self):
        for change_type in ("display_name", "favorite_team"):
            with self.subTest(change_type=change_type):
                cursor = Mock()
                for recent in ([], [{"changed_at": self.now}]):
                    cursor.fetchall.return_value = recent
                    check_change_limit(cursor, 7, change_type, self.now + timedelta(days=1))
                cursor.fetchall.return_value = [{"changed_at": self.now + timedelta(days=1)},
                                                {"changed_at": self.now}]
                with self.assertRaises(ProfileChangeLimitError) as raised:
                    check_change_limit(cursor, 7, change_type, self.now + timedelta(days=13))
                self.assertEqual(raised.exception.available_at, self.now + timedelta(days=14))
                self.assertEqual(cursor.execute.call_args.args[1][1], change_type)
                cursor.fetchall.return_value = [{"changed_at": self.now + timedelta(days=1)}]
                check_change_limit(cursor, 7, change_type, self.now + timedelta(days=14))

    def test_only_selected_users_can_keep_changing_favorite_team_at_the_limit(self):
        for user_id in range(1, 16):
            with self.subTest(user_id=user_id):
                cursor = Mock()
                cursor.fetchall.return_value = [{"changed_at": self.now}, {"changed_at": self.now}]
                if user_id in (1, 3, 12, 13):
                    for _ in range(10):
                        check_change_limit(cursor, user_id, "favorite_team", self.now)
                else:
                    with self.assertRaises(ProfileChangeLimitError):
                        check_change_limit(cursor, user_id, "favorite_team", self.now)

    def test_favorite_team_exempt_users_still_have_display_name_limit(self):
        for user_id in (1, 3, 12, 13):
            with self.subTest(user_id=user_id):
                cursor = Mock()
                cursor.fetchall.return_value = [{"changed_at": self.now}, {"changed_at": self.now}]
                with self.assertRaises(ProfileChangeLimitError):
                    check_change_limit(cursor, user_id, "display_name", self.now)

    def test_same_home_team_does_not_consume_or_extend_change_interval(self):
        self.assertIsNone(favorite_changed_at_after_update(6, None, 6, self.now))
        self.assertEqual(
            favorite_changed_at_after_update(503, self.now, 503, self.now + timedelta(days=1)),
            self.now,
        )


if __name__ == '__main__':
    unittest.main()
