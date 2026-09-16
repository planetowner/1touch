#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# 같은 이미지·DB 설정으로 최근 7일을 확인해요. 저장은 타이머의 --apply가 있어야 해요.
exec bash compose-production.sh run --rm --no-deps -T api \
  python -m one_touch_loader.cli opta-shots sync \
  --dataset both --recent-days 7 --refresh-details --output-dir /app/logs/opta-sync "$@"
