$ErrorActionPreference = 'Stop'

Write-Host '[fixtures verification] START'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
Set-Location -LiteralPath $backendRoot

$env:PYTHONPATH = Join-Path $backendRoot 'python'

Write-Host '[fixtures verification] COMPILE'
python -m compileall -q `
    '.\python\one_touch_loader' `
    '.\python\diagnostics\test_fixtures_loader.py' `
    '.\python\diagnostics\verify_fixtures_migration.py'
if ($LASTEXITCODE -ne 0) {
    throw "Python compile failed with exit code $LASTEXITCODE"
}

Write-Host '[fixtures verification] TEST'
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$testOutput = python -m unittest discover `
    -s '.\python\diagnostics' `
    -p 'test_fixtures_loader.py' 2>&1
$testExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
$testOutput | ForEach-Object { Write-Host $_ }
if ($testExitCode -ne 0) {
    throw "Fixtures loader tests failed with exit code $testExitCode"
}

Write-Host '[fixtures verification] DATABASE'
python '.\python\diagnostics\verify_fixtures_migration.py'
if ($LASTEXITCODE -ne 0) {
    throw "Fixtures verification failed with exit code $LASTEXITCODE"
}

Write-Host '[fixtures verification] PASSED'
