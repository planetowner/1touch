#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# 종료 경기만 즉시 수집하고 아직 없는 원본은 경기별로 5분 뒤 다시 확인해요.
exec bash sync-match-refresh.sh opta "$@"
