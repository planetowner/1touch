#!/usr/bin/env bash
set -euo pipefail
umask 077

transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$transfer_directory/prepare-service-settings.sh"
prepare_service_settings "$transfer_directory" configure_kakao.py kakao.env --from-env /input/kakao.env

# 설정 저장만 확인해요. 실제 로그인 검증에는 앱에서 받은 사용자 토큰이 필요해요.
docker run --rm -i --network none --user 0:0 \
  -v "$runtime_directory:/settings:ro" -v "$transfer_directory:/input:ro" \
  --entrypoint python "$api_image" -X utf8 -B - <<'PY'
from dotenv import dotenv_values
selected = dotenv_values('/input/kakao.env', interpolate=False)
saved = dotenv_values('/settings/.env.production', interpolate=False)
if any(saved.get(key) != value for key, value in selected.items()):
    raise SystemExit('Kakao settings were not saved correctly.')
print(f'Server Kakao App ID verified: app_id={saved["KAKAO_APP_ID"]}')
print(f'Webhook audience key configured: {bool(saved.get("KAKAO_REST_API_KEY"))}')
print('Saved settings checked only. Real Kakao sign-in has not been tested.')
print('No database changes. The running API has not been restarted.')
PY

echo "Server settings backup retained: $transfer_directory/before.env.production"
