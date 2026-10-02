"""커뮤니티 적립 금액과 작성자 국가별 하루 경계를 한곳에서 정해요."""
from datetime import datetime, timedelta

from .community_periods import PostPeriod, period_bounds

POST_POINTS = 100
POSTS_PER_DAY = 3
INTERACTION_POINTS = 10
LIKES_PER_POST = 20
QUALITY_POINTS = 200
QUALITY_INTERACTIONS = 25
DAILY_POINTS = 1000
OLD_POST_AGE = timedelta(days=7)
POINT_KINDS = ('community_post', 'community_like', 'community_comment', 'community_quality')


def reward_timezone(country_code: str | None) -> str:
    return {'KR': 'Asia/Seoul', 'JP': 'Asia/Tokyo', 'CN': 'Asia/Shanghai'}.get(
        country_code, 'America/New_York')


def reward_day_bounds(country_code: str | None, now: datetime) -> tuple[datetime, datetime]:
    # 뉴욕의 하루는 서머타임 전환일에 23시간 또는 25시간일 수 있어요.
    return period_bounds(PostPeriod.today, reward_timezone(country_code), now)


def reward_amount(kind: str, *, now: datetime, published_at: datetime,
                  earned_today: int, posts_today: int, likes_before: int) -> int:
    amount = {'community_post': POST_POINTS, 'community_like': INTERACTION_POINTS,
              'community_comment': INTERACTION_POINTS, 'community_quality': QUALITY_POINTS}[kind]
    if kind == 'community_post' and posts_today >= POSTS_PER_DAY:
        return 0
    if kind == 'community_like' and likes_before >= LIKES_PER_POST:
        return 0
    if kind != 'community_post' and now >= published_at + OLD_POST_AGE:
        amount //= 2
    # 남은 일일 한도까지만 지급하고 초과분은 다음 날로 넘기지 않아요.
    return min(amount, max(0, DAILY_POINTS - earned_today))
