$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_transfers_contracts import verify_schema

run_migration(
    name="transfers_contracts_minimal",
    tables=("team_transfers", "transfer_windows"),
    sql_paths=(
        Path("one_touch_loader/sql/migrate_transfers_contracts_minimal.sql"),
        Path("one_touch_loader/sql/create_transfers.sql"),
        Path("one_touch_loader/sql/create_player_contracts.sql"),
    ),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) {
        throw "Transfers/contracts migration failed. Check the output and retained backup."
    }
}
finally {
    Pop-Location
}
