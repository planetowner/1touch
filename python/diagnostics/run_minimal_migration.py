"""검증한 최소 스키마 변경의 사전 확인·백업·실행·사후 확인 순서를 공유해요."""
from __future__ import annotations

import os
import subprocess
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from one_touch_loader.core.db import DB_CONFIG, get_conn


def run_migration(*, name: str, tables: tuple[str, ...], sql_paths: tuple[Path, ...], verify_schema):
    # 기존 Best Eleven과 부상 변경은 대상만 다르고 실행 순서는 같아요.
    verify_schema(before=True)
    root = Path(__file__).resolve().parents[2]
    folder = root / "logs/database-backups" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    folder.mkdir(parents=True)
    backup = folder / f"before_{name}.sql"
    dump = Path(r"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe")
    subprocess.run([
        str(dump), f"--host={DB_CONFIG['host']}", f"--port={DB_CONFIG['port']}",
        f"--user={DB_CONFIG['user']}", "--default-character-set=utf8mb4",
        "--single-transaction", "--no-tablespaces", f"--result-file={backup}",
        DB_CONFIG["database"], *tables,
    ], env={**os.environ, "MYSQL_PWD": DB_CONFIG["password"]}, check=True)
    if backup.stat().st_size == 0:
        raise RuntimeError(f"Empty backup: {backup}")
    print(f"Backup created: {backup}", flush=True)
    print(f"Backup bytes: {backup.stat().st_size}", flush=True)

    # MySQL DDL은 전체 롤백되지 않으므로 실패해도 앞서 만든 백업을 남겨요.
    # 호출부에서 지정한 DDL 파일만 순서대로 실행하며 SQL에 프로시저는 없어요.
    with closing(get_conn()) as conn:
        with conn.cursor() as cursor:
            for path in sql_paths:
                for statement in path.read_text(encoding="utf-8").split(";"):
                    if statement.strip():
                        cursor.execute(statement)
        conn.commit()
    verify_schema(before=False)
    print(f"{name} migration completed.")
    print(f"Backup retained at: {backup}")
