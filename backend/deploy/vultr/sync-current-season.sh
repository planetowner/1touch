#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# 실측한 모든 시즌 갱신 작업에 기존 공통 배치 설정으로 같은 상한을 적용해요.
export ONETOUCH_BATCH_MEMORY_LIMIT=512m
# Lightsail에서도 기존 운영 Compose 설정과 같은 DB·API 설정을 사용해요.
exec bash compose-production.sh -f compose.batch-resources.yaml run --rm --no-deps -T api \
  python -u -m one_touch_loader.cli current-season "$@"
