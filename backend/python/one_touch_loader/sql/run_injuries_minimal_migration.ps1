$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_injuries import verify_schema

run_migration(
    name="injuries_minimal",
    tables=("team_player_injuries",),
    sql_paths=(
        Path("one_touch_loader/sql/create_team_player_injuries.sql"),
        Path("one_touch_loader/sql/migrate_injuries_minimal.sql"),
    ),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) {
        throw "Injuries migration failed with exit code $LASTEXITCODE. Check the output and retained backup."
    }
}
finally {
    Pop-Location
}
