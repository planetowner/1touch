"""기존 JWT·HTTP 라이브러리로 FCM HTTP v1 알림을 보내요."""
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import os
import re
import time

import jwt
import requests

from ...core.notifications import KINDS, message

TOKEN_URL = 'https://oauth2.googleapis.com/token'


class PushError(Exception):
    def __init__(self, code, *, retryable=False, retry_after=60):
        self.code, self.retryable, self.retry_after = code, retryable, retry_after
        super().__init__(code)


def retry_delay(value, now):
    if value is None:
        return 60
    if value.isdigit():
        return max(60, int(value))
    try:
        return max(60, int((parsedate_to_datetime(value) - now).total_seconds()))
    except (TypeError, ValueError):
        return 60


def fcm_message(row, token, locale, data, now):
    scope = KINDS[row['kind']][0]
    ttl = max(0, int((row['expires_at'] - now).total_seconds()))
    notification_id = str(row['notification_id'])
    content = message(row['kind'], data, locale)
    return {'token': token, 'notification': content,
            'data': {'notification_id': notification_id, 'kind': row['kind'], 'destination': data['destination']},
            'android': {'priority': 'HIGH', 'ttl': f'{ttl}s', 'notification': {
                'visibility': 'PRIVATE', 'tag': notification_id, 'sound': 'default',
                'channel_id': {'community': 'post_updates', 'team': 'team_updates', 'player': 'player_updates'}[scope],
                'icon': 'ic_stat_onetouch'}},
            # iOS의 미리보기 표시 여부는 사용자의 시스템 설정을 따라요. 카테고리는 앱에서 등록해요.
            'apns': {'headers': {'apns-push-type': 'alert', 'apns-priority': '10',
                                 'apns-collapse-id': notification_id,
                                 'apns-expiration': str(int(row['expires_at'].replace(tzinfo=timezone.utc).timestamp()))},
                     'payload': {'aps': {'alert': content, 'sound': 'default',
                                         'category': 'ONETOUCH_PRIVATE', 'thread-id': scope}}}}


class PushSender:
    def __init__(self):
        self.project = os.getenv('FCM_PROJECT_ID', '')
        self.email = os.getenv('FCM_CLIENT_EMAIL', '')
        self.key = os.getenv('FCM_PRIVATE_KEY', '').replace('\\n', '\n')
        if not re.fullmatch(r'[a-z][a-z0-9-]{4,62}', self.project) or not self.email or not self.key:
            raise PushError('fcm_not_configured')
        self.session = requests.Session()
        self.access_token = None
        self.expires = 0

    def close(self):
        self.session.close()

    def _access_token(self):
        if self.access_token is not None and time.time() < self.expires:
            return self.access_token
        now = int(time.time())
        try:
            assertion = jwt.encode({'iss': self.email, 'scope': 'https://www.googleapis.com/auth/firebase.messaging',
                                    'aud': TOKEN_URL, 'iat': now, 'exp': now + 3600}, self.key, algorithm='RS256')
        except (ValueError, jwt.PyJWTError) as error:
            raise PushError('fcm_invalid_credentials') from error
        try:
            response = self.session.post(TOKEN_URL, data={
                'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion': assertion}, timeout=10)
        except requests.RequestException as error:
            raise PushError('fcm_auth_unavailable') from error
        if response.status_code != 200:
            raise PushError('fcm_auth_failed')
        body = response.json()
        self.access_token = body['access_token']
        self.expires = now + int(body['expires_in']) - 60
        return self.access_token

    def send(self, row, token, locale, data, now):
        headers = {'Authorization': 'Bearer ' + self._access_token()}
        try:
            response = self.session.post(f'https://fcm.googleapis.com/v1/projects/{self.project}/messages:send',
                                         headers=headers, json={'message': fcm_message(row, token, locale, data, now)}, timeout=10)
        except requests.RequestException as error:
            raise PushError('fcm_unavailable', retryable=True) from error
        if response.status_code == 200:
            return
        if response.status_code in (401, 403):
            # 프로젝트·APNs 인증 오류를 기기 토큰 만료로 오인해 삭제하지 않아요.
            raise PushError('fcm_permission_denied')
        try:
            details = response.json().get('error', {}).get('details', [])
        except ValueError:
            details = []
        if any(d.get('@type') == 'type.googleapis.com/google.firebase.fcm.v1.FcmError'
               and d.get('errorCode') == 'UNREGISTERED' for d in details):
            raise PushError('fcm_unregistered')
        if response.status_code == 429 or response.status_code >= 500:
            raise PushError('fcm_unavailable', retryable=True,
                            retry_after=retry_delay(response.headers.get('Retry-After'), datetime.now(timezone.utc)))
        # 공급자 원문에는 토큰이 포함될 수 있어 알려진 오류 코드만 기록해요.
        raise PushError('fcm_invalid_message')
