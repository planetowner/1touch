#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
exec docker compose --project-name onetouch-live-test --env-file .env.live-test -f compose.yaml "$@"
