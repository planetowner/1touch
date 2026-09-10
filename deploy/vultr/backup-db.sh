#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
umask 077
backup_directory=backups
if [[ "${1:-}" == --daily ]]; then
  backup_directory=backups/daily
elif [[ $# -gt 0 ]]; then
  echo 'Usage: backup-db.sh [--daily]' >&2
  exit 1
fi
mkdir -p -- "$backup_directory"
backup_path="$backup_directory/$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
temporary_path="$backup_path.partial"
trap 'rm -f -- "$temporary_path"' EXIT

docker compose exec -T db sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump -uroot --single-transaction --quick --no-tablespaces --set-gtid-purged=OFF --hex-blob --routines --events --triggers 1touch' \
  | gzip > "$temporary_path"
gzip --test -- "$temporary_path"
mv -- "$temporary_path" "$backup_path"
# 자동 백업만 14일 보관해요. 변경 전에 직접 만든 백업은 그대로 남겨요.
if [[ "${1:-}" == --daily ]]; then
  find "$PWD/backups/daily" -maxdepth 1 -type f -name '20?????????????Z.sql.gz' -mtime +13 -delete
fi
echo "Backup created: $PWD/$backup_path"
