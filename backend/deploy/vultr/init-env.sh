#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# 기존 접속 정보를 바꾸면 저장된 DB와 암호가 달라지므로 덮어쓰지 않아요.
if [[ -e .env ]]; then
  echo '.env already exists. No changes made.' >&2
  exit 1
fi
umask 077
{
  printf 'MYSQL_PASSWORD=%s\n' "$(openssl rand -hex 24)"
  printf 'MYSQL_ROOT_PASSWORD=%s\n' "$(openssl rand -hex 24)"
  printf 'SPORTMONKS_API_TOKEN=\n'
} > .env
echo 'Created private .env. Passwords were not printed.'
