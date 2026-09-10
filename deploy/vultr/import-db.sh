#!/usr/bin/env bash
set -euo pipefail
dump_path=$(realpath -- "${1:?Usage: bash import-db.sh /absolute/path/database.sql.gz}")
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

gzip --test -- "$dump_path"
# 개발 중인 서버 DB에 다시 덮어쓰는 일을 막기 위해 빈 DB에만 복원해요.
table_count=$(docker compose exec -T db sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -Nse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '\''1touch'\''"')
if [[ "$table_count" != 0 ]]; then
  echo "1touch already contains $table_count tables/views. Import cancelled." >&2
  exit 1
fi
gzip --decompress --stdout -- "$dump_path" | docker compose exec -T db sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot --default-character-set=utf8mb4 1touch'
echo 'Import finished. Run transfer.py verify before using this database.'
