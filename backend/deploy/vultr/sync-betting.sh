#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# 대상 조회와 격리 정산으로 실측한 상한을 공통 설정에 전달해요.
export ONETOUCH_BATCH_MEMORY_LIMIT=512m
exec bash compose-production.sh -f compose.batch-resources.yaml run --rm --no-deps -T api \
  python -m one_touch_loader.loaders.betting_loader "$@"
