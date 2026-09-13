[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ssh-common.ps1')
$backendRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pythonPath = (Get-Command python.exe).Source

Write-Host '1/4. 운영 서버의 Sportmonks 키·라이브 조회 권한을 읽기 전용으로 확인해요.'
& (Join-Path $PSScriptRoot 'check-live-fixtures.ps1')
Write-Host '2/4. 라인업을 백업하고 선수 통계·경기 시계 테이블을 준비해요.'
Invoke-AccessCommand $pythonPath @(
    '-X', 'utf8', '-B', (Join-Path $backendRoot 'python\diagnostics\migrate_fixture_player_stats.py'), '--apply'
)
Invoke-AccessCommand $pythonPath @(
    '-X', 'utf8', '-B', (Join-Path $backendRoot 'python\diagnostics\migrate_fixture_clock.py'), '--apply'
)
Write-Host '3/4. 백엔드를 배포해요. 프런트엔드와 Git 커밋·푸시는 변경하지 않아요.'
& (Join-Path $PSScriptRoot 'deploy-production.ps1')
Write-Host '4/4. 첫 라이브 수집을 확인하고, 회차가 끝날 때마다 15초 뒤 갱신하도록 켜요.'
Invoke-AccessCommand $sshPath ($keyConnection + @(
    'sudo systemctl start onetouch-fixture-live.service && sudo systemctl enable --now onetouch-fixture-live.timer && sudo systemctl list-timers onetouch-fixture-live.timer --no-pager'
))
Write-Host '완료: 백엔드 라이브 수집과 경기 시계 API를 준비했어요. 앱의 표시·반복 호출은 프런트엔드에서 연결해야 해요.'
