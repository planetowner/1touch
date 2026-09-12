#!/usr/bin/env bash
set -euo pipefail
umask 077

transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$transfer_directory/prepare-service-settings.sh"
prepare_service_settings "$transfer_directory" configure_ses.py ses.env --from-env /input/ses.env

# 기존 공통 전송·백업 절차를 쓰고, 저장한 주소만 확인해요. 시험 메일은 보내지 않아요.
docker run --rm -i --network none --user 0:0 \
  -v "$runtime_directory:/settings:ro" -v "$transfer_directory:/input:ro" \
  --entrypoint python "$api_image" -X utf8 -B - <<'PY'
from dotenv import dotenv_values
selected = dotenv_values('/input/ses.env', interpolate=False)
saved = dotenv_values('/settings/.env.production', interpolate=False)
if saved.get('SES_FEEDBACK_EMAIL') != selected['SES_FEEDBACK_EMAIL']:
    raise SystemExit('SES feedback setting was not saved correctly.')
print('Server SES feedback address verified. No email sent or database changed.')
print('The running API has not been restarted.')
PY

echo "Server settings backup retained: $transfer_directory/before.env.production"
