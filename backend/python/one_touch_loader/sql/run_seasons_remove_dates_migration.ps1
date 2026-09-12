$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'migrate_seasons_remove_dates.sql'
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
$backupPath = Join-Path $backupDirectory 'before_seasons_remove_dates_migration.sql'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$env:MYSQL_PWD = $env:DB_PASSWORD

try {
    $seasonDateColumns = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT column_name FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'seasons' AND column_name IN ('starting_at', 'ending_at') ORDER BY FIELD(column_name, 'starting_at', 'ending_at')"
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Database preflight failed with exit code $LASTEXITCODE"
    }

    if (
        $seasonDateColumns.Count -ne 2 -or
        $seasonDateColumns[0] -ne 'starting_at' -or
        $seasonDateColumns[1] -ne 'ending_at'
    ) {
        throw "Unexpected seasons date columns: $($seasonDateColumns -join ', ')"
    }

    $invalidSeasonNames = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT CONCAT(season_id, ':', name) FROM seasons WHERE name NOT REGEXP '^[0-9]{4}/[0-9]{4}$' OR CAST(RIGHT(name, 4) AS UNSIGNED) <> CAST(LEFT(name, 4) AS UNSIGNED) + 1 ORDER BY season_id"
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Season-name preflight failed with exit code $LASTEXITCODE"
    }

    if ($invalidSeasonNames.Count -ne 0) {
        throw "Invalid season names prevent date removal: $($invalidSeasonNames -join ', ')"
    }

    & $mysqlDumpPath `
        "--host=$env:DB_HOST" `
        "--port=$env:DB_PORT" `
        "--user=$env:DB_USER" `
        "--default-character-set=utf8mb4" `
        "--single-transaction" `
        "--routines" `
        "--triggers" `
        "--events" `
        "--no-tablespaces" `
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
        throw "Database migration failed with exit code $LASTEXITCODE. Restore from: $backupPath"
    }

    Write-Host 'Seasons date-column migration completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
