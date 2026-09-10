[CmdletBinding()]
param(
    [string]$SmtpCredentialsCsv = (Join-Path $env:USERPROFILE 'Downloads\1touch-auth-smtp_credentials.csv')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ssh-common.ps1')
$backendPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$credentialsPath = (Resolve-Path -LiteralPath $SmtpCredentialsCsv).Path
$pythonPath = (Get-Command python.exe -ErrorAction Stop).Source
$releaseTag = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$remotePath = "/opt/1touch/transfer/user-community/$releaseTag"

Push-Location -LiteralPath (Join-Path $backendPath 'python')
try {
    # 실제 빈 테이블 조건부터 확인해 실패한 점검 때문에 기존 API를 멈추지 않아요.
    Write-Host '1/5. 운영 DB의 기존 회원 테이블이 비어 있는지 확인해요.'
    Invoke-AccessCommand $pythonPath @('-X', 'utf8', '-B', '-m', 'diagnostics.verify_user_community', '--before')

    Write-Host '2/5. SMTP 키를 비공개 임시 폴더에 전송해 서버 설정을 준비해요.'
    Invoke-AccessCommand $sshPath ($keyOptions + @("${loginUser}@$serverIp", "install -d -m 700 $remotePath"))
    Invoke-AccessCommand $scpPath ($keyOptions + @($credentialsPath, "${loginUser}@${serverIp}:$remotePath/smtp.csv"))
    Invoke-AccessCommand $scpPath ($keyOptions + @(
        (Join-Path $PSScriptRoot 'configure_ses.py'),
        (Join-Path $PSScriptRoot 'prepare-user-community.sh'), "${loginUser}@${serverIp}:$remotePath/"
    ))
    Write-Host 'sudo에는 서버 onetouch 계정 암호를 입력해요. SMTP 연결 확인 후 기존 API를 멈춰요.'
    Invoke-AccessCommand $sshPath ($keyConnection + @("sudo bash $remotePath/prepare-user-community.sh"))

    Write-Host '3/5. 기존 실행기로 백업한 뒤 회원·커뮤니티 DB 구조를 바꿔요.'
    & (Join-Path $backendPath 'python\one_touch_loader\sql\run_user_community_migration.ps1')

    # 마이그레이션 실패 후 예전 API를 자동 재시작하면 바뀐 구조와 충돌할 수 있어요.
    Write-Host '4/5. 기존 운영 배포기로 새 API를 배포해요. sudo 암호를 다시 요청할 수 있어요.'
    & (Join-Path $PSScriptRoot 'deploy-production.ps1')

    Write-Host '5/5. 새 DB 구조와 공개 인증 안내를 확인해요.'
    Invoke-AccessCommand $pythonPath @('-X', 'utf8', '-B', '-m', 'diagnostics.verify_user_community', '--after')
    Invoke-RestMethod 'https://api.1touch.football/v1/auth/providers?country_code=KR'
    Write-Host '회원·커뮤니티 API 배포를 확인했어요. 실제 메일 수신·R2·소셜 로그인은 별도 확인이 필요해요.'
}
finally { Pop-Location }
