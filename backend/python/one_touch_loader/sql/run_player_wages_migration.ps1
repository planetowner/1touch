$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'create_player_wages.sql'
$mysqlClientPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$mysqlDumpPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe'

foreach ($requiredPath in @($envPath, $sqlPath, $mysqlClientPath, $mysqlDumpPath)) {
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
$backupPath = Join-Path $backupDirectory 'before_player_wages_migration.sql'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$env:MYSQL_PWD = $env:DB_PASSWORD

try {
    $preflightRows = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'player_wage_estimates'), (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'player_wages')"
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Player wages preflight failed with exit code $LASTEXITCODE"
    }

    if ($preflightRows.Count -ne 1) {
        throw "Unexpected preflight output: $($preflightRows -join ', ')"
    }

    $preflightValues = $preflightRows[0] -split "`t"
    if (
        $preflightValues.Count -ne 2 -or
        $preflightValues[0] -ne '1' -or
        $preflightValues[1] -ne '0'
    ) {
        throw (
            'Expected player_wage_estimates to exist and player_wages to be absent. ' +
            "Actual: $($preflightValues -join ', ')"
        )
    }

    $oldRowCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            '--execute=SELECT COUNT(*) FROM player_wage_estimates'
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Old player wage row check failed with exit code $LASTEXITCODE"
    }

    if ($oldRowCount.Count -ne 1 -or $oldRowCount[0] -ne '0') {
        throw "player_wage_estimates must be empty. Actual rows: $($oldRowCount -join ', ')"
    }

    & $mysqlDumpPath `
        "--host=$env:DB_HOST" `
        "--port=$env:DB_PORT" `
        "--user=$env:DB_USER" `
        '--default-character-set=utf8mb4' `
        '--single-transaction' `
        '--routines' `
        '--triggers' `
        '--events' `
        '--no-tablespaces' `
        "--result-file=$backupPath" `
        $env:DB_NAME

    if ($LASTEXITCODE -ne 0) {
        throw "Database backup failed with exit code $LASTEXITCODE"
    }

    $backupFile = Get-Item -LiteralPath $backupPath
    if ($backupFile.Length -eq 0) {
        throw "Database backup is empty: $backupPath"
    }

    Write-Host "Backup created: $backupPath"
    Write-Host "Backup bytes: $($backupFile.Length)"

    $migrationSql = @(
        'DROP TABLE player_wage_estimates;'
        Get-Content -Raw -LiteralPath $sqlPath
    ) -join "`r`n"

    $migrationSql |
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME"

    if ($LASTEXITCODE -ne 0) {
        throw "Player wages migration failed with exit code $LASTEXITCODE. Restore from: $backupPath"
    }

    $postflightRows = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'player_wage_estimates'), (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'player_wages'), (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'player_wages')"
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Player wages verification failed with exit code $LASTEXITCODE"
    }

    if ($postflightRows.Count -ne 1) {
        throw "Unexpected verification output: $($postflightRows -join ', ')"
    }

    $postflightValues = $postflightRows[0] -split "`t"
    if (
        $postflightValues.Count -ne 3 -or
        $postflightValues[0] -ne '0' -or
        $postflightValues[1] -ne '1' -or
        $postflightValues[2] -ne '4'
    ) {
        throw "Unexpected player_wages schema state: $($postflightValues -join ', ')"
    }

    Write-Host 'Player wages migration completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
