#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# 최근 미제공 경기는 5분 뒤, 킥오프 후 48시간이 지난 미제공 경기는 하루 뒤 확인해요.
exec bash sync-match-refresh.sh opta "$@"
