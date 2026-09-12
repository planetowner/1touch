#!/usr/bin/env bash
set -euo pipefail
umask 077

transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$transfer_directory/prepare-service-settings.sh"
prepare_service_settings "$transfer_directory" configure_community.py community.env --from-env /input/community.env

# 권한 부여 대상은 사용자 확인을 마친 회원 ID예요. 다른 설정을 출력하지 않아요.
docker run --rm -i --network none --user 0:0 \
  -v "$runtime_directory:/settings:ro" -v "$transfer_directory:/input:ro" \
  --entrypoint python "$api_image" -X utf8 -B - <<'PY'
from dotenv import dotenv_values
selected = dotenv_values('/input/community.env', interpolate=False)
saved = dotenv_values('/settings/.env.production', interpolate=False)
if saved.get('COMMUNITY_ADMIN_USER_IDS') != selected['COMMUNITY_ADMIN_USER_IDS']:
    raise SystemExit('Community administrator settings were not saved correctly.')
print(f'Server community administrator IDs verified: {saved["COMMUNITY_ADMIN_USER_IDS"]}')
print('Saved settings checked only. The running API has not been restarted.')
PY

echo "Server settings backup retained: $transfer_directory/before.env.production"
