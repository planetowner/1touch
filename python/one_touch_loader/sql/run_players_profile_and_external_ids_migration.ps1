$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'migrate_players_profile_and_external_ids.sql'
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
$backupPath = Join-Path $backupDirectory 'before_players_profile_and_external_ids_migration.sql'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$env:MYSQL_PWD = $env:DB_PASSWORD

try {
    $playerColumns = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT column_name FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'players' ORDER BY ordinal_position"
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Players schema preflight failed with exit code $LASTEXITCODE"
    }

    $expectedPlayerColumns = @(
        'player_id',
        'position_id',
        'firstname',
        'lastname',
        'name',
        'display_name'
    )
    if (($playerColumns -join ',') -ne ($expectedPlayerColumns -join ',')) {
        throw "Unexpected players columns: $($playerColumns -join ', ')"
    }

    $externalTableCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'player_external_ids'"
    )

    if ($LASTEXITCODE -ne 0) {
        throw "External-ID table preflight failed with exit code $LASTEXITCODE"
    }
    if ($externalTableCount.Count -ne 1 -or $externalTableCount[0] -ne '0') {
        throw "player_external_ids already exists"
    }

    $invalidRequiredPlayers = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM players WHERE display_name IS NULL OR TRIM(display_name) = '' OR name IS NULL OR TRIM(name) = '' OR position_id IS NULL"
    )

    if ($LASTEXITCODE -ne 0) {
        throw "Players data preflight failed with exit code $LASTEXITCODE"
    }
    if ($invalidRequiredPlayers.Count -ne 1 -or $invalidRequiredPlayers[0] -ne '0') {
        throw "Players contain missing display_name, name, or position_id values"
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
        throw "Database migration failed with exit code $LASTEXITCODE. Restore from: $backupPath"
    }

    Write-Host 'Players profile and external-ID migration completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
