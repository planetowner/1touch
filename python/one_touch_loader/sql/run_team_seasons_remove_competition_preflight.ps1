$ErrorActionPreference = 'Stop'

$backendRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$envPath = Join-Path $backendRoot '.env'
$sqlPath = Join-Path $PSScriptRoot 'preflight_team_seasons_remove_competition.sql'
$mysqlClientPath = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'

foreach ($requiredPath in @($envPath, $sqlPath, $mysqlClientPath)) {
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
    Get-Content -Raw -LiteralPath $sqlPath |
        & $mysqlClientPath `
            "--host=$env:DB_HOST" `
            "--port=$env:DB_PORT" `
            "--user=$env:DB_USER" `
            "--database=$env:DB_NAME"

    if ($LASTEXITCODE -ne 0) {
        throw "team_seasons preflight failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
