#!/usr/bin/env bash

# 서비스마다 입력 키만 달라요. 기존 API 이미지로 설정을 백업·저장하는 순서를 공유해요.
prepare_service_settings() {
    transfer_directory="$1"
    settings_program="$2"
    transfer_credentials="$transfer_directory/$3"
    shift 3
    runtime_directory=/opt/1touch/backend/deploy/vultr
    cd "$runtime_directory"

    trap 'rm -f -- "$transfer_credentials"' EXIT
    api_id=$(bash compose-production.sh ps -q api)
    [[ -n "$api_id" ]] || { echo 'Expected the existing API to be running.' >&2; exit 1; }
    api_image=$(docker inspect --format '{{.Config.Image}}' "$api_id")
    cp -- .env.production "$transfer_directory/before.env.production"

    # dotenv가 파일을 교체하므로 파일 하나가 아닌 설정 디렉터리를 마운트해요.
    docker run --rm --network none --user 0:0 \
      -v "$runtime_directory:/settings" -v "$transfer_directory:/input:ro" \
      --entrypoint python "$api_image" -X utf8 -B "/input/$settings_program" \
      --env-file /settings/.env.production "$@"
    chmod 600 .env.production
}

# 채널 설정은 입력한 값과 저장된 값이 같은지 확인해요. 공급자 로그인 시험과는 별개예요.
verify_saved_service_settings() {
    docker run --rm -i --network none --user 0:0 \
      -v "$runtime_directory:/settings:ro" -v "$transfer_directory:/input:ro" \
      --entrypoint python "$api_image" -X utf8 -B - "$1" <<'PY'
import sys
from dotenv import dotenv_values
service = sys.argv[1]
selected = dotenv_values(f'/input/{service}.env', interpolate=False)
saved = dotenv_values('/settings/.env.production', interpolate=False)
if not selected or any(saved.get(key) != value for key, value in selected.items()):
    raise SystemExit(f'{service} settings were not saved correctly.')
print(f'Server {service} settings verified: values={len(selected)}')
print('Saved settings checked only. Real social sign-in has not been tested.')
print('No database changes. The running API has not been restarted.')
PY
    echo "Server settings backup retained: $transfer_directory/before.env.production"
}
