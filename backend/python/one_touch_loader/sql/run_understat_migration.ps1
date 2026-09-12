$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_understat import OLD_TABLES, verify_schema

run_migration(
    name="understat_minimal",
    tables=OLD_TABLES,
    sql_paths=(Path("one_touch_loader/sql/migrate_understat_minimal.sql"),),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) {
        throw "Understat migration failed. Check the output and retained backup."
    }
}
finally {
    Pop-Location
}
