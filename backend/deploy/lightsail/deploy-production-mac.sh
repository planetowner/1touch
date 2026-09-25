#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
backend_directory=$(cd -- "$script_directory/../.." && pwd)
release_tag=$(date -u +%Y%m%dT%H%M%SZ)
output_directory="$backend_directory/logs/lightsail-releases/$release_tag"
remote_directory="/home/ubuntu/onetouch-transfer/production/$release_tag"
server_ip=3.39.136.116
server="ubuntu@$server_ip"
key_path="$HOME/.ssh/onetouch-lightsail-seoul.pem"
ssh_options=(-o IdentitiesOnly=yes -o PreferredAuthentications=publickey -o PasswordAuthentication=no -i "$key_path")

# 운영 DB는 다시 옮기지 않고 코드만 새 릴리스로 묶어요.
python3 "$script_directory/../vultr/transfer.py" code --output "$output_directory"
ssh -n "${ssh_options[@]}" "$server" "install -d -m 700 '$remote_directory'"
scp "${ssh_options[@]}" \
  "$output_directory/backend.tar.gz" "$output_directory/manifest.json" \
  "$script_directory/../vultr/deploy-production.sh" "$server:$remote_directory/"
ssh -tt "${ssh_options[@]}" "$server" \
  "sudo bash '$remote_directory/deploy-production.sh' '$release_tag' api.1touch.football '$server_ip'"
