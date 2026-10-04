#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
production=/opt/1touch/backend/deploy/vultr
umask 077

# 원본 계정·경기·포인트는 읽어 오지 않아요. 설정·구조·공개 사전만 따로 가져와요.
if [[ ! -f .env.live-test ]]; then
  bash "$production/compose-production.sh" exec -T api python - < export_settings.py > .env.live-test.pending
  mv .env.live-test.pending .env.live-test
fi
install -d -o 1001 -g 1001 ../../logs
bash compose.sh build api
bash compose.sh up -d --wait live-test-db
if [[ ! -f .schema-initialized ]]; then
  bash "$production/compose-production.sh" exec -T api python - < export_schema.py > .schema.sql
  bash compose.sh exec -T live-test-db sh -c \
    'MYSQL_PWD="$MYSQL_PASSWORD" mysql --user="$MYSQL_USER" --database="$MYSQL_DATABASE"' < .schema.sql
  touch .schema-initialized
fi

bash compose.sh run --rm --no-deps api python -m live_test.seed --apply
bash compose.sh run --rm --no-deps api python -c \
  'from live_test.predictions import refresh; print(refresh(apply=True))'
bash compose.sh up -d --wait api
python3 proxy_route.py add "$production/Caddyfile"
if ! bash "$production/compose-production.sh" exec -T proxy caddy validate --config /etc/caddy/Caddyfile; then
  python3 proxy_route.py remove "$production/Caddyfile"
  exit 1
fi
bash "$production/compose-production.sh" exec -T proxy caddy reload --config /etc/caddy/Caddyfile
bash compose.sh up -d live notifications refresh
curl --fail --silent --show-error https://api.1touch.football/live-test/v1/health
echo 'Live test is ready: https://api.1touch.football/live-test/v1/'
