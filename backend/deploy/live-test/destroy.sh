#!/usr/bin/env bash
set -euo pipefail
script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bash "$script_directory/stop.sh" --delete-data
cd /
# 테스트 컨테이너·DB를 내린 뒤 전용 코드와 업로드 파일까지 지워요.
rm -rf -- /opt/onetouch-live-test /home/ubuntu/onetouch-live-test
