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
prune_backups() {
  local backup_directory="$1"
  local retention_days="$2"
  find "$backup_directory" -maxdepth 1 -type f -name '20?????????????Z.sql.gz' \
    -mtime "+$((retention_days - 1))" -delete
}

# 새 백업을 검증한 뒤 정리해요. 일일 백업은 14일, 수동·배포 백업은 30일 보관해요.
if [[ "${1:-}" == --daily ]]; then
  prune_backups "$PWD/backups/daily" 14
fi
prune_backups "$PWD/backups" 30
echo "Backup created: $PWD/$backup_path"
