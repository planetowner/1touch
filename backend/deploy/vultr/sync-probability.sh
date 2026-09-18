#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# API와 같은 DB의 학습 모델을 유지하고, 바뀐 리그와 빠진 일별 기록만 계산해요.
exec bash compose-production.sh run --rm --no-deps -T api \
  python -m one_touch_loader.cli probability refresh "$@"
