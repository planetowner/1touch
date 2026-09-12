#!/usr/bin/env bash
set -euo pipefail
umask 077

transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$transfer_directory/prepare-service-settings.sh"
prepare_service_settings "$transfer_directory" configure_google.py google.env --from-env /input/google.env

# 저장된 허용 ID만 대조해요. 실제 앱 로그인 성공 여부는 ID 토큰을 받은 뒤 확인해야 해요.
docker run --rm -i --network none --user 0:0 \
  -v "$runtime_directory:/settings:ro" -v "$transfer_directory:/input:ro" \
  --entrypoint python "$api_image" -X utf8 -B - <<'PY'
from dotenv import dotenv_values
selected = dotenv_values('/input/google.env', interpolate=False)['GOOGLE_CLIENT_IDS'].split(',')
saved = dotenv_values('/settings/.env.production', interpolate=False)['GOOGLE_CLIENT_IDS'].split(',')
if not set(selected).issubset(saved):
    raise SystemExit('Google Client IDs were not saved correctly.')
print(f'Server Google Client IDs verified: provided={len(selected)} allowed={len(saved)}')
print('Saved settings checked only. Real Google sign-in has not been tested.')
print('No database changes. The running API has not been restarted.')
PY

echo "Server settings backup retained: $transfer_directory/before.env.production"
