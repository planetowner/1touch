$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_community_rules import verify_schema
run_migration(
    name="community_rules_languages", tables=("community_rules",),
    sql_paths=(Path("one_touch_loader/sql/migrate_community_rules_languages.sql"),),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) { throw 'Community rules migration failed. Check the retained backup.' }
}
finally { Pop-Location }
