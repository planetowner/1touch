$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_understat import verify_player_ids_schema

# 기존 변경과 같은 사전 확인·백업·실행·사후 확인 순서로 진행해요.
run_migration(
    name="player_external_ids_aliases",
    tables=("player_external_ids",),
    sql_paths=(Path("one_touch_loader/sql/migrate_player_external_ids_aliases.sql"),),
    verify_schema=verify_player_ids_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) {
        throw "Player external IDs migration failed. Check the output and retained backup."
    }
}
finally {
    Pop-Location
}
