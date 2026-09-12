#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) != 0 ]]; then
  echo 'Run this SSH configuration step with sudo.' >&2
  exit 1
fi

config_path=/etc/ssh/sshd_config.d/00-onetouch-key-only.conf
if [[ -e "$config_path" ]]; then
  echo "$config_path already exists. Inspect it before running this step again." >&2
  exit 1
fi

# 먼저 읽은 값이 적용되므로 Vultr의 50-cloud-init.conf보다 앞에 배치해요.
policy='PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes'

# 실제 설정 파일을 쓰기 전에 현재 서버 설정과 합쳐 문법과 호스트 키를 검사해요.
{ printf '%s\n' "$policy"; cat /etc/ssh/sshd_config; } | /usr/sbin/sshd -t -f /dev/stdin
printf '%s\n' "$policy" > "$config_path"
chmod 644 "$config_path"
/usr/sbin/sshd -t
effective=$(/usr/sbin/sshd -T)
while read -r option value; do
  expected="${option,,} $value"
  if ! grep -Fxq "$expected" <<< "$effective"; then
    echo "SSH setting did not take effect: $expected. Service was not reloaded." >&2
    exit 1
  fi
  printf '%s\n' "$expected"
done <<< "$policy"

# 기존 연결을 끊지 않고 새 연결부터 정책을 적용해요. root 암호는 변경하지 않아요.
systemctl reload ssh
systemctl is-active --quiet ssh
echo 'SSH policy applied. Verify a new onetouch key connection from the PC.'
