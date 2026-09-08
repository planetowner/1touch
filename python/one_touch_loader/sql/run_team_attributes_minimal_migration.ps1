$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'migrate_team_attributes_minimal.sql'
$viewPath = Join-Path $PSScriptRoot 'create_team_attribute_display_scores_view.sql'
$pythonRoot = Join-Path $backendRoot 'python'
$mysqlClientPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$mysqlDumpPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe'

foreach ($requiredPath in @($envPath, $sqlPath, $viewPath, $mysqlClientPath, $mysqlDumpPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing required file: $requiredPath"
    }
}

foreach ($line in Get-Content -LiteralPath $envPath) {
    $trimmedLine = $line.Trim()
    if (
        [string]::IsNullOrWhiteSpace($trimmedLine) -or
        $trimmedLine.StartsWith('#') -or
        -not $trimmedLine.Contains('=')
    ) {
        continue
    }

    $pair = $trimmedLine -split '=', 2
    $name = $pair[0].Trim()
    $value = $pair[1].Trim()
    if (
        ($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))
    ) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
}

$timestamp = Get-Date -Format 'yyyyMMddTHHmmss'
$backupDirectory = Join-Path $backendRoot "logs\database-backups\$timestamp"
$backupPath = Join-Path $backupDirectory 'before_team_attributes_minimal.sql'
$snapshotPath = Join-Path $backupDirectory 'team_attributes_preserved_values.json'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$env:MYSQL_PWD = $env:DB_PASSWORD
$previousOutputEncoding = $OutputEncoding
Push-Location -LiteralPath $pythonRoot
try {
    # 보존할 값과 표시 뷰를 기록하고, 변경할 키·관계가 실제 데이터와 맞는지 확인해요.
    python -X utf8 -B -m diagnostics.verify_team_attributes_migration --before $snapshotPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Team attributes preflight failed. No migration was executed.'
    }

    # 삭제할 기여도 JSON과 notes 원문까지 Attributes 4개 테이블·뷰를 모두 백업해요.
    & $mysqlDumpPath `
        "--host=$env:DB_HOST" `
        "--port=$env:DB_PORT" `
        "--user=$env:DB_USER" `
        '--default-character-set=utf8mb4' `
        '--single-transaction' `
        '--no-tablespaces' `
        "--result-file=$backupPath" `
        $env:DB_NAME `
        'team_attribute_training_features' `
        'team_attribute_regression_models' `
        'team_attribute_regression_weights' `
        'team_attribute_group_scores' `
        'v_team_attribute_display_scores'
    if ($LASTEXITCODE -ne 0) {
        throw "Attributes backup failed with exit code $LASTEXITCODE"
    }
    $backupFile = Get-Item -LiteralPath $backupPath
    if ($backupFile.Length -eq 0) {
        throw "Attributes backup is empty: $backupPath"
    }
    Write-Host "Backup created: $backupPath"
    Write-Host "Backup bytes: $($backupFile.Length)"

    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    foreach ($path in @($sqlPath, $viewPath)) {
        Get-Content -Raw -Encoding UTF8 -LiteralPath $path |
            & $mysqlClientPath `
                "--host=$env:DB_HOST" `
                "--port=$env:DB_PORT" `
                "--user=$env:DB_USER" `
                "--database=$env:DB_NAME" `
                '--default-character-set=utf8mb4'
        if ($LASTEXITCODE -ne 0) {
            throw "Attributes migration failed: $path. Backup retained at: $backupPath"
        }
    }

    python -X utf8 -B -m diagnostics.verify_team_attributes_migration --after $snapshotPath
    if ($LASTEXITCODE -ne 0) {
        throw "Attributes verification failed. Backup retained at: $backupPath"
    }
    Write-Host 'Team attributes minimal migration completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Pop-Location
    $OutputEncoding = $previousOutputEncoding
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
