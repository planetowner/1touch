#!/usr/bin/env bash
set -euo pipefail
umask 077

transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_directory=/opt/1touch/backend/deploy/vultr
cd "$runtime_directory"

# 전송한 키는 이번 준비 단계가 끝나면 지워요. 원본은 사용자 PC에 남아요.
trap 'rm -f -- "$transfer_directory/smtp.csv"' EXIT
api_id=$(bash compose-production.sh ps -q api)
[[ -n "$api_id" ]] || { echo 'Expected the existing API to be running before migration.' >&2; exit 1; }
api_image=$(docker inspect --format '{{.Config.Image}}' "$api_id")
cp -- .env.production "$transfer_directory/before.env.production"

# 로컬과 같은 설정 함수를 사용해요. 호스트에 패키지를 추가하지 않고 기존 API 이미지를 사용해요.
# 파일 하나를 마운트하면 dotenv의 원자적 교체가 실패하므로 설정 디렉터리를 마운트해요.
docker run --rm --network none --user 0:0 \
  -v "$runtime_directory:/settings" -v "$transfer_directory:/input:ro" \
  --entrypoint python "$api_image" -X utf8 -B /input/configure_ses.py \
  --credentials-csv /input/smtp.csv --env-file /settings/.env.production \
  --from-email noreply@auth.1touch.football
chmod 600 .env.production

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
