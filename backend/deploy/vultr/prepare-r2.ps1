[CmdletBinding()]
param()

# 이미 안내한 R2 명령은 유지하고 실제 설정 전송은 공통 절차를 사용해요.
& (Join-Path $PSScriptRoot 'prepare-service-settings.ps1') -Service r2
