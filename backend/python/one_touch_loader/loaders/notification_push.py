"""기기별 발송 결과를 남기고 일시적인 전송 실패만 다시 시도해요."""
from datetime import datetime, timedelta
import math

from ..api.db import fetch_one_dict, fetch_one_from_cursor, transaction
from ..api.repos.notifications_repo import push_data
from ..api.services.community_periods import utc_now
from ..api.services.push_sender import PushError, PushSender


def dispatch(*, apply=False, limit=100, sender=None):
    if not apply:
        row = fetch_one_dict("SELECT COUNT(*) AS total FROM notification_push_deliveries WHERE status='pending' AND next_attempt_at<=%s", (utc_now(),))
        return {'apply': False, 'pending': row['total']}
    # 설정이 없으면 대기 행을 바꾸기 전에 중단해요.
    owned = sender is None
    sender = sender or PushSender()
    counts = {'sent': 0, 'skipped': 0, 'failed': 0, 'retry': 0}
    try:
        for _ in range(limit):
            with transaction() as conn, conn.cursor(dictionary=True) as cur:
                now = utc_now()
                delivery = fetch_one_from_cursor(cur, '''SELECT notification_id,device_id,attempts FROM notification_push_deliveries
                    WHERE status='pending' AND next_attempt_at<=%s ORDER BY next_attempt_at,notification_id
                    LIMIT 1 FOR UPDATE SKIP LOCKED''', (now,))
                if delivery is None:
                    break
                row = fetch_one_from_cursor(cur, 'SELECT * FROM user_notifications WHERE notification_id=%s', (delivery['notification_id'],))
                device = fetch_one_from_cursor(cur, '''SELECT d.*,s.expires_at AS session_expires_at FROM user_push_devices d
                    JOIN user_sessions s ON s.token_hash=d.session_token_hash WHERE d.device_id=%s FOR UPDATE''', (delivery['device_id'],))
                data = push_data(cur, row, now) if row and device and device['user_id'] == row['user_id'] and device['session_expires_at'] > now else None
                status, code, next_try = 'skipped', None, now
                if data is not None:
                    if row['kind'] == 'team_match_reminder':
                        data['minutes_until_kickoff'] = math.ceil((datetime.fromisoformat(data['starting_at']) - now).total_seconds() / 60)
                    try:
                        sender.send(row, device['token'], device['locale'], data, now)
                        status = 'sent'
                    except PushError as error:
                        if error.code in ('fcm_not_configured', 'fcm_invalid_credentials', 'fcm_auth_unavailable',
                                          'fcm_auth_failed', 'fcm_permission_denied'):
                            raise
                        if error.code == 'fcm_unregistered':
                            cur.execute('DELETE FROM user_push_devices WHERE device_id=%s', (delivery['device_id'],))
                            counts['skipped'] += 1
                            continue
                        code = error.code
                        status = 'pending' if error.retryable and delivery['attempts'] < 4 else 'failed'
                        next_try = now + timedelta(seconds=max(error.retry_after, 60 * 2 ** delivery['attempts']))
                cur.execute('''UPDATE notification_push_deliveries SET status=%s,attempts=attempts+%s,
                    next_attempt_at=%s,last_error=%s WHERE notification_id=%s AND device_id=%s''',
                    (status, int(data is not None), next_try, code, delivery['notification_id'], delivery['device_id']))
                counts['retry' if status == 'pending' else status] += 1
    finally:
        if owned:
            sender.close()
    return {'apply': True, **counts}
