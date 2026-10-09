#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# 전체 선수 재계산을 측정한 상한을 기존 공통 배치 설정에 전달해요.
export ONETOUCH_BATCH_MEMORY_LIMIT=512m
exec bash compose-production.sh -f compose.batch-resources.yaml run --rm --no-deps -T api \
  python -m one_touch_loader.loaders.player_indicators_loader "$@"
