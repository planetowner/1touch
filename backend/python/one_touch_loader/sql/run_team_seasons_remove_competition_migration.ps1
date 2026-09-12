$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'migrate_team_seasons_remove_competition.sql'
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
$backupPath = Join-Path $backupDirectory 'before_team_seasons_remove_competition.sql'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$env:MYSQL_PWD = $env:DB_PASSWORD
try {
    $expectedColumnCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'team_seasons' AND ((column_name = 'team_id' AND column_type = 'bigint unsigned' AND is_nullable = 'NO') OR (column_name = 'season_id' AND column_type = 'bigint unsigned' AND is_nullable = 'NO') OR (column_name = 'competition_id' AND column_type = 'bigint unsigned' AND is_nullable = 'NO'))"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "team_seasons column preflight failed with exit code $LASTEXITCODE"
    }
    if ($expectedColumnCount.Count -ne 1 -or $expectedColumnCount[0] -ne '3') {
        throw 'team_seasons does not have the expected three-column schema'
    }

    $unexpectedColumnCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'team_seasons' AND column_name NOT IN ('team_id', 'season_id', 'competition_id')"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "team_seasons extra-column preflight failed with exit code $LASTEXITCODE"
    }
    if ($unexpectedColumnCount.Count -ne 1 -or $unexpectedColumnCount[0] -ne '0') {
        throw 'team_seasons contains an unexpected column'
    }

    $invalidRowCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM team_seasons LEFT JOIN teams ON teams.team_id = team_seasons.team_id LEFT JOIN seasons ON seasons.season_id = team_seasons.season_id WHERE teams.team_id IS NULL OR seasons.season_id IS NULL OR team_seasons.competition_id <> seasons.competition_id"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "team_seasons data preflight failed with exit code $LASTEXITCODE"
    }
    if ($invalidRowCount.Count -ne 1 -or $invalidRowCount[0] -ne '0') {
        throw "team_seasons contains invalid relationships: $($invalidRowCount[0])"
    }

    $duplicateCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM (SELECT team_id, season_id FROM team_seasons GROUP BY team_id, season_id HAVING COUNT(*) > 1) AS duplicates"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "team_seasons duplicate preflight failed with exit code $LASTEXITCODE"
    }
    if ($duplicateCount.Count -ne 1 -or $duplicateCount[0] -ne '0') {
        throw "team_seasons contains duplicate team-season relationships: $($duplicateCount[0])"
    }

    $expectedIndexCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM (SELECT index_name, GROUP_CONCAT(column_name ORDER BY seq_in_index) AS indexed_columns FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'team_seasons' GROUP BY index_name) AS indexes WHERE (index_name = 'PRIMARY' AND indexed_columns = 'team_id,season_id') OR (index_name = 'idx_ts_season' AND indexed_columns = 'season_id') OR (index_name = 'idx_ts_competition_season' AND indexed_columns = 'competition_id,season_id')"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "team_seasons index preflight failed with exit code $LASTEXITCODE"
    }
    if ($expectedIndexCount.Count -ne 1 -or $expectedIndexCount[0] -ne '3') {
        throw 'team_seasons indexes do not match the expected schema'
    }

    $foreignKeyCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.key_column_usage WHERE constraint_schema = DATABASE() AND table_name = 'team_seasons' AND referenced_table_name IS NOT NULL"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "team_seasons foreign-key preflight failed with exit code $LASTEXITCODE"
    }
    if ($foreignKeyCount.Count -ne 1 -or $foreignKeyCount[0] -ne '0') {
        throw 'team_seasons already has foreign keys; inspect them before migration'
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

    Get-Content -Raw -LiteralPath $sqlPath |
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME"
    if ($LASTEXITCODE -ne 0) {
        throw "team_seasons migration failed with exit code $LASTEXITCODE. Restore from: $backupPath"
    }

    Write-Host 'team_seasons migration completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
