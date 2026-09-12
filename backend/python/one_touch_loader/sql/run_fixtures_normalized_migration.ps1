$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'migrate_fixtures_normalized.sql'
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
$backupPath = Join-Path $backupDirectory 'before_fixtures_normalized_migration.sql'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$env:MYSQL_PWD = $env:DB_PASSWORD

try {
    $fixtureColumns = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT column_name FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'fixtures' ORDER BY ordinal_position"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Fixtures schema preflight failed with exit code $LASTEXITCODE"
    }

    $expectedFixtureColumns = @(
        'fixture_id',
        'season_id',
        'competition_id',
        'home_team_id',
        'away_team_id',
        'round_name',
        'stage_type_id',
        'stage_id',
        'group_id',
        'leg_number',
        'status',
        'starting_at',
        'home_score',
        'away_score',
        'home_penalty_score',
        'away_penalty_score'
    )
    if (($fixtureColumns -join ',') -ne ($expectedFixtureColumns -join ',')) {
        throw "Unexpected fixtures columns: $($fixtureColumns -join ', ')"
    }

    $fixtureRows = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            '--execute=SELECT COUNT(*) FROM fixtures'
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Fixtures row-count preflight failed with exit code $LASTEXITCODE"
    }
    if ($fixtureRows.Count -ne 1 -or $fixtureRows[0] -ne '0') {
        throw "fixtures must be empty before this migration; found=$($fixtureRows -join ',')"
    }

    $statsRows = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            '--execute=SELECT COUNT(*) FROM fixture_team_stats_raw'
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Fixture stats row-count preflight failed with exit code $LASTEXITCODE"
    }
    if ($statsRows.Count -ne 1 -or $statsRows[0] -ne '0') {
        throw "fixture_team_stats_raw must be empty before this migration"
    }

    $knockoutTieRows = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            '--execute=SELECT COUNT(*) FROM knockout_ties'
    )
    if ($LASTEXITCODE -ne 0) {
        throw "knockout_ties preflight failed with exit code $LASTEXITCODE"
    }
    if ($knockoutTieRows.Count -ne 1 -or $knockoutTieRows[0] -ne '0') {
        throw "knockout_ties must be empty before replacing it with provider aggregates"
    }

    $fixtureForeignKeys = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT CONCAT(table_name, ':', constraint_name) FROM information_schema.key_column_usage WHERE constraint_schema = DATABASE() AND referenced_table_name = 'fixtures' ORDER BY table_name, constraint_name"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Fixtures foreign-key preflight failed with exit code $LASTEXITCODE"
    }
    if (
        $fixtureForeignKeys.Count -ne 1 -or
        $fixtureForeignKeys[0] -ne 'fixture_team_stats_raw:fk_ftsr_fixture'
    ) {
        throw "Unexpected foreign keys referencing fixtures: $($fixtureForeignKeys -join ', ')"
    }

    $newTableCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN ('aggregates','rounds','venues','fixture_states')"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Related-table preflight failed with exit code $LASTEXITCODE"
    }
    if ($newTableCount.Count -ne 1 -or $newTableCount[0] -ne '0') {
        throw "aggregates, rounds, venues, or fixture_states already exists"
    }

    $requiredParentCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN ('stages','stage_groups','teams')"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Parent-table preflight failed with exit code $LASTEXITCODE"
    }
    if ($requiredParentCount.Count -ne 1 -or $requiredParentCount[0] -ne '3') {
        throw "stages, stage_groups, and teams must exist"
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

    Write-Host 'Fixtures normalized migration completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
