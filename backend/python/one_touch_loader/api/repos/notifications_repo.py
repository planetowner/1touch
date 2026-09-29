"""알림 설정·커뮤니티 알림함·푸시 대기를 같은 사용자 권한으로 처리해요."""
from datetime import timedelta
import hashlib
import json

from fastapi import HTTPException

from ..db import fetch_all_dict, fetch_one_dict, transaction
from ..services.auth_security import token_hash
from ..services.community_periods import public_row, utc_now
from .users_repo import get_user, lock_user, require_profile
from ...core.db_json import decoded
from ...core.notifications import DEFAULTS, KINDS, NotificationEvent, fixture_events, state_event


def read_one(cur, sql, params=()):
    cur.execute(sql, params)
    return cur.fetchone()


def following(cur, user_id, scope):
    table, column = {'team': ('user_following_teams', 'team_id'),
                     'player': ('user_following_players', 'player_id')}[scope]
    cur.execute(f'SELECT {column} AS subject_id FROM {table} WHERE user_id=%s', (user_id,))
    return {r['subject_id'] for r in cur.fetchall()}


def settings(cur, user_id, scope, subject_id):
    row = read_one(cur, '''SELECT preferences FROM user_notification_preferences
        WHERE user_id=%s AND scope=%s AND subject_id=%s''', (user_id, scope, subject_id))
    return {**DEFAULTS[scope], **(decoded(row['preferences']) if row else {})}


def preference_snapshot(user_id):
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        result = {'community': settings(cur, user_id, 'community', 0)}
        for scope in ('team', 'player'):
            result[scope + 's'] = {str(i): settings(cur, user_id, scope, i) for i in sorted(following(cur, user_id, scope))}
        return result


def update_preferences(user_id, scope, values, subject_ids=None):
    if not values or set(values) - DEFAULTS[scope].keys():
        raise HTTPException(422, 'Unknown notification preference')
    if scope == 'community' and subject_ids is not None:
        raise HTTPException(422, 'Community preferences do not have subjects')
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, user_id)
        allowed = {0} if scope == 'community' else following(cur, user_id, scope)
        ids = allowed if subject_ids is None else set(subject_ids)
        if subject_ids is not None and len(ids) != len(subject_ids):
            raise HTTPException(422, 'Repeated subject ID')
        if not ids <= allowed:
            raise HTTPException(403, 'Notification preferences require following the subject')
        for subject_id in sorted(ids):
            value = {**settings(cur, user_id, scope, subject_id), **values}
            cur.execute('''INSERT INTO user_notification_preferences (user_id,scope,subject_id,preferences)
                VALUES (%s,%s,%s,%s) ON DUPLICATE KEY UPDATE preferences=VALUES(preferences)''',
                (user_id, scope, subject_id, json.dumps(value)))


def register_device(user_id, session_token, device_id, body):
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, user_id)
        digest = hashlib.sha256(body['token'].encode()).digest()
        session_hash = token_hash(session_token)
        previous = read_one(cur, 'SELECT user_id,session_token_hash FROM user_push_devices WHERE device_id=%s FOR UPDATE', (device_id,))
        # 다른 계정·세션으로 바뀔 때만 이전 발송 대기를 지워요. 같은 세션의 토큰 갱신은 유지해요.
        if previous and (previous['user_id'] != user_id or previous['session_token_hash'] != session_hash):
            cur.execute('DELETE FROM user_push_devices WHERE device_id=%s', (device_id,))
        cur.execute('DELETE FROM user_push_devices WHERE token_hash=%s AND device_id<>%s', (digest, device_id))
        cur.execute('''INSERT INTO user_push_devices
            (device_id,user_id,session_token_hash,token_hash,token,platform,locale) VALUES (%s,%s,%s,%s,%s,%s,%s)
            ON DUPLICATE KEY UPDATE token_hash=VALUES(token_hash),token=VALUES(token),platform=VALUES(platform),locale=VALUES(locale)''',
            (device_id, user_id, session_hash, digest, body['token'], body['platform'], body['locale']))


def unregister_device(user_id, device_id):
    with transaction() as conn, conn.cursor() as cur:
        cur.execute('DELETE FROM user_push_devices WHERE user_id=%s AND device_id=%s', (user_id, device_id))


def eligible_subjects(cur, user_id, kind, subjects):
    scope, setting = KINDS[kind]
    allowed = {0} if scope == 'community' else following(cur, user_id, scope)
    return tuple(i for i in subjects if i in allowed and settings(cur, user_id, scope, i)[setting])


