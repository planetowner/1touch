#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# API와 같은 이미지·DB·R2 설정으로 정리해요. 옵션 없이 직접 실행하면 조회만 해요.
# 정리 작업도 공통 자원 제한을 써서 운영 API·DB의 메모리를 보호해요.
export ONETOUCH_BATCH_MEMORY_LIMIT=512m
exec bash compose-production.sh -f compose.batch-resources.yaml run --rm --no-deps -T api \
  python -m one_touch_loader.cli community cleanup "$@"
