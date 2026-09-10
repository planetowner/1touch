#!/usr/bin/env bash
set -euo pipefail
umask 077

release_tag="${1:?Release tag is required}"
api_domain="${2:?API domain is required}"
server_ip="${3:?Server IP is required}"
[[ "$release_tag" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]
[[ "$api_domain" =~ ^[a-z0-9]+([.-][a-z0-9]+)+$ ]]
transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
release_directory="/opt/1touch/releases/$release_tag"
runtime_directory=/opt/1touch/backend/deploy/vultr
candidate_environment="$runtime_directory/.env.production.next"

# DNS가 아직 주차 페이지를 가리키면 실행 중인 API를 변경하지 않아요.
python3 - "$api_domain" "$server_ip" <<'PY'
import socket, sys
domain, expected = sys.argv[1:]
addresses = {item[4][0] for item in socket.getaddrinfo(domain, 443, type=socket.SOCK_STREAM)}
if addresses != {expected}:
    raise SystemExit(f'DNS must point only to {expected}; observed: {sorted(addresses)}')
print(f'DNS verified: {domain} -> {expected}')
PY

# 현재 API는 그대로 둔 채 전송 파일을 확인하고 새 이미지를 먼저 만들어요.
python3 - "$transfer_directory" "$release_directory" <<'PY'
import hashlib, json, os, pathlib, sys, tarfile
transfer, release = map(pathlib.Path, sys.argv[1:])
manifest = json.loads((transfer / 'manifest.json').read_text())
archive = transfer / 'backend.tar.gz'
with archive.open('rb') as stream:
    actual = hashlib.file_digest(stream, 'sha256').hexdigest()
if actual != manifest['files']['backend.tar.gz']:
    raise SystemExit('Code archive checksum mismatch')
# 비밀 파일을 제외한 소스는 컨테이너의 일반 사용자도 읽을 수 있게 풀어요.
os.umask(0o022)
release.mkdir(parents=True, exist_ok=False)
with tarfile.open(archive, 'r:gz') as stream:
    stream.extractall(release, filter='data')
print(f'Code archive verified: {release.name}')
PY
# PowerShell 출력 파이프에서 진행 표시가 겹치지 않도록 일반 텍스트로 출력해요.
docker build --progress=plain -t "onetouch-api:$release_tag" \
  -f "$release_directory/deploy/vultr/Dockerfile" "$release_directory"

if [[ ! -f "$runtime_directory/.env.production" ]]; then
  # PowerShell은 줄바꿈 전까지 안내를 전달하지 않아, 암호 입력 전에 줄을 마쳐요.
  printf '\nNew API collaboration password:\n' >/dev/tty
  IFS= read -r -s collaboration_password </dev/tty
  printf '\nRetype API collaboration password:\n' >/dev/tty
  IFS= read -r -s confirmation </dev/tty
  printf '\n' >/dev/tty
  if [[ -z "$collaboration_password" || "$collaboration_password" != "$confirmation" ]]; then
    echo 'The passwords are empty or do not match. No API switch was made.' >&2
    exit 1
  fi
  # 이미지 버전은 운영 Compose 파일 한 곳에서 읽어요. DB 암호는 출력하지 않아요.
  proxy_image=$(RELEASE_TAG="$release_tag" API_DOMAIN="$api_domain" COLLAB_PASSWORD_HASH=preparing \
    docker compose --env-file "$runtime_directory/.env" \
    -f "$release_directory/deploy/vultr/compose.yaml" \
    -f "$release_directory/deploy/vultr/compose.production.yaml" config --format json \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["services"]["proxy"]["image"])')
  # Caddy는 줄바꿈으로 입력 완료를 판단해요. 없으면 EOF로 실패해요.
  password_hash=$(printf '%s\n' "$collaboration_password" | docker run --rm -i --entrypoint caddy "$proxy_image" hash-password)
  unset collaboration_password confirmation
  {
    printf 'API_DOMAIN=%s\nRELEASE_TAG=%s\nCOLLAB_USER=developer\n' "$api_domain" "$release_tag"
    printf "COLLAB_PASSWORD_HASH='%s'\n" "$password_hash"
    printf 'API_CORS_ORIGINS=\n'
  } > "$candidate_environment"
  unset password_hash
else
  if ! grep -Fxq "API_DOMAIN=$api_domain" "$runtime_directory/.env.production"; then
    echo 'API_DOMAIN differs from the saved configuration. Review the domain before deploying.' >&2
    exit 1
  fi
  sed "s/^RELEASE_TAG=.*/RELEASE_TAG=$release_tag/" "$runtime_directory/.env.production" > "$candidate_environment"
fi

# 기존 compose.yaml과 .env를 유지해 같은 DB 볼륨과 암호를 계속 사용해요.
for filename in compose.production.yaml Caddyfile compose-production.sh backup-db.sh; do
  install -m 644 "$release_directory/deploy/vultr/$filename" "$runtime_directory/$filename"
done
cd "$runtime_directory"
ONETOUCH_PRODUCTION_ENV=.env.production.next bash compose-production.sh config --quiet
ONETOUCH_PRODUCTION_ENV=.env.production.next bash compose-production.sh run --rm --no-deps proxy caddy validate --config /etc/caddy/Caddyfile
bash backup-db.sh
install -d -m 755 -o 1001 -g 1001 /opt/1touch/backend/logs

# Docker가 공개하는 포트도 HTTPS 프록시의 80/443으로 제한해요. DB/API는 루프백을 유지해요.
ufw allow 80/tcp
ufw allow 443/tcp
# 검증과 백업이 통과한 뒤에만 새 버전 설정으로 바꿔요.
if [[ -f .env.production ]]; then
  cp -- .env.production .env.production.previous
fi
mv -- .env.production.next .env.production
bash compose-production.sh up -d --no-build --wait --wait-timeout 180
install -m 644 "$release_directory/deploy/vultr/onetouch-db-backup.service" /etc/systemd/system/onetouch-db-backup.service
install -m 644 "$release_directory/deploy/vultr/onetouch-db-backup.timer" /etc/systemd/system/onetouch-db-backup.timer
systemctl daemon-reload
systemctl enable --now onetouch-db-backup.timer
systemctl start onetouch-db-backup.service

# 인증서를 무시하지 않고 실제 도메인의 HTTPS 응답을 확인해요.
curl --fail --silent --show-error --retry 12 --retry-all-errors --retry-delay 5 --max-time 10 \
  "https://$api_domain/v1/health"
status=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 10 "https://$api_domain/docs")
[[ "$status" == 401 ]] || { echo "Expected protected API docs (401), got $status" >&2; exit 1; }
printf '\n'
bash compose-production.sh ps
systemctl list-timers onetouch-db-backup.timer --no-pager
echo 'HTTPS, protected docs, API/database health and daily SQL backup verified.'
