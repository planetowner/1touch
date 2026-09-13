#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# API와 같은 코드·DB·공급자 설정을 써요. 직접 실행은 조회만 하고 타이머가 --apply를 전달해요.
exec bash compose-production.sh run --rm --no-deps -T api \
  python -m one_touch_loader.cli fixtures live "$@"
