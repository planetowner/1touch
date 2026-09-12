$ErrorActionPreference = 'Stop'
$deployPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testPath = Join-Path ([IO.Path]::GetTempPath()) ('onetouch-deploy-' + [guid]::NewGuid().ToString('N'))
$testDeploy = Join-Path $testPath 'deploy\vultr'
$testSql = Join-Path $testPath 'python\one_touch_loader\sql'
[void](New-Item -ItemType Directory -Path $testDeploy, $testSql)
Copy-Item -LiteralPath (Join-Path $deployPath 'deploy-user-community.ps1') -Destination $testDeploy
# 외부 명령과 DB·배포 실행기를 모두 모의 처리해 실패 이후 작업이 없는지 확인해요.
@'
$serverIp = 'test-server'
$loginUser = 'test-user'
$sshPath = 'ssh'
$scpPath = 'scp'
$keyOptions = @()
$keyConnection = @()
function Invoke-AccessCommand { param($Program, $CommandArguments) Record-Stage $Program }
'@ | Set-Content -LiteralPath (Join-Path $testDeploy 'ssh-common.ps1') -Encoding UTF8
'Record-Stage migration' | Set-Content -LiteralPath (Join-Path $testSql 'run_user_community_migration.ps1')
'Record-Stage deploy' | Set-Content -LiteralPath (Join-Path $testDeploy 'deploy-production.ps1')
'test CSV placeholder' | Set-Content -LiteralPath (Join-Path $testPath 'smtp.csv')
function Record-Stage($name) {
    $global:stages.Add($name)
    if ($global:failAt -eq $global:stages.Count) { throw 'Simulated stage failure' }
}
function Get-Command { param($Name, $ErrorAction) [pscustomobject]@{Source = 'python'} }
function Invoke-RestMethod { param($Uri) Record-Stage 'verify-api' }

try {
    foreach ($failure in 0..9) {
        $global:stages = [Collections.Generic.List[string]]::new()
        $global:failAt = $failure
        $failed = $false
        try { & (Join-Path $testDeploy 'deploy-user-community.ps1') -SmtpCredentialsCsv (Join-Path $testPath 'smtp.csv') 6>$null }
        catch { $failed = $true }
        $expected = if ($failure) { $failure } else { 9 }
        if ($global:stages.Count -ne $expected -or $failed -ne ($failure -ne 0)) {
            throw "Unexpected failure boundary: $failure ($($global:stages -join ','))"
        }
        if (-not $failure -and ($global:stages -join ',') -ne 'python,ssh,scp,scp,ssh,migration,deploy,python,verify-api') {
            throw 'Unexpected deployment order'
        }
    }
    'PASS: preflight, SMTP preparation, migration, deployment and verification order; all stage failures stop (mocked)'
}
finally {
    # 이 테스트가 만든 임시 경로인지 확인하고 해당 경로만 정리해요.
    $resolvedTest = [IO.Path]::GetFullPath($testPath)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolvedTest.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolvedTest) -notlike 'onetouch-deploy-*') { throw 'Unexpected test cleanup path' }
    Remove-Item -LiteralPath $resolvedTest -Recurse -Force
}
