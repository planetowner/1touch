$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_account_management import verify_schema
run_migration(
    name="account_management", tables=("users", "email_verification_codes"),
    sql_paths=(Path("one_touch_loader/sql/migrate_account_management.sql"),),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) { throw 'Account management migration failed. Check the retained backup.' }
}
finally { Pop-Location }
