$serverIp = '158.247.195.63'
$loginUser = 'onetouch'
$keyPath = Join-Path $env:USERPROFILE '.ssh\onetouch-vultr'
$sshPath = (Get-Command ssh.exe -ErrorAction Stop).Source
$scpPath = (Get-Command scp.exe -ErrorAction Stop).Source

# 비밀번호 접속을 키 접속 성공으로 오인하지 않도록 모든 작업에서 키 인증만 사용해요.
$keyOptions = @('-i', $keyPath, '-o', 'IdentitiesOnly=yes', '-o', 'PreferredAuthentications=publickey', '-o', 'PasswordAuthentication=no')
$keyConnection = @('-tt') + $keyOptions + @("${loginUser}@$serverIp")

# 접속 설정과 이전 작업이 같은 종료 코드 처리 규칙을 사용해요.
function Invoke-AccessCommand {
    param([string]$Program, [string[]]$CommandArguments)
    # 파이프는 줄바꿈 없는 SSH·sudo 입력 안내를 막아요. 터미널로 직접 출력하고 종료 코드로 판단해요.
    & $Program @CommandArguments
    $commandExitCode = $LASTEXITCODE
    if ($commandExitCode -ne 0) {
        throw "단계가 실패했어요. 종료 코드: $commandExitCode. 출력을 확인한 뒤 이어서 진행해요."
    }
}
