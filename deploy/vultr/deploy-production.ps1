[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9]+([.-][a-z0-9]+)+$')]
    [string]$Domain = 'api.1touch.football'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ssh-common.ps1')
$releaseTag = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$backendPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$outputPath = Join-Path $backendPath "logs\vultr-releases\$releaseTag"
$remotePath = "/opt/1touch/transfer/production/$releaseTag"

Write-Host '1/3. 현재 코드를 묶어요. DB는 내보내거나 복원하지 않아요.'
Invoke-AccessCommand (Get-Command python.exe).Source @(
    '-X', 'utf8', '-B', (Join-Path $PSScriptRoot 'transfer.py'), 'code', '--output', $outputPath
)

Write-Host '2/3. 코드를 서버에 전송해요. Enter passphrase에는 SSH 키 암호를 입력해요.'
# 입력이 없는 준비 명령은 Windows SSH가 터미널 입력을 기다리며 종료되지 않도록 해요.
Invoke-AccessCommand $sshPath (@('-n') + $keyOptions + @("${loginUser}@$serverIp", "install -d -m 700 $remotePath"))
Invoke-AccessCommand $scpPath ($keyOptions + @(
    (Join-Path $outputPath 'backend.tar.gz'), (Join-Path $outputPath 'manifest.json'),
    (Join-Path $PSScriptRoot 'deploy-production.sh'), "${loginUser}@${serverIp}:$remotePath/"
))

Write-Host '3/3. HTTPS와 운영 설정을 적용해요. sudo에는 onetouch 계정 암호를 입력해요.'
Write-Host '첫 실행에는 개발팀용 API 접근 암호를 새로 정해요. SSH·DB 암호와 다르게 입력해요.'
Invoke-AccessCommand $sshPath ($keyConnection + @("sudo bash $remotePath/deploy-production.sh $releaseTag $Domain $serverIp"))
Write-Host "완료: https://$Domain/v1/health 응답과 API·DB 상태를 확인했어요."
