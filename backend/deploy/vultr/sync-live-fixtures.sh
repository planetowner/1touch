#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# 경기 응답 처리와 종료 후 선수 지표 계산을 실측한 상한을 공통 설정에 전달해요.
export ONETOUCH_BATCH_MEMORY_LIMIT=512m
# API와 같은 코드·DB·공급자 설정을 써요. 직접 실행은 조회만 하고 타이머가 --apply를 전달해요.
exec bash compose-production.sh -f compose.batch-resources.yaml run --rm --no-deps -T api \
  python -m one_touch_loader.cli fixtures live "$@"
