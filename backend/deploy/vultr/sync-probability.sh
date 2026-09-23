#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# 종료 결과가 바뀌면 바로 계산하고, 외부 Elo·대진은 15분마다 확인해요.
exec bash sync-match-refresh.sh probability "$@"
