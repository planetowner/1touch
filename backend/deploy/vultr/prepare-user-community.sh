#!/usr/bin/env bash
set -euo pipefail
umask 077

transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$transfer_directory/prepare-service-settings.sh"
prepare_service_settings "$transfer_directory" configure_ses.py smtp.csv \
  --credentials-csv /input/smtp.csv \
  --from-email noreply@auth.1touch.football

# 실제 서버에서도 TLS·SMTP 인증까지만 검사해요. 테스트 메일이나 회원 데이터는 만들지 않아요.
docker run --rm -i --user 0:0 -v "$runtime_directory:/settings:ro" \
  --entrypoint python "$api_image" -X utf8 -B - <<'PY'
import smtplib, ssl
from dotenv import dotenv_values
settings = dotenv_values('/settings/.env.production', interpolate=False)
try:
    with smtplib.SMTP(settings['SES_SMTP_HOST'], 587, timeout=15) as client:
        client.ehlo()
        client.starttls(context=ssl.create_default_context())
        client.ehlo()
        client.login(settings['SES_SMTP_USERNAME'], settings['SES_SMTP_PASSWORD'])
except (smtplib.SMTPException, OSError) as exc:
    raise SystemExit(f'SES authentication failed: {type(exc).__name__}') from None
print('Server SES TLS and SMTP authentication verified. No email sent.')
PY

# 예전 GET 요청도 사용자 행을 만들 수 있어, 빈 테이블 재검증·마이그레이션 전에 멈춰요.
bash compose-production.sh stop api
echo 'SMTP settings prepared and old API stopped. Continue with the backed-up migration.'
