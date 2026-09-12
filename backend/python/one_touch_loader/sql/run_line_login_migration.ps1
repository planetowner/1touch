$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_line_login import verify_schema
run_migration(
    name="line_login", tables=("user_social_identities",),
    sql_paths=(Path("one_touch_loader/sql/migrate_line_login.sql"),),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) { throw 'LINE login migration failed. Check the retained backup.' }
}
finally { Pop-Location }
