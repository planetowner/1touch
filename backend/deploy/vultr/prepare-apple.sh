#!/usr/bin/env bash
set -euo pipefail
umask 077

transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$transfer_directory/prepare-service-settings.sh"
prepare_service_settings "$transfer_directory" configure_apple.py apple.env --from-env /input/apple.env

# Apple에 요청하지 않고 저장된 설정과 ES256 서명용 개인 키를 검사해요.
docker run --rm -i --network none --user 0:0 \
  -v "$runtime_directory:/settings:ro" -v "$transfer_directory:/input:ro" \
  --entrypoint python "$api_image" -X utf8 -B - <<'PY'
import sys
from pathlib import Path
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
sys.path.insert(0, '/input')
from configure_apple import apple_settings

selected = apple_settings(Path('/input/apple.env'))
saved = apple_settings(Path('/settings/.env.production'))
if not set(selected['APPLE_CLIENT_IDS'].split(',')).issubset(saved['APPLE_CLIENT_IDS'].split(',')):
    raise SystemExit('Apple Client IDs were not saved correctly.')
if any(saved[name] != selected[name] for name in ('APPLE_TEAM_ID', 'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY')):
    raise SystemExit('Apple signing settings were not saved correctly.')
key = serialization.load_pem_private_key(saved['APPLE_PRIVATE_KEY'].replace('\\n', '\n').encode(), password=None)
if not isinstance(key, ec.EllipticCurvePrivateKey) or not isinstance(key.curve, ec.SECP256R1):
    raise SystemExit('Apple signing requires a P-256 private key.')
message = b'1touch-apple-settings-check'
signature = key.sign(message, ec.ECDSA(hashes.SHA256()))
key.public_key().verify(signature, message, ec.ECDSA(hashes.SHA256()))
print(f"Server Apple settings verified: allowed={len(saved['APPLE_CLIENT_IDS'].split(','))} P-256 signature=valid")
print('Saved settings and key checked only. Real Apple sign-in has not been tested.')
print('No database changes. The running API has not been restarted.')
PY

echo "Server settings backup retained: $transfer_directory/before.env.production"
