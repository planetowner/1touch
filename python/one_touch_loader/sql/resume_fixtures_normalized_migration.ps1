$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'resume_fixtures_normalized_migration.sql'
$mysqlClientPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$backupPath = Join-Path $backendRoot (
    'logs\database-backups\20260812T195108\' +
    'before_fixtures_normalized_migration.sql'
)

foreach ($requiredPath in @($envPath, $sqlPath, $mysqlClientPath, $backupPath)) {
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

$env:MYSQL_PWD = $env:DB_PASSWORD

try {
    $tableState = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT CONCAT(table_name, ':', table_rows) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN ('fixtures','rounds','venues','fixture_states') ORDER BY table_name"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Table-state preflight failed with exit code $LASTEXITCODE"
    }
    $expectedTableState = @(
        'fixture_states:0',
        'rounds:0',
        'venues:0'
    )
    if (($tableState -join ',') -ne ($expectedTableState -join ',')) {
        throw "Unexpected partial migration tables: $($tableState -join ', ')"
    }

    $supportingColumns = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT CONCAT(table_name, ':', GROUP_CONCAT(column_name ORDER BY ordinal_position SEPARATOR ',')) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name IN ('rounds','venues','fixture_states') GROUP BY table_name ORDER BY table_name"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Supporting-column preflight failed with exit code $LASTEXITCODE"
    }
    $expectedSupportingColumns = @(
        'fixture_states:state_id,state_code,name',
        'rounds:round_id,stage_id,name',
        'venues:venue_id,name'
    )
    if (($supportingColumns -join ';') -ne ($expectedSupportingColumns -join ';')) {
        throw "Unexpected supporting-table columns: $($supportingColumns -join '; ')"
    }

    $rawState = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT CONCAT((SELECT COUNT(*) FROM fixture_team_stats_raw), ':', (SELECT COUNT(*) FROM information_schema.key_column_usage WHERE constraint_schema = DATABASE() AND referenced_table_name = 'fixtures'))"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Raw-stats preflight failed with exit code $LASTEXITCODE"
    }
    if ($rawState.Count -ne 1 -or $rawState[0] -ne '0:0') {
        throw "Unexpected fixture_team_stats_raw state: $($rawState -join ', ')"
    }

    Get-Content -Raw -LiteralPath $sqlPath |
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME"
    if ($LASTEXITCODE -ne 0) {
        throw "Fixtures migration resume failed with exit code $LASTEXITCODE"
    }

    Write-Host 'Fixtures normalized migration resumed and completed.'
    Write-Host "Original backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
