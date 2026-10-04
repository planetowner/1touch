#!/usr/bin/env bash
set -euo pipefail
script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
backend_directory=$(cd -- "$script_directory/../.." && pwd)
output_directory="$backend_directory/logs/live-test-releases/$(date -u +%Y%m%dT%H%M%SZ)"
server=ubuntu@3.39.136.116
key_path="$HOME/.ssh/onetouch-lightsail-seoul.pem"
ssh_options=(-o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -i "$key_path")

# 기존 코드 포장 함수를 써서 현재 작업 내용은 포함하고 환경변수·로그는 제외해요.
python3 "$script_directory/../vultr/transfer.py" code --output "$output_directory"
ssh "${ssh_options[@]}" "$server" 'install -d -m 700 /home/ubuntu/onetouch-live-test'
scp "${ssh_options[@]}" "$output_directory/backend.tar.gz" "$server:/home/ubuntu/onetouch-live-test/backend.tar.gz"
ssh "${ssh_options[@]}" "$server" \
  'sudo install -d /opt/onetouch-live-test/backend && sudo tar -xzf /home/ubuntu/onetouch-live-test/backend.tar.gz -C /opt/onetouch-live-test/backend && sudo bash /opt/onetouch-live-test/backend/deploy/live-test/start.sh'
