#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
production=/opt/1touch/backend/deploy/vultr

if [[ "${1:-}" != "" && "${1:-}" != "--delete-data" ]]; then
  echo 'Usage: bash stop.sh [--delete-data]' >&2
  exit 2
fi
python3 proxy_route.py remove "$production/Caddyfile"
bash "$production/compose-production.sh" exec -T proxy caddy validate --config /etc/caddy/Caddyfile
bash "$production/compose-production.sh" exec -T proxy caddy reload --config /etc/caddy/Caddyfile
if [[ "${1:-}" == "--delete-data" ]]; then
  # 명시한 테스트 Compose 프로젝트의 DB 볼륨만 삭제해요.
  bash compose.sh down --volumes --rmi local
  rm -f .schema-initialized .schema.sql .env.live-test
else
  bash compose.sh down
fi
