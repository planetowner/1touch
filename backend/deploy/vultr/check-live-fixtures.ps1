[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ssh-common.ps1') -Target Lightsail

# 실행 중인 API의 키로 읽기만 확인해요. 키 값과 공급자 응답 본문은 출력하지 않아요.
# 새 코드 배포 전이라 기존 _get을 사용해요. 요청 항목은 test_live_preflight에서 새 수집기와 대조해요.
$probeCode = @'
import os
import requests
from one_touch_loader.core.sportmonks import SportmonksClient
token = os.getenv("SPORTMONKS_API_TOKEN")
if not token:
    raise SystemExit("Server SPORTMONKS_API_TOKEN is empty. No changes made.")
try:
    response = SportmonksClient(timeout=20)._get("livescores", params={
        "include": "participants;state;scores;periods;events.type;statistics.type;lineups.details;lineups.player;formations;coaches;pressure",
    })
except requests.RequestException as error:
    status = error.response.status_code if error.response is not None else "connection failed"
    raise SystemExit(f"Server Sportmonks live access: {status}. No changes made.")
print(f"Server Sportmonks live access: HTTP 200, fixtures={len(response['data'])}. Read-only check passed.")
'@
$probeBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($probeCode))
$remoteCommand = "cd /opt/1touch/backend/deploy/vultr && sudo bash compose-production.sh exec -T api python -c 'import base64; exec(base64.b64decode(""$probeBase64""))'"
Invoke-AccessCommand $sshPath ($keyConnection + @($remoteCommand))
