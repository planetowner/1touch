#!/usr/bin/env bash
set -euo pipefail
umask 077

transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$transfer_directory/prepare-service-settings.sh"
prepare_service_settings "$transfer_directory" configure_r2.py r2.env --from-env /input/r2.env

# 현재 API와 같은 R2 클라이언트로 목록만 확인해요. 파일 업로드·삭제는 실행하지 않아요.
docker run --rm -i --user 0:0 -v "$runtime_directory:/settings:ro" \
  --entrypoint python "$api_image" -X utf8 -B - <<'PY'
import os
from dotenv import dotenv_values
from fastapi import HTTPException
settings = dotenv_values('/settings/.env.production', interpolate=False)
for key in ('R2_ACCOUNT_ID', 'R2_BUCKET', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY'):
    os.environ[key] = settings[key]
from one_touch_loader.api.services.media_storage import object_operation
try:
    result = object_operation('list_objects_v2', MaxKeys=1)
except HTTPException as exc:
    raise SystemExit(f'R2 check failed: HTTP {exc.status_code} {exc.detail}') from None
print(f"Server R2 bucket list verified: returned={result['KeyCount']}")
print('No files uploaded or deleted. The running API has not been restarted.')
PY

echo "Server settings backup retained: $transfer_directory/before.env.production"
