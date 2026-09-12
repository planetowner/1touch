$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ssh-common.ps1')

Write-Host 'SSH 키 암호를 입력해 서버 API와 DB 연결을 열어요.'
Write-Host '연결 완료 문구가 나오면 이 창을 열어 두고 개발해요. 종료할 때는 Ctrl+C를 눌러요.'
Write-Host '연결 후 API 문서: http://127.0.0.1:18000/docs'
Write-Host '연결 후 DB 주소: 127.0.0.1, 포트 13306, 사용자 onetouch, DB 1touch'
# PC의 기존 MySQL 3306 포트와 구분하고 서버 포트는 외부에 공개하지 않아요.
$tunnelOptions = $keyOptions + @(
    '-N', '-o', 'ExitOnForwardFailure=yes',
    # 인증과 두 로컬 포트 열기가 성공한 뒤에만 완료 문구를 표시해요.
    '-o', 'PermitLocalCommand=yes',
    '-o', "LocalCommand=powershell.exe -NoProfile -Command Write-Host '연결 완료: 서버 API와 DB 터널이 열렸어요.'",
    '-L', '127.0.0.1:13306:127.0.0.1:3306',
    '-L', '127.0.0.1:18000:127.0.0.1:8000',
    "${loginUser}@$serverIp"
)
Invoke-AccessCommand $sshPath $tunnelOptions
