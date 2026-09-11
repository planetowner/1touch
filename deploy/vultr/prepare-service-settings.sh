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
