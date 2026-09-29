$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_unique_user_display_name import verify_schema
run_migration(
    name="unique_user_display_name", tables=("users",),
    sql_paths=(Path("one_touch_loader/sql/migrate_unique_user_display_name.sql"),),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) { throw 'Nickname uniqueness migration failed. Check the retained backup.' }
}
finally { Pop-Location }
