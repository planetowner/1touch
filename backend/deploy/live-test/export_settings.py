"""인증·푸시에 필요한 설정만 읽고 테스트 DB 암호는 새로 만들어요."""
import os
import secrets

SHARED = (
    'SPORTMONKS_API_TOKEN', 'SES_SMTP_HOST', 'SES_SMTP_USERNAME', 'SES_SMTP_PASSWORD',
    'SES_FROM_EMAIL', 'SES_FEEDBACK_EMAIL', 'GOOGLE_CLIENT_IDS', 'APPLE_CLIENT_IDS',
    'APPLE_TEAM_ID', 'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY', 'KAKAO_APP_ID',
    'KAKAO_REST_API_KEY', 'LINE_CHANNEL_ID', 'LINE_CHANNEL_SECRET',
    'FCM_PROJECT_ID', 'FCM_CLIENT_EMAIL', 'FCM_PRIVATE_KEY',
)


def settings():
    values = {key: os.environ[key] for key in SHARED if os.environ.get(key)}
    required = ('SPORTMONKS_API_TOKEN', 'FCM_PROJECT_ID', 'FCM_CLIENT_EMAIL', 'FCM_PRIVATE_KEY')
    missing = [key for key in required if not values.get(key)]
    if missing:
        raise RuntimeError('Missing test prerequisites: ' + ', '.join(missing))
    values.update(AUTH_CODE_SECRET=secrets.token_hex(32),
                  LIVE_TEST_MYSQL_PASSWORD=secrets.token_hex(32),
                  LIVE_TEST_MYSQL_ROOT_PASSWORD=secrets.token_hex(32))
    return values


if __name__ == '__main__':
    # 작은따옴표는 Compose의 달러 보간을 막아요. 실제 개행은 env 파일에서 지원해요.
    for key, value in settings().items():
        if "'" in value:
            raise ValueError(f'Unsupported quote in setting: {key}')
        print(f"{key}='{value}'")
