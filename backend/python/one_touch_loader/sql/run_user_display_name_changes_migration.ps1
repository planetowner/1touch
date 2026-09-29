$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_user_display_name_changes import verify_schema
run_migration(
    name="user_display_name_changes", tables=("users",),
    sql_paths=(Path("one_touch_loader/sql/migrate_user_display_name_changes.sql"),),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) { throw 'User display-name migration failed. Check the retained backup.' }
}
finally { Pop-Location }
