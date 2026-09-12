#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# API와 같은 이미지·DB·R2 설정으로 정리해요. 옵션 없이 직접 실행하면 조회만 해요.
exec bash compose-production.sh run --rm --no-deps -T api \
  python -m one_touch_loader.cli community cleanup "$@"
