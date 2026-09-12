$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'migrate_stages_normalized.sql'
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
$backupPath = Join-Path $backupDirectory 'before_stages_normalized_migration.sql'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$env:MYSQL_PWD = $env:DB_PASSWORD

try {
    $stageColumns = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT CONCAT(column_name, ':', column_type, ':', is_nullable) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'stages' ORDER BY ordinal_position"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Stages schema preflight failed with exit code $LASTEXITCODE"
    }

    $legacyStageColumns = @(
        'stage_id:int:NO',
        'competition_id:int:NO',
        'season_id:int:NO',
        'type_id:int:NO',
        'name:varchar(128):NO'
    )
    $normalizedStageColumns = @(
        'stage_id:int:NO',
        'season_id:bigint unsigned:NO',
        'stage_type_id:int:NO',
        'name:varchar(128):NO'
    )

    $stageTypesTableCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'stage_types'"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Stage-types preflight failed with exit code $LASTEXITCODE"
    }
    if (
        ($stageColumns -join ',') -eq ($normalizedStageColumns -join ',') -and
        $stageTypesTableCount.Count -eq 1 -and
        $stageTypesTableCount[0] -eq '1'
    ) {
        $stageTypeRows = @(
            & $mysqlClientPath `
                "--host=$env:DB_HOST" `
                "--port=$env:DB_PORT" `
                "--user=$env:DB_USER" `
                "--database=$env:DB_NAME" `
                '--batch' `
                '--skip-column-names' `
                "--execute=SELECT CONCAT(stage_type_id, ':', code, ':', name) FROM stage_types ORDER BY stage_type_id"
        )
        if ($LASTEXITCODE -ne 0) {
            throw "Stage-types verification failed with exit code $LASTEXITCODE"
        }

        $expectedStageTypeRows = @(
            '223:group-stage:GROUP_STAGE',
            '224:knock-out:KNOCK_OUT',
            '225:qualifying:QUALIFYING'
        )
        if (($stageTypeRows -join ',') -ne ($expectedStageTypeRows -join ',')) {
            throw "Unexpected stage_types rows: $($stageTypeRows -join ', ')"
        }

        Write-Host 'Stages normalized migration already applied.'
        return
    }

    if (($stageColumns -join ',') -ne ($legacyStageColumns -join ',')) {
        throw "Unexpected stages columns: $($stageColumns -join ', ')"
    }
    if ($stageTypesTableCount.Count -ne 1 -or $stageTypesTableCount[0] -ne '0') {
        throw 'stage_types table already exists'
    }

    $unknownStageTypes = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            '--execute=SELECT DISTINCT type_id FROM stages WHERE type_id NOT IN (223,224,225) ORDER BY type_id'
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Stage-type coverage check failed with exit code $LASTEXITCODE"
    }
    if ($unknownStageTypes.Count -ne 0) {
        throw "Unknown stage type IDs prevent migration: $($unknownStageTypes -join ', ')"
    }

    $invalidStageRelations = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT st.stage_id FROM stages st LEFT JOIN seasons s ON s.season_id = st.season_id WHERE s.season_id IS NULL OR s.competition_id <> st.competition_id ORDER BY st.stage_id"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Stage relation check failed with exit code $LASTEXITCODE"
    }
    if ($invalidStageRelations.Count -ne 0) {
        throw "Invalid stage-season relations prevent migration: $($invalidStageRelations -join ', ')"
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

    Write-Host 'Stages normalized migration completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
