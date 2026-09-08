$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$backupPath = Join-Path $backendRoot (
    'logs\database-backups\20260811T025847\before_team_season_data_reset.sql'
)
$mysqlClientPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$restoreDatabase = '1touch_restore_20260811'

foreach ($requiredPath in @($envPath, $backupPath, $mysqlClientPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing required file: $requiredPath"
    }
}

$backupFile = Get-Item -LiteralPath $backupPath
if ($backupFile.Length -ne 166279420) {
    throw (
        "Backup size does not match the verified dump: " +
        "expected=166279420 actual=$($backupFile.Length) path=$backupPath"
    )
}

if ($restoreDatabase -notmatch '^[A-Za-z0-9_]+$') {
    throw "Unsafe restore database name: $restoreDatabase"
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

foreach ($requiredVariable in @('DB_HOST', 'DB_PORT', 'DB_USER', 'DB_PASSWORD')) {
    $value = [Environment]::GetEnvironmentVariable($requiredVariable, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required environment variable: $requiredVariable"
    }
}

function Invoke-MySqlScalar {
    param(
        [Parameter(Mandatory = $false)]
        [string] $Database,

        [Parameter(Mandatory = $true)]
        [string] $Sql
    )

    $arguments = @(
        "--host=$env:DB_HOST",
        "--port=$env:DB_PORT",
        "--user=$env:DB_USER",
        '--batch',
        '--skip-column-names',
        "--execute=$Sql"
    )
    if (-not [string]::IsNullOrWhiteSpace($Database)) {
        $arguments += "--database=$Database"
    }

    $rows = @(& $mysqlClientPath @arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "MySQL query failed with exit code $LASTEXITCODE"
    }
    if ($rows.Count -ne 1) {
        throw "Expected one scalar row, found $($rows.Count): $Sql"
    }

    return $rows[0].Trim()
}

$env:MYSQL_PWD = $env:DB_PASSWORD
try {
    $existingDatabaseCount = Invoke-MySqlScalar -Sql (
        "SELECT COUNT(*) FROM information_schema.schemata " +
        "WHERE schema_name = '$restoreDatabase'"
    )
    if ($existingDatabaseCount -ne '0') {
        throw (
            "Restore database already exists. Nothing was changed: " +
            $restoreDatabase
        )
    }

$quotedRestoreDatabase = [char]96 + $restoreDatabase + [char]96
    $createDatabaseSql = (
        "CREATE DATABASE $quotedRestoreDatabase " +
        'CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci'
    )
    & $mysqlClientPath `
        "--host=$env:DB_HOST" `
        "--port=$env:DB_PORT" `
        "--user=$env:DB_USER" `
        "--execute=$createDatabaseSql"
    if ($LASTEXITCODE -ne 0) {
        throw "Restore database creation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Restore database created: $restoreDatabase"
    Write-Host "Source database was not selected or modified: $env:DB_NAME"

    $restoreArguments = @(
        "--host=$env:DB_HOST",
        "--port=$env:DB_PORT",
        "--user=$env:DB_USER",
        "--database=$restoreDatabase",
        '--default-character-set=utf8mb4'
    )
    $restoreProcess = Start-Process `
        -FilePath $mysqlClientPath `
        -ArgumentList $restoreArguments `
        -RedirectStandardInput $backupPath `
        -NoNewWindow `
        -Wait `
        -PassThru
    if ($restoreProcess.ExitCode -ne 0) {
        throw (
            "Restore failed with exit code $($restoreProcess.ExitCode). " +
            "The source database was not modified. " +
            "The partial restore database was retained for inspection: " +
            $restoreDatabase
        )
    }

    $expectedCounts = [ordered]@{
        seasons = 109
        teams = 929
        team_seasons = 972
        fixtures = 24958
        fixture_lineups = 115273
        fixture_team_stats_raw = 950986
        standings = 1700
        xg_standings = 876
        knockout_ties = 2208
        points_pace = 32222
        team_best_eleven = 6732
        team_best_eleven_formations = 612
    }

    foreach ($entry in $expectedCounts.GetEnumerator()) {
        $actualCount = Invoke-MySqlScalar `
            -Database $restoreDatabase `
            -Sql "SELECT COUNT(*) FROM ``$($entry.Key)``"
        if ($actualCount -ne [string]$entry.Value) {
            throw (
                "Restored row count mismatch: table=$($entry.Key) " +
                "expected=$($entry.Value) actual=$actualCount"
            )
        }
        Write-Host (
            "Verified table=$($entry.Key) rows=$actualCount"
        )
    }

    $historicalSeasonCount = Invoke-MySqlScalar `
        -Database $restoreDatabase `
        -Sql (
            "SELECT COUNT(*) FROM seasons " +
            "WHERE season_id IN (6397, 6405, 8026, 8442, 8557) " +
            "AND competition_id IN (8, 82, 301, 384, 564) " +
            "AND name = '2017/2018'"
        )
    if ($historicalSeasonCount -ne '5') {
        throw (
            "Big 5 2017/2018 season verification failed: " +
            "expected=5 actual=$historicalSeasonCount"
        )
    }

    Write-Host 'Verified Big 5 2017/2018 seasons: 5'
    Write-Host "Restore completed: $restoreDatabase"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
