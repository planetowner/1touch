$ErrorActionPreference = 'Stop'
$pythonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Push-Location -LiteralPath $pythonRoot
try {
    # DB 설정과 연결은 기존 Python 모듈을 써서 환경 파일 해석을 중복하지 않아요.
    @'
from pathlib import Path
from diagnostics.run_minimal_migration import run_migration
from diagnostics.verify_best_eleven_migration import verify_schema

run_migration(
    name="best_eleven_minimal",
    tables=("team_best_eleven_formations", "team_best_eleven"),
    sql_paths=(Path("one_touch_loader/sql/migrate_best_eleven_minimal.sql"),),
    verify_schema=verify_schema,
)
'@ | python -X utf8 -B -
    if ($LASTEXITCODE -ne 0) {
        throw "Best Eleven migration failed with exit code $LASTEXITCODE. Check the output and retained backup."
    }
}
finally {
    Pop-Location
}
