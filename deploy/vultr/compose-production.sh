#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# 상태 조회, 배포, 재시작이 같은 운영 설정과 DB 볼륨을 사용해요.
exec docker compose --env-file .env --env-file "${ONETOUCH_PRODUCTION_ENV:-.env.production}" \
  -f compose.yaml -f compose.production.yaml "$@"
