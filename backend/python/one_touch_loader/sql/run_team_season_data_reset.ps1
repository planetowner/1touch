# 과거 스키마의 전체 초기화 기록이에요. 현재 DB에는 실행하지 않아요.
# 이후 경기 상세·attributes·Understat 변경으로 대상 테이블 구성이 달라졌어요.
$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'reset_team_season_data.sql'
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

$resetTables = @(
    'fixture_formations',
    'fixture_lineups',
    'fixture_team_stats_raw',
    'fixtures',
    'aggregates',
    'player_team_honours',
    'player_wages',
    'stage_groups',
    'stages',
    'standings',
    'team_attribute_group_scores',
    'team_attribute_features',
    'team_attribute_regression_weights',
    'team_attribute_regression_models',
    'team_best_eleven',
    'team_best_eleven_formations',
    'team_highlights_cache',
    'team_player_injuries',
    'team_seasons',
    'team_squad_members',
    'team_transfers',
    'team_youtube_playlists',
    'team_youtube_sources',
    'transfer_windows',
    'understat_season_map',
    'understat_team_map',
    'user_following_teams',
    'xg_standings',
    'xg_standings_calibration',
    'seasons',
    'teams'
)
$tableNamesSql = ($resetTables | ForEach-Object { "'$_'" }) -join ','
$expectedTableCount = [string]$resetTables.Count

$timestamp = Get-Date -Format 'yyyyMMddTHHmmss'
$backupDirectory = Join-Path $backendRoot "logs\database-backups\$timestamp"
$backupPath = Join-Path $backupDirectory 'before_team_season_data_reset.sql'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$env:MYSQL_PWD = $env:DB_PASSWORD
try {
    $existingTableCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE' AND table_name IN ($tableNamesSql)"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Reset table preflight failed with exit code $LASTEXITCODE"
    }
    if (
        $existingTableCount.Count -ne 1 -or
        $existingTableCount[0] -ne $expectedTableCount
    ) {
        throw "Reset table preflight found $($existingTableCount[0]) of $($resetTables.Count) required tables"
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
        throw "Team-season data reset failed with exit code $LASTEXITCODE. Restore from: $backupPath"
    }

    Write-Host 'Team-season data reset completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
