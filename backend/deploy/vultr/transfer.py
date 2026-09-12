from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
from datetime import datetime, timezone


BACKEND_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(BACKEND_ROOT / "python"))

def snapshot_database() -> dict:
    # 코드만 묶을 때는 DB 접속이나 SSH 터널이 필요 없어요.
    from one_touch_loader.core.db import get_conn

    connection = get_conn()
    try:
        connection.start_transaction(consistent_snapshot=True, readonly=True)
        with connection.cursor() as cursor:
            cursor.execute("SELECT VERSION(), @@lower_case_table_names, @@time_zone, @@system_time_zone")
            version, case_mode, time_zone, system_time_zone = cursor.fetchone()
            cursor.execute(
                "SELECT TABLE_NAME, TABLE_TYPE FROM information_schema.TABLES "
                "WHERE TABLE_SCHEMA = DATABASE() ORDER BY TABLE_NAME"
            )
            objects = cursor.fetchall()
            counts = {}
            views = []
            for name, kind in objects:
                if kind == "VIEW":
                    views.append(name)
                else:
                    identifier = name.replace("`", "``")
                    cursor.execute(f"SELECT COUNT(*) FROM `{identifier}`")
                    counts[name] = cursor.fetchone()[0]
        return {
            "mysql_version": version,
            "lower_case_table_names": case_mode,
            "time_zone": time_zone,
            "system_time_zone": system_time_zone,
            "tables": counts,
            "views": views,
        }
    finally:
        connection.rollback()
        connection.close()


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def export_transfer(output: Path, mysqldump: Path) -> None:
    from one_touch_loader.core.db import DB_CONFIG

    mysqldump = mysqldump.resolve(strict=True)
    before = snapshot_database()
    output.mkdir(parents=True, exist_ok=False)
    sql_path = output / "database.sql"
    process_env = os.environ.copy()
    # 암호를 명령행이나 출력에 남기지 않고 이 자식 프로세스에만 전달해요.
    process_env["MYSQL_PWD"] = DB_CONFIG["password"]
    arguments = [
        str(mysqldump),
        "--no-defaults",
        f"--host={DB_CONFIG['host']}",
        f"--port={DB_CONFIG['port']}",
        f"--user={DB_CONFIG['user']}",
        "--single-transaction", "--quick", "--no-tablespaces",
        "--set-gtid-purged=OFF", "--default-character-set=utf8mb4",
        "--skip-add-drop-table", "--hex-blob", "--routines", "--events", "--triggers",
        DB_CONFIG["database"],
    ]
    with sql_path.open("wb") as stream:
        subprocess.run(arguments, env=process_env, stdout=stream, check=True)
    after = snapshot_database()
    if before != after:
        raise RuntimeError("Source metadata or row counts changed during export. Pause loaders and export again.")
    dump_path = output / "database.sql.gz"
    with sql_path.open("rb") as source, gzip.open(dump_path, "wb") as target:
        while chunk := source.read(1024 * 1024):
            target.write(chunk)
    sql_path.unlink()

    archive_path = output / "backend.tar.gz"
    archive_backend(archive_path)
    manifest = {
        "exported_at_utc": datetime.now(timezone.utc).isoformat(),
        "database": before,
        "files": {path.name: sha256(path) for path in (dump_path, archive_path)},
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(output), "tables": len(before["tables"]), "views": len(before["views"]), "files": manifest["files"]}))


def archive_backend(archive_path: Path) -> None:
    with tarfile.open(archive_path, "w:gz") as archive:
        # 작업 폴더의 코드를 담아 커밋 전 변경도 포함하고, 인증 정보와 로그는 제외해요.
        for item in ("python", "deploy", "requirements.txt", ".dockerignore", "README_repro.md"):
            root = BACKEND_ROOT / item
            paths = sorted(root.rglob("*")) if root.is_dir() else [root]
            for path in paths:
                if not path.is_file():
                    continue
                relative = path.relative_to(BACKEND_ROOT)
                if any(part in {"__pycache__", "backups"} or part.startswith(".env") for part in relative.parts):
                    continue
                archive.add(path, arcname=str(relative), recursive=False)


def export_code(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=False)
    archive_path = output / "backend.tar.gz"
    archive_backend(archive_path)
    manifest = {
        "exported_at_utc": datetime.now(timezone.utc).isoformat(),
        "files": {archive_path.name: sha256(archive_path)},
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(output), "files": manifest["files"]}))


def verify_transfer(manifest_path: Path) -> None:
    expected = json.loads(manifest_path.read_text(encoding="utf-8"))["database"]
    actual = snapshot_database()
    # Windows와 Linux의 시간대 표시 이름은 달라서 서버의 TZ 설정은 별도로 확인해요.
    differences = {
        key: {"expected": expected[key], "actual": actual[key]}
        for key in ("mysql_version", "lower_case_table_names", "time_zone", "tables", "views")
        if expected[key] != actual[key]
    }
    if differences:
        raise RuntimeError(json.dumps(differences, ensure_ascii=False))
    print(json.dumps({"status": "PASS", "tables": len(actual["tables"]), "views": len(actual["views"]), "mysql_version": actual["mysql_version"], "system_time_zone": actual["system_time_zone"]}))


def main() -> None:
    parser = argparse.ArgumentParser(description="Export a development database or verify its restored copy.")
    commands = parser.add_subparsers(dest="command", required=True)
    export = commands.add_parser("export")
    export.add_argument("--output", type=Path, required=True)
    export.add_argument("--mysqldump", type=Path, required=True)
    code = commands.add_parser("code", help="Package the current code without connecting to a database.")
    code.add_argument("--output", type=Path, required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("manifest", type=Path)
    args = parser.parse_args()
    if args.command == "export":
        export_transfer(args.output.resolve(), args.mysqldump)
    elif args.command == "code":
        export_code(args.output.resolve())
    else:
        verify_transfer(args.manifest)


if __name__ == "__main__":
    main()
