$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$createSqlPath = Join-Path $PSScriptRoot 'migrate_countries_create.sql'
$foreignKeySqlPath = Join-Path $PSScriptRoot 'migrate_countries_add_fk.sql'
$mysqlClientPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$mysqlDumpPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe'

foreach ($requiredPath in @(
    $envPath,
    $createSqlPath,
    $foreignKeySqlPath,
    $mysqlClientPath,
    $mysqlDumpPath
)) {
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
$backupPath = Join-Path $backupDirectory 'before_countries_migration.sql'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$env:MYSQL_PWD = $env:DB_PASSWORD
$previousPythonPath = $env:PYTHONPATH

try {
    $countriesTableCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'countries'"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Countries table preflight failed with exit code $LASTEXITCODE"
    }
    if ($countriesTableCount.Count -ne 1 -or $countriesTableCount[0] -ne '0') {
        throw 'countries table already exists'
    }

    $nationalityColumnCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'players' AND column_name = 'nationality_id' AND column_type = 'bigint unsigned' AND is_nullable = 'YES'"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Players nationality preflight failed with exit code $LASTEXITCODE"
    }
    if ($nationalityColumnCount.Count -ne 1 -or $nationalityColumnCount[0] -ne '1') {
        throw 'players.nationality_id does not have the expected nullable BIGINT UNSIGNED type'
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

    Get-Content -Raw -LiteralPath $createSqlPath |
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME"
    if ($LASTEXITCODE -ne 0) {
        throw "Countries table creation failed with exit code $LASTEXITCODE. Restore from: $backupPath"
    }

    $env:PYTHONPATH = Join-Path $backendRoot 'python'
    Push-Location $backendRoot
    try {
        python -m one_touch_loader.cli countries refresh
        if ($LASTEXITCODE -ne 0) {
            throw "Countries loader failed with exit code $LASTEXITCODE. Restore from: $backupPath"
        }
    }
    finally {
        Pop-Location
    }

    $orphanNationalityCount = @(
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME" `
            '--batch' `
            '--skip-column-names' `
            "--execute=SELECT COUNT(*) FROM players LEFT JOIN countries ON countries.country_id = players.nationality_id WHERE players.nationality_id IS NOT NULL AND countries.country_id IS NULL"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Nationality coverage check failed with exit code $LASTEXITCODE"
    }
    if ($orphanNationalityCount.Count -ne 1 -or $orphanNationalityCount[0] -ne '0') {
        throw "Players contain nationality IDs missing from countries: $($orphanNationalityCount[0])"
    }

    Get-Content -Raw -LiteralPath $foreignKeySqlPath |
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME"
    if ($LASTEXITCODE -ne 0) {
        throw "Countries foreign-key migration failed with exit code $LASTEXITCODE. Restore from: $backupPath"
    }

    Write-Host 'Countries migration completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    if ($null -eq $previousPythonPath) {
        Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
    }
    else {
        $env:PYTHONPATH = $previousPythonPath
    }
}
