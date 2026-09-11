$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_user_community import COLUMNS
from diagnostics.verify_community_management import verify_schema
run_migration(
    name="community_management", tables=tuple(COLUMNS),
    sql_paths=(Path("one_touch_loader/sql/migrate_community_management.sql"),),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) { throw 'Community management migration failed. Check the retained backup.' }
}
finally { Pop-Location }
