[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$TransferDirectory)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ssh-common.ps1')
$transferPath = (Resolve-Path -LiteralPath $TransferDirectory -ErrorAction Stop).Path
$transferFiles = @('backend.tar.gz', 'database.sql.gz', 'manifest.json') | ForEach-Object {
    $path = Join-Path $transferPath $_
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "이전 파일이 없어요: $path"
    }
    $path
}
$deployScript = Join-Path $PSScriptRoot 'deploy-dev.sh'

Write-Host '1/3. 서버에 코드와 DB 복사본을 받을 폴더를 준비해요.'
Write-Host 'Enter passphrase에는 SSH 키 암호, sudo에는 onetouch 계정 암호를 입력해요.'
# 코드는 앞으로도 같은 일반 계정으로 수정하고 전송할 수 있도록 소유자를 지정해요.
Invoke-AccessCommand $sshPath ($keyConnection + @("sudo install -d -o $loginUser -g $loginUser -m 700 /opt/1touch /opt/1touch/transfer /opt/1touch/backend"))

Write-Host '2/3. 코드와 DB 복사본을 전송해요. 크기에 따라 시간이 걸려요.'
Invoke-AccessCommand $scpPath ($keyOptions + $transferFiles + @($deployScript, "${loginUser}@${serverIp}:/opt/1touch/transfer/"))

Write-Host '3/3. 서버에 실행 환경을 설치하고 DB를 복원·비교한 뒤 API를 시작해요.'
Write-Host '처음 설치하므로 시간이 걸려요. 도중 sudo 암호를 다시 물으면 onetouch 계정 암호를 입력해요.'
Invoke-AccessCommand $sshPath ($keyConnection + @('bash /opt/1touch/transfer/deploy-dev.sh'))
Write-Host '완료: DB 복원 비교를 통과하고 API 컨테이너를 시작했어요. 다음은 PC에서 접속을 확인할 차례예요.'
