[CmdletBinding(DefaultParameterSetName = 'Setup')]
param(
    [Parameter(ParameterSetName = 'Verify')][switch]$VerifyOnly,
    [Parameter(ParameterSetName = 'Password')][switch]$ChangeUserPassword,
    [Parameter(ParameterSetName = 'Harden')][switch]$HardenSsh
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ssh-common.ps1')
$serverScript = Join-Path $PSScriptRoot 'onetouch-access.sh'
$keygenPath = (Get-Command ssh-keygen.exe -ErrorAction Stop).Source

if ($PSCmdlet.ParameterSetName -eq 'Setup') {
    if ((Test-Path -LiteralPath $keyPath) -or (Test-Path -LiteralPath "$keyPath.pub")) {
        throw "이미 키 파일이 있어요: $keyPath. 덮어쓰지 않고 상태를 먼저 확인해요."
    }

    Write-Host '1/4. 이 서버에 사용할 SSH 키를 만들어요.'
    Write-Host 'Enter passphrase에는 키를 보호할 암호를 입력하고 한 번 더 입력해요.'
    Invoke-AccessCommand $keygenPath @('-t', 'ed25519', '-a', '64', '-f', $keyPath, '-C', 'onetouch-dev')

    Write-Host '2/4. 공개키와 계정 설정 파일을 서버로 보내요.'
    Write-Host 'root 암호를 물으면 Vultr 화면의 현재 서버 암호를 입력해요.'
    Invoke-AccessCommand $scpPath @($serverScript, "$keyPath.pub", "root@${serverIp}:/root/")

    Write-Host '3/4. onetouch 계정을 만들어요.'
    Write-Host '먼저 현재 root 암호를 입력해요. 이후 New password에는 새 onetouch 계정 암호를 정해요.'
    Invoke-AccessCommand $sshPath @('-tt', "root@$serverIp", "bash /root/onetouch-access.sh $loginUser /root/onetouch-vultr.pub")
}

if ($ChangeUserPassword) {
    Write-Host 'onetouch 계정 암호만 변경해요. 기존 root 암호와 SSH 키 암호는 유지해요.'
    Write-Host 'Enter passphrase에는 기존 SSH 키 암호를 입력해요.'
    Write-Host 'Current password에는 기존 onetouch 암호, New password와 Retype에는 새 계정 암호를 입력해요.'
    # 로그인한 일반 사용자 자신의 암호만 바꾸므로 sudo나 root 계정을 사용하지 않아요.
    Invoke-AccessCommand $sshPath ($keyConnection + @('passwd'))
    Write-Host '완료: onetouch 계정 암호를 변경했어요. root 암호와 SSH 키 암호는 유지했어요.'
    return
}

$verifyCommand = 'id && sudo -k && sudo -v && sudo -n id'
Write-Host 'SSH 키 접속과 관리자 권한을 확인해요.'
Write-Host '키 암호를 입력하고, sudo 암호를 물으면 새 onetouch 계정 암호를 입력해요.'
Invoke-AccessCommand $sshPath ($keyConnection + @($verifyCommand))

if ($HardenSsh) {
    $hardeningScript = Join-Path $PSScriptRoot 'onetouch-harden-ssh.sh'
    Write-Host '접속 검증을 통과했어요. SSH 제한 설정 파일을 전송해요.'
    Invoke-AccessCommand $scpPath ($keyOptions + @($hardeningScript, "${loginUser}@${serverIp}:/home/${loginUser}/onetouch-harden-ssh.sh"))
    Write-Host 'root 직접 접속과 비밀번호 SSH 접속을 차단해요. sudo에는 onetouch 계정 암호를 입력해요.'
    Invoke-AccessCommand $sshPath ($keyConnection + @("sudo bash /home/$loginUser/onetouch-harden-ssh.sh"))
    Write-Host '변경된 설정으로 새 연결을 열어 접속과 관리자 권한을 다시 확인해요.'
    Invoke-AccessCommand $sshPath ($keyConnection + @($verifyCommand))
    Write-Host '완료: SSH 접속 제한과 새 키 연결 검증을 마쳤어요. 기존 암호들은 유지했어요.'
    return
}

Write-Host '완료: onetouch 계정, SSH 키 접속, sudo 권한을 확인했어요. 기존 root 암호는 유지했어요.'
Write-Host '이 검증 명령은 SSH 로그인 제한 설정을 변경하지 않아요.'
Write-Host "접속 명령: ssh -i `"$keyPath`" ${loginUser}@$serverIp"
