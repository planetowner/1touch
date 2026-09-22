#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# Ranking을 한 번 읽고 리그·컵·유럽대항전에 같은 전력을 전달해요.
exec bash compose-production.sh run --rm --no-deps -T api \
  python -m one_touch_loader.loaders.probability_refresh "$@"