def enqueue(cur, event: NotificationEvent, now, *, user_ids=None):
    if user_ids is None:
        table, column = {'team': ('user_following_teams', 'team_id'),
                         'player': ('user_following_players', 'player_id')}[event.scope]
        marks = ','.join('%s' for _ in event.subjects)
        cur.execute(f'SELECT DISTINCT user_id FROM {table} WHERE {column} IN ({marks})', event.subjects)
        user_ids = [r['user_id'] for r in cur.fetchall()]
    for user_id in sorted(set(user_ids)):
        subjects = eligible_subjects(cur, user_id, event.kind, event.subjects)
        if not subjects:
            continue
        cur.execute('''INSERT INTO user_notifications
            (user_id,event_key,kind,scope,subject_ids,payload,fixture_id,post_id,comment_id,actor_id,created_at,expires_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON DUPLICATE KEY UPDATE notification_id=notification_id''',
            (user_id, event.key, event.kind, event.scope, json.dumps(subjects), json.dumps(event.payload),
             event.fixture_id, event.post_id, event.comment_id, event.actor_id, now, event.expires_at))
        if cur.rowcount != 1:
            continue
        notification_id = cur.lastrowid
        # 로그아웃은 세션 FK로 기기와 발송 대기를 삭제해요. 만료된 세션도 대상에서 제외해요.
        cur.execute('''INSERT INTO notification_push_deliveries (notification_id,device_id,next_attempt_at)
            SELECT %s,d.device_id,%s FROM user_push_devices d JOIN user_sessions s
            ON s.token_hash=d.session_token_hash WHERE d.user_id=%s AND s.expires_at>%s''',
            (notification_id, now, user_id, now))


def notify_post(cur, post, actor_id, *, comment_id=None):
    owner = post['user_id']
    if owner is None or owner == actor_id:
        return
    if read_one(cur, 'SELECT 1 FROM user_blocks WHERE user_id=%s AND blocked_user_id=%s', (owner, actor_id)):
        return
    kind = 'post_comment' if comment_id is not None else 'post_reaction'
    key = f'comment:{comment_id}' if comment_id is not None else f"post:{post['post_id']}:like:{actor_id}"
    now = utc_now()
    enqueue(cur, NotificationEvent(key, kind, (0,), {'destination': f"/notifications/post/{post['post_id']}"},
                                  now + timedelta(days=1), post_id=post['post_id'], comment_id=comment_id,
                                  actor_id=actor_id), now, user_ids=[owner])


# 목록·읽지 않은 개수·푸시 모두 같은 공개 조건을 써요. 삭제·차단 후 원문이 새지 않아요.
COMMUNITY_FROM = '''FROM user_notifications n JOIN posts p ON p.post_id=n.post_id
    JOIN users actor ON actor.user_id=n.actor_id JOIN users owner ON owner.user_id=n.user_id
    LEFT JOIN post_comments c ON c.comment_id=n.comment_id'''
COMMUNITY_VISIBLE = '''n.scope='community' AND n.cancelled_at IS NULL AND p.state='active'
    AND p.user_id=n.user_id AND owner.favorite_team_id IS NOT NULL
    AND (owner.favorite_team_id=p.team_id OR EXISTS(SELECT 1 FROM user_following_teams f
        WHERE f.user_id=n.user_id AND f.team_id=p.team_id))
    AND NOT EXISTS(SELECT 1 FROM user_blocks b WHERE b.user_id=n.user_id AND b.blocked_user_id=n.actor_id)
    AND ((n.kind='post_comment' AND c.state='active') OR (n.kind='post_reaction' AND EXISTS(
        SELECT 1 FROM post_likes l WHERE l.post_id=n.post_id AND l.user_id=n.actor_id)))'''
COMMUNITY_FIELDS = '''n.notification_id,n.kind,n.post_id,n.comment_id,n.actor_id,n.created_at,n.read_at,
    p.team_id,actor.username,LEFT(c.body,60) AS comment_preview'''


