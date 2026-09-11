[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('r2', 'google', 'apple', 'kakao', 'ses', 'community')]
    [string]$Service
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ssh-common.ps1')
$Service = $Service.ToLowerInvariant()
$backendPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$pythonPath = (Get-Command python.exe -ErrorAction Stop).Source
$tag = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$remotePath = "/opt/1touch/transfer/$Service/$tag"
$credentialsFile = New-TemporaryFile
$settingsProgram = "configure_$Service.py"
$serverProgram = "prepare-$Service.sh"

try {
    # 서비스별로 같은 전송 절차를 쓰되 각 설정 프로그램이 자기 서비스 값만 골라요.
    Invoke-AccessCommand $pythonPath @('-X', 'utf8', '-B', (Join-Path $PSScriptRoot $settingsProgram),
        '--from-env', (Join-Path $backendPath '.env'), '--env-file', $credentialsFile.FullName)
    Write-Host "$Service 설정만 서버에 전송해요. 다른 서비스의 설정과 DB는 옮기지 않아요."
    Invoke-AccessCommand $sshPath ($keyOptions + @("${loginUser}@$serverIp", "install -d -m 700 $remotePath"))
    Invoke-AccessCommand $scpPath ($keyOptions + @($credentialsFile.FullName, "${loginUser}@${serverIp}:$remotePath/$Service.env"))
    Invoke-AccessCommand $scpPath ($keyOptions + @(
        (Join-Path $PSScriptRoot $settingsProgram), (Join-Path $PSScriptRoot 'environment_settings.py'),
        (Join-Path $PSScriptRoot 'prepare-service-settings.sh'),
        (Join-Path $PSScriptRoot $serverProgram), "${loginUser}@${serverIp}:$remotePath/"))
    Write-Host 'sudo에는 서버 onetouch 계정 암호를 입력해요. 설정 저장과 읽기 전용 점검을 진행해요.'
    Invoke-AccessCommand $sshPath ($keyConnection + @("sudo bash $remotePath/$serverProgram"))
    Write-Host '서버 설정을 준비했어요. 실행 중인 API에는 다음 배포 때 반영돼요.'
}
finally {
    # 이번 명령이 만든 로컬 임시 파일만 지워요. 원본 .env는 유지해요.
    Remove-Item -LiteralPath $credentialsFile.FullName -Force
}
