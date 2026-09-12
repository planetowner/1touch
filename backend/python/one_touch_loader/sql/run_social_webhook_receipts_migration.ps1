$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_social_webhook_receipts import verify_schema
run_migration(
    name="social_webhook_receipts", tables=("kakao_webhook_receipts",),
    sql_paths=(Path("one_touch_loader/sql/migrate_social_webhook_receipts.sql"),),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) { throw 'Social webhook migration failed. Check the retained backup.' }
}
finally { Pop-Location }
