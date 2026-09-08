$ErrorActionPreference = 'Stop'

$backendRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'reset_capology_player_ids.sql'
$timestamp = Get-Date -Format 'yyyyMMddTHHmmss'
$backupDirectory = Join-Path $backendRoot "logs\database-backups\$timestamp"
$backupPath = Join-Path $backupDirectory 'before_capology_player_ids_reset.sql'
$backupErrorPath = Join-Path $backupDirectory 'before_capology_player_ids_reset.stderr.log'
$mysqlClientPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$mysqldumpPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe'

if (-not (Test-Path -LiteralPath $envPath)) {
    throw ".env not found: $envPath"
}
if (-not (Test-Path -LiteralPath $sqlPath)) {
    throw "SQL file not found: $sqlPath"
}
if (-not (Test-Path -LiteralPath $mysqlClientPath)) {
    throw "MySQL client not found: $mysqlClientPath"
}
if (-not (Test-Path -LiteralPath $mysqldumpPath)) {
    throw "mysqldump not found: $mysqldumpPath"
}

Get-Content -LiteralPath $envPath |
    Where-Object { $_ -match '^\s*[^#][^=]*=' } |
    ForEach-Object {
        $pair = $_ -split '=', 2
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

$requiredVariables = @('DB_HOST', 'DB_PORT', 'DB_USER', 'DB_PASSWORD', 'DB_NAME')
foreach ($variableName in $requiredVariables) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($variableName, 'Process'))) {
        throw "Missing environment variable: $variableName"
    }
}

New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
$env:MYSQL_PWD = $env:DB_PASSWORD

try {
    $dumpArguments = @(
        "--host=$env:DB_HOST",
        "--port=$env:DB_PORT",
        "--user=$env:DB_USER",
        '--single-transaction',
        '--routines',
        '--triggers',
        $env:DB_NAME
    )

    $dumpProcess = Start-Process `
        -FilePath $mysqldumpPath `
        -ArgumentList $dumpArguments `
        -Wait `
        -PassThru `
        -NoNewWindow `
        -RedirectStandardOutput $backupPath `
        -RedirectStandardError $backupErrorPath

    if ($dumpProcess.ExitCode -ne 0) {
        throw "Database backup failed with exit code $($dumpProcess.ExitCode). See: $backupErrorPath"
    }

    $backupBytes = (Get-Item -LiteralPath $backupPath).Length
    if ($backupBytes -le 0) {
        throw "Database backup is empty: $backupPath"
    }

    Write-Host "Backup created: $backupPath"
    Write-Host "Backup bytes: $backupBytes"

    Get-Content -Raw -LiteralPath $sqlPath |
        & $mysqlClientPath `
            --host=$env:DB_HOST `
            --port=$env:DB_PORT `
            --user=$env:DB_USER `
            --database=$env:DB_NAME

    if ($LASTEXITCODE -ne 0) {
        throw "Capology player-ID reset failed with exit code $LASTEXITCODE"
    }

    Write-Host 'Capology player-ID reset completed.'
    Write-Host "Backup retained at: $backupPath"
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
