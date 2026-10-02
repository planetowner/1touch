"""게시·반응 저장과 같은 트랜잭션에서 한도 확인과 적립을 끝내요."""
from ..services.community_points import POINT_KINDS, QUALITY_INTERACTIONS, reward_amount, reward_day_bounds
from .points_repo import initialize_locked_wallet, apply_delta


def _award(cur, post, kind, actor_id, now):
    user_id, post_id = post['user_id'], post['post_id']
    request_id = f'{kind}:{post_id}' + (f':{actor_id}' if actor_id is not None else '')
    cur.execute('SELECT entry_id FROM user_point_entries WHERE user_id=%s AND request_id=%s', (user_id, request_id))
    if cur.fetchone() is not None:
        return
    wallet = initialize_locked_wallet(cur, user_id, now)
    start, end = reward_day_bounds(wallet['country_code'], now)
    cur.execute('''SELECT COALESCE(SUM(amount),0) AS earned,
        COALESCE(SUM(kind='community_post'),0) AS posts FROM user_point_entries
        WHERE user_id=%s AND created_at>=%s AND created_at<%s AND kind IN (%s,%s,%s,%s)''',
        (user_id, start, end, *POINT_KINDS))
    day = cur.fetchone()
    likes_before = 0
    if kind == 'community_like':
        cur.execute("SELECT COUNT(*) AS total FROM user_point_entries WHERE post_id=%s AND kind='community_like'", (post_id,))
        likes_before = cur.fetchone()['total']
    amount = reward_amount(kind, now=now, published_at=post['created_at'], earned_today=int(day['earned']),
                           posts_today=int(day['posts']), likes_before=likes_before)
    # 한도 때문에 0점을 지급한 반응도 기록해 다음 날 재등록으로 다시 적립하지 못하게 해요.
    apply_delta(cur, user_id, wallet, amount, now, kind=kind, request_id=request_id, post_id=post_id)


def reward_publication(cur, post, now):
    _award(cur, post, 'community_post', None, now)


def reward_interaction(cur, post, actor_id, kind, now):
    if post['user_id'] is None or post['user_id'] == actor_id:
        return
    _award(cur, post, kind, actor_id, now)
    # 좋아요의 적립 한도와 보너스 조건은 달라요. 21번째 이후 좋아요도 상호작용에 포함해요.
    # 답글도 댓글이고, 같은 작성자의 활성 댓글은 글마다 한 번만 세어요.
    cur.execute('''SELECT
        (SELECT COUNT(*) FROM post_likes WHERE post_id=%s AND user_id<>%s) +
        (SELECT COUNT(DISTINCT user_id) FROM post_comments
         WHERE post_id=%s AND user_id<>%s AND state='active') AS total''',
        (post['post_id'], post['user_id'], post['post_id'], post['user_id']))
    if cur.fetchone()['total'] >= QUALITY_INTERACTIONS:
        _award(cur, post, 'community_quality', None, now)
