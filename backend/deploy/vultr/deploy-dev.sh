#!/usr/bin/env bash
set -euo pipefail

cd /opt/1touch/transfer
# 전송 중 파일이 달라졌다면 코드를 풀거나 DB를 복원하기 전에 멈춰요.
python3 - <<'PY'
import hashlib
import json
from pathlib import Path

manifest = json.loads(Path('manifest.json').read_text())
for name, expected in manifest['files'].items():
    with Path(name).open('rb') as stream:
        actual = hashlib.file_digest(stream, 'sha256').hexdigest()
    if actual != expected:
        raise SystemExit(f'Checksum mismatch: {name}')
    print(f'Verified: {name}')
PY
tar -xzf backend.tar.gz -C /opt/1touch/backend
cd /opt/1touch/backend/deploy/vultr

# 검증한 설치·복원 스크립트를 그대로 호출해 수동 실행과 같은 규칙을 적용해요.
sudo bash install-docker.sh
sudo bash init-env.sh
sudo docker compose up -d --wait db
sudo bash import-db.sh /opt/1touch/transfer/database.sql.gz
sudo docker compose build api
sudo docker compose run --rm --no-deps -v /opt/1touch/transfer:/transfer:ro api \
  python /app/deploy/vultr/transfer.py verify /transfer/manifest.json
sudo docker compose up -d api
sudo docker compose ps
echo 'Restored database verified and API container started. Verify API access through SSH next.'
