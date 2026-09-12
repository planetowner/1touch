$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'migrate_fixtures_aggregates.sql'
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
$backupPath = Join-Path $backupDirectory 'before_fixtures_aggregates_migration.sql'
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
            "--execute=SELECT CONCAT(column_name, ':', column_type, ':', is_nullable) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'fixtures' ORDER BY ordinal_position"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Fixtures schema preflight failed with exit code $LASTEXITCODE"
    }

    $expectedFixtureColumns = @(
        'fixture_id:bigint unsigned:NO',
        'stage_id:int:NO',
        'round_id:int:YES',
        'group_id:int:YES',
        'leg_number:tinyint unsigned:NO',
        'home_team_id:bigint unsigned:NO',
        'away_team_id:bigint unsigned:NO',
        'starting_at:datetime:YES',
        'venue_id:bigint unsigned:YES',
        'state_id:int unsigned:NO',
        'home_score:smallint unsigned:YES',
        'away_score:smallint unsigned:YES',
        'home_penalty_score:smallint unsigned:YES',
        'away_penalty_score:smallint unsigned:YES'
    )
    if (($fixtureColumns -join ',') -ne ($expectedFixtureColumns -join ',')) {
        throw "Unexpected fixtures columns: $($fixtureColumns -join ', ')"
    }

    $stageColumns = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT column_name FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'stages' ORDER BY ordinal_position"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Stages schema preflight failed with exit code $LASTEXITCODE"
    }
    $expectedStageColumns = @('stage_id', 'season_id', 'stage_type_id', 'name')
    if (($stageColumns -join ',') -ne ($expectedStageColumns -join ',')) {
        throw 'Run the stages normalized migration before this migration'
    }

    $aggregateTableCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'aggregates'"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Aggregates preflight failed with exit code $LASTEXITCODE"
    }
    if ($aggregateTableCount.Count -ne 1 -or $aggregateTableCount[0] -ne '0') {
        throw 'aggregates table already exists'
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
    if ($fixtureRows.Count -ne 1) {
        throw "Unexpected fixtures row-count result: $($fixtureRows -join ', ')"
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
    if ($knockoutTieRows.Count -ne 1) {
        throw "Unexpected knockout_ties row-count result: $($knockoutTieRows -join ', ')"
    }

    $legConstraintCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_schema = DATABASE() AND table_name = 'fixtures' AND constraint_name = 'chk_fixtures_leg_number' AND constraint_type = 'CHECK'"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Fixture leg constraint preflight failed with exit code $LASTEXITCODE"
    }
    if ($legConstraintCount.Count -ne 1 -or $legConstraintCount[0] -ne '1') {
        throw 'chk_fixtures_leg_number is missing'
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
    Write-Host "Fixture rows to replace: $($fixtureRows[0])"
    Write-Host "Inferred knockout-tie rows to replace: $($knockoutTieRows[0])"

    Get-Content -Raw -LiteralPath $sqlPath |
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME"
    if ($LASTEXITCODE -ne 0) {
        throw "Database migration failed with exit code $LASTEXITCODE. Restore from: $backupPath"
    }

    Write-Host 'Fixtures and aggregates migration completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
