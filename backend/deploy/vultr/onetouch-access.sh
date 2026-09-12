#!/usr/bin/env bash
set -euo pipefail

login_user=${1:?Usage: bash onetouch-access.sh USER PUBLIC_KEY}
public_key=${2:?Usage: bash onetouch-access.sh USER PUBLIC_KEY}

if [[ $(id -u) != 0 ]]; then
  echo 'Run this initial account setup as root.' >&2
  exit 1
fi
if id "$login_user" >/dev/null 2>&1; then
  echo "Account $login_user already exists. Stop and inspect it before continuing." >&2
  exit 1
fi
ssh-keygen -lf "$public_key"

# 첫 암호는 사용자가 터미널에서 직접 정하고, 명령이나 파일에는 담지 않아요.
adduser --disabled-password --gecos '' "$login_user"
passwd "$login_user"
usermod -aG sudo "$login_user"

login_home=$(getent passwd "$login_user" | cut -d: -f6)
login_group=$(id -gn "$login_user")
install -d -m 700 -o "$login_user" -g "$login_group" "$login_home/.ssh"
install -m 600 -o "$login_user" -g "$login_group" "$public_key" "$login_home/.ssh/authorized_keys"
id "$login_user"
ssh-keygen -lf "$login_home/.ssh/authorized_keys"

# 새 연결에서 키와 sudo를 검증하기 전에는 기존 SSH 로그인 설정을 바꾸지 않아요.
echo 'Account and public key installed. Verify a new key-only SSH connection next.'
