#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# Lightsail에서도 기존 운영 Compose 설정과 같은 DB·API 설정을 사용해요.
exec bash compose-production.sh run --rm --no-deps -T api \
  python -u -m one_touch_loader.cli current-season "$@"
