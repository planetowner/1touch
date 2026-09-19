#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
exec bash compose-production.sh run --rm --no-deps -T api \
  python -m one_touch_loader.loaders.news_loader refresh "$@"
