"""국가별 자정·서머타임·적립 한도·7일 경계를 검증해요."""
from datetime import datetime, timedelta
import unittest

from one_touch_loader.api.services.community_points import reward_amount, reward_day_bounds, reward_timezone


class CommunityPointRuleTests(unittest.TestCase):
    now = datetime(2026, 10, 2, 12)

    def amount(self, kind, **changes):
        return reward_amount(kind, **{'now': self.now, 'published_at': self.now,
            'earned_today': 0, 'posts_today': 0, 'likes_before': 0, **changes})

    def test_example_totals_430_points(self):
        self.assertEqual(2 * self.amount('community_post') + 15 * self.amount('community_like')
                         + 8 * self.amount('community_comment'), 430)

    def test_post_and_like_count_limits(self):
        self.assertEqual(self.amount('community_post', posts_today=2), 100)
        self.assertEqual(self.amount('community_post', posts_today=3), 0)
        self.assertEqual(self.amount('community_like', likes_before=19), 10)
        self.assertEqual(self.amount('community_like', likes_before=20), 0)

    def test_all_rewards_obey_remaining_daily_limit(self):
        for kind in ('community_post', 'community_like', 'community_comment', 'community_quality'):
            with self.subTest(kind=kind):
                self.assertEqual(self.amount(kind, earned_today=995), 5)
                self.assertEqual(self.amount(kind, earned_today=1000), 0)

    def test_age_discount_starts_at_exactly_seven_days(self):
        for kind, full in (('community_like', 10), ('community_comment', 10), ('community_quality', 200)):
            with self.subTest(kind=kind):
                self.assertEqual(self.amount(kind, published_at=self.now - timedelta(days=7) + timedelta(microseconds=1)), full)
                self.assertEqual(self.amount(kind, published_at=self.now - timedelta(days=7)), full // 2)
        self.assertEqual(self.amount('community_post', published_at=self.now - timedelta(days=8)), 100)

    def test_country_mapping_and_midnight(self):
        for country, zone, midnight in (
                ('KR', 'Asia/Seoul', datetime(2026, 10, 1, 15)),
                ('JP', 'Asia/Tokyo', datetime(2026, 10, 1, 15)),
                ('CN', 'Asia/Shanghai', datetime(2026, 10, 1, 16)),
                ('US', 'America/New_York', datetime(2026, 10, 2, 4)),
                ('GB', 'America/New_York', datetime(2026, 10, 2, 4))):
            with self.subTest(country=country):
                self.assertEqual(reward_timezone(country), zone)
                self.assertEqual(reward_day_bounds(country, self.now), (midnight, midnight + timedelta(days=1)))
                self.assertEqual(reward_day_bounds(country, midnight)[0], midnight)
                self.assertEqual(reward_day_bounds(country, midnight - timedelta(microseconds=1))[1], midnight)

    def test_new_york_dst_days_are_not_fixed_24_hours(self):
        self.assertEqual(reward_day_bounds('US', datetime(2026, 3, 8, 12)),
                         (datetime(2026, 3, 8, 5), datetime(2026, 3, 9, 4)))
        self.assertEqual(reward_day_bounds('US', datetime(2026, 11, 1, 12)),
                         (datetime(2026, 11, 1, 4), datetime(2026, 11, 2, 5)))


if __name__ == '__main__':
    unittest.main()
