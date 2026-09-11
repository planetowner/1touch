[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$sourceDirectory = Split-Path $PSScriptRoot -Parent
$backendDirectory = [IO.Path]::GetFullPath((Join-Path $sourceDirectory '..\..'))
$testRoot = Join-Path $backendDirectory ('logs\service-settings-test-' + [guid]::NewGuid().ToString('N'))
$testScripts = Join-Path $testRoot 'deploy\vultr'
[void](New-Item -ItemType Directory -Path $testScripts -Force)
$encoding = [Text.UTF8Encoding]::new($true)
foreach ($name in @('prepare-service-settings.ps1', 'prepare-r2.ps1', 'configure_google.py', 'configure_r2.py', 'configure_apple.py', 'configure_kakao.py', 'environment_settings.py')) {
    Copy-Item -LiteralPath (Join-Path $sourceDirectory $name) -Destination $testScripts
}
$fakeEnvironment = "DB_HOST=test-db`nSES_SMTP_PASSWORD=test-smtp`nAUTH_CODE_SECRET=test-auth`nR2_ACCOUNT_ID=test-account`nR2_BUCKET=test-bucket`nR2_ACCESS_KEY_ID=test-access`nR2_SECRET_ACCESS_KEY=test-secret`nGOOGLE_CLIENT_IDS=test.apps.googleusercontent.com`n"
$fakeEnvironment += "APPLE_CLIENT_IDS=com.example.football`nAPPLE_TEAM_ID=TESTTEAM01`nAPPLE_KEY_ID=TESTKEY001`nAPPLE_PRIVATE_KEY='-----BEGIN PRIVATE KEY-----\nZmFrZS1rZXk=\n-----END PRIVATE KEY-----'`n"
$fakeEnvironment += "KAKAO_APP_ID=123456`nKAKAO_REST_API_KEY=0123456789abcdef0123456789abcdef`n"
[IO.File]::WriteAllText((Join-Path $testRoot '.env'), $fakeEnvironment, [Text.UTF8Encoding]::new($false))

# 실제 Python 내보내기만 실행하고 SSH·SCP는 기록만 남겨 운영 서버에 접근하지 않아요.
$fakeAccess = @'
$sshPath = 'test-ssh'
$scpPath = 'test-scp'
$loginUser = 'test-user'
$serverIp = 'example.invalid'
$keyOptions = @()
$keyConnection = @('test-user@example.invalid')
$script:testCallCount = 0
function Invoke-AccessCommand {
    param([string]$Program, [string[]]$CommandArguments)
    $script:testCallCount++
    [pscustomobject]@{ program = $Program; arguments = $CommandArguments } |
        ConvertTo-Json -Compress | Add-Content -LiteralPath $env:ONETOUCH_TEST_TRACE -Encoding UTF8
    if ($script:testCallCount -eq [int]$env:ONETOUCH_TEST_FAIL_AT) { throw 'Expected test failure' }
    if ($Program -notin @('test-ssh', 'test-scp')) {
        & $Program @CommandArguments
        if ($LASTEXITCODE -ne 0) { throw 'Test export failed' }
    }
    if ($Program -eq 'test-scp' -and $script:testCallCount -eq 3) {
        Copy-Item -LiteralPath $CommandArguments[0] -Destination $env:ONETOUCH_TEST_EXPORTED
    }
}
'@
[IO.File]::WriteAllText((Join-Path $testScripts 'ssh-common.ps1'), $fakeAccess, $encoding)
$powershellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
$caseCount = 0
foreach ($service in @('r2', 'google', 'apple', 'kakao')) {
    foreach ($failAt in 0..5) {
        $caseName = "$service-$failAt"
        $env:ONETOUCH_TEST_TRACE = Join-Path $testRoot "$caseName.jsonl"
        $env:ONETOUCH_TEST_EXPORTED = Join-Path $testRoot "$caseName.env"
        $env:ONETOUCH_TEST_FAIL_AT = [string]$failAt
        $entry = Join-Path $testScripts 'prepare-service-settings.ps1'
        $entryArguments = @('-Service', $service)
        if ($service -eq 'r2') {
            $entry = Join-Path $testScripts 'prepare-r2.ps1'
            $entryArguments = @()
        }
        # 실패 출력도 테스트 로그로 받아 다음 실패 지점을 계속 확인해요.
        $ErrorActionPreference = 'Continue'
        & $powershellPath -NoLogo -NoProfile -NonInteractive -File $entry @entryArguments *> (Join-Path $testRoot "$caseName.log")
        $caseExitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if (($caseExitCode -eq 0) -ne ($failAt -eq 0)) { throw "Unexpected exit: $caseName" }
        $calls = @(Get-Content -LiteralPath $env:ONETOUCH_TEST_TRACE | ForEach-Object { $_ | ConvertFrom-Json })
        $expectedCalls = if ($failAt -eq 0) { 5 } else { $failAt }
        if ($calls.Count -ne $expectedCalls) { throw "Continued after failure: $caseName" }
        $temporaryFile = $calls[0].arguments[-1]
        if (Test-Path -LiteralPath $temporaryFile) { throw "Temporary file was retained: $caseName" }
        if ($failAt -eq 0 -or $failAt -gt 3) {
            $selectedKeys = @(Get-Content -LiteralPath $env:ONETOUCH_TEST_EXPORTED | ForEach-Object { ($_ -split '=', 2)[0] })
            $expectedKeys = switch ($service) {
                'r2' { @('R2_ACCOUNT_ID', 'R2_BUCKET', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY') }
                'google' { @('GOOGLE_CLIENT_IDS') }
                'apple' { @('APPLE_CLIENT_IDS', 'APPLE_TEAM_ID', 'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY') }
                'kakao' { @('KAKAO_APP_ID', 'KAKAO_REST_API_KEY') }
            }
            if (Compare-Object $selectedKeys $expectedKeys) { throw "Unrelated settings exported: $caseName" }
        }
        if ([IO.File]::ReadAllText((Join-Path $testRoot '.env')) -ne $fakeEnvironment) { throw 'Source settings changed' }
        $caseCount++
    }
}
Remove-Item Env:ONETOUCH_TEST_TRACE, Env:ONETOUCH_TEST_EXPORTED, Env:ONETOUCH_TEST_FAIL_AT
Write-Output "PASS: $caseCount mocked transfers; per-service values only, failure stops, temporary files removed, source settings unchanged"
Write-Output "Test logs: $testRoot"
