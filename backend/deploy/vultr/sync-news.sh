#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# 기사 수집과 표시 이미지 변환을 실측한 상한을 공통 설정에 전달해요.
export ONETOUCH_BATCH_MEMORY_LIMIT=512m
exec bash compose-production.sh -f compose.batch-resources.yaml run --rm --no-deps -T api \
  python -m one_touch_loader.loaders.news_loader refresh "$@"