def list_community(user_id, *, before_id=None, limit=30, team_id=None):
    require_profile(get_user(user_id))
    where, params = 'n.user_id=%s AND ' + COMMUNITY_VISIBLE, [user_id]
    if team_id is not None:
        where += ' AND p.team_id=%s'
        params.append(team_id)
    count = fetch_one_dict(f'SELECT COUNT(*) AS total {COMMUNITY_FROM} WHERE {where} AND n.read_at IS NULL', tuple(params))
    if before_id is not None:
        where += ' AND n.notification_id<%s'
        params.append(before_id)
    rows = fetch_all_dict(f'SELECT {COMMUNITY_FIELDS} {COMMUNITY_FROM} WHERE {where} '
                          'ORDER BY n.notification_id DESC LIMIT %s', (*params, limit + 1))
    items = [{**public_row(row), 'destination': f"/notifications/post/{row['post_id']}"} for row in rows[:limit]]
    return {'items': items, 'unread_count': count['total'],
            'next_before_id': items[-1]['notification_id'] if len(rows) > limit else None}


def mark_read(user_id, through_id):
    with transaction() as conn, conn.cursor() as cur:
        cur.execute("""UPDATE user_notifications SET read_at=COALESCE(read_at,%s)
            WHERE user_id=%s AND scope='community' AND notification_id<=%s""", (utc_now(), user_id, through_id))


def capture_fixture(connection, fixture, sampled_at):
    with connection.cursor(dictionary=True) as cur:
        # 선발 수집과 라이브 수집이 같은 경기를 갱신할 때 마지막 관측 순서를 지켜요.
        read_one(cur, 'SELECT fixture_id FROM fixtures WHERE fixture_id=%s FOR UPDATE', (fixture['id'],))
        previous = read_one(cur, 'SELECT * FROM notification_fixture_state WHERE fixture_id=%s', (fixture['id'],))
        if previous and previous['sampled_at'] >= sampled_at:
            return False
        candidates = fixture_events(fixture, sampled_at)
        keys = {e.key for e in candidates}
        seen = set(decoded(previous['seen_keys'])) if previous else set()
        # 처음 켰을 때 진행 중 경기의 지난 골을 모두 보내지 않아요. 경기 전 확정 선발은 바로 알려요.
        if previous is not None or fixture['state_id'] in (1, 16):
            for event in candidates:
                if event.key not in seen:
                    enqueue(cur, event, sampled_at)
        if previous is not None:
            phase = state_event(fixture, previous['state_id'], sampled_at)
            if phase is not None and phase.key not in seen:
                enqueue(cur, phase, sampled_at)
                seen.add(phase.key)
            # VAR 취소·카드 철회·선발 변경은 아직 발송하지 않은 알림도 취소해요.
            removed = set(decoded(previous['current_keys'])) - keys
            for key in removed:
                cur.execute('UPDATE user_notifications SET cancelled_at=%s WHERE fixture_id=%s AND event_key=%s',
                            (sampled_at, fixture['id'], key))
        cur.execute('''INSERT INTO notification_fixture_state (fixture_id,state_id,seen_keys,current_keys,sampled_at)
            VALUES (%s,%s,%s,%s,%s) ON DUPLICATE KEY UPDATE state_id=VALUES(state_id),seen_keys=VALUES(seen_keys),
            current_keys=VALUES(current_keys),sampled_at=VALUES(sampled_at)''',
            (fixture['id'], fixture['state_id'], json.dumps(sorted(seen | keys)), json.dumps(sorted(keys)), sampled_at))
        return True


def push_data(cur, row, now):
    if row['cancelled_at'] is not None or row['expires_at'] <= now:
        return None
    if not eligible_subjects(cur, row['user_id'], row['kind'], decoded(row['subject_ids'])):
        return None
    data = decoded(row['payload'])
    if row['scope'] == 'community':
        try:
            require_profile(read_one(cur, 'SELECT * FROM users WHERE user_id=%s', (row['user_id'],)))
        except HTTPException:
            return None
        community = read_one(cur, f'SELECT {COMMUNITY_FIELDS} {COMMUNITY_FROM} WHERE n.notification_id=%s AND {COMMUNITY_VISIBLE}',
                             (row['notification_id'],))
        if community is None:
            return None
        return {**data, 'username': community['username'], 'comment_preview': community['comment_preview'] or ''}
    if row['kind'] in ('team_new_bets', 'team_match_reminder'):
        fixture = read_one(cur, 'SELECT starting_at,state_id FROM fixtures WHERE fixture_id=%s', (row['fixture_id'],))
        if (fixture is None or fixture['state_id'] not in (1, 16) or fixture['starting_at'] is None
                or fixture['starting_at'] <= now or fixture['starting_at'].isoformat() != data['starting_at']):
            return None
    return data
