$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_user_community import OLD, verify_schema
run_migration(
    name="user_community_minimal", tables=tuple(OLD),
    sql_paths=(Path("one_touch_loader/sql/migrate_user_community_minimal.sql"),),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) { throw 'User/community migration failed. Check the retained backup.' }
}
finally { Pop-Location }
