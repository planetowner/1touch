#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# 공급자별 서비스로 실행해 브라우저 수집이 라이브 점수·다른 공급자를 막지 않게 해요.
exec bash compose-production.sh run --rm --no-deps -T api \
  python -m one_touch_loader.loaders.match_refresh "$@"
