#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
compose_args=(run --rm --no-deps -T api)
if [[ "${1:-}" == opta || "${1:-}" == probability || "${1:-}" == understat || "${1:-}" == standings ]]; then
  # Understat·순위는 실제 갱신 경로를 측정한 상한을 같은 공통 설정에 전달해요.
  if [[ "${1:-}" == understat || "${1:-}" == standings ]]; then
    export ONETOUCH_BATCH_MEMORY_LIMIT=512m
  fi
  compose_args=(-f compose.batch-resources.yaml "${compose_args[@]}")
fi
# 공급자별 서비스로 실행해 브라우저 수집이 라이브 점수·다른 공급자를 막지 않게 해요.
exec bash compose-production.sh "${compose_args[@]}" \
  python -m one_touch_loader.loaders.match_refresh "$@"
