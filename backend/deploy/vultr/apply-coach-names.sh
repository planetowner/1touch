#!/usr/bin/env bash
set -euo pipefail

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
server=ubuntu@3.39.136.116
runtime=/opt/1touch/backend/deploy/vultr
ssh_options=(-i "$HOME/.ssh/onetouch-lightsail-seoul.pem" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no)
locale_group=ko
apply=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --locale-group)
      locale_group=${2:-}
      [[ "$locale_group" == ko || "$locale_group" == ja-zh ]] || { echo 'Expected ko or ja-zh' >&2; exit 1; }
      shift 2 ;;
    --apply) apply=true; shift ;;
    *) echo 'Usage: bash apply-coach-names.sh [--locale-group ko|ja-zh] [--apply]' >&2; exit 1 ;;
  esac
done

# 기존 API 이미지에서도 검토한 파일을 임시 경로에서 실행할 수 있게 전달해요.
payload() {
  python3 - "$repository/backend/python" "$locale_group" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
group = sys.argv[2]
paths = (
    "diagnostics/migrate_coach_names.py",
    f"diagnostics/coach_names.{group}.json",
    f"one_touch_loader/sql/migrate_coach_names_{group.replace('-', '_')}.sql",
)
print(json.dumps({path: (root / path).read_text(encoding="utf-8") for path in paths}))
PY
}

remote_code=$(cat <<'PY'
import json, pathlib, runpy, sys, tempfile
from contextlib import closing
from diagnostics import migrate_sportmonks_names as shared
from one_touch_loader.core.db import get_conn

with tempfile.TemporaryDirectory(prefix="coach-names-") as folder:
    root = pathlib.Path(folder)
    for relative, content in json.load(sys.stdin).items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    migration = runpy.run_path(str(root / "diagnostics/migrate_coach_names.py"))
    config = migration["configuration"](sys.argv[2])
    options = dict(entities=migration["reviewed_rows"](sys.argv[2]), specs=config["specs"], locales=config["locales"])
    ready, summary = shared.preview(**options)
    print(json.dumps(dict(schema_ready=ready, tables=summary), ensure_ascii=False), flush=True)
    if sys.argv[1] == "apply" and any(row["updates"] for row in summary.values()):
        with closing(get_conn()) as conn:
            if not ready:
                with conn.cursor() as cursor:
                    cursor.execute(config["sql_path"].read_text(encoding="utf-8"))
                conn.commit()
            shared.migrate_data(conn, **options)
        shared.verify_schema(before=False, specs=options["specs"], locales=options["locales"])
        _, after = shared.preview(**options)
        if any(row["updates"] for row in after.values()):
            raise ValueError("Saved names differ from reviewed values")
        print(json.dumps(dict(verified=after), ensure_ascii=False), flush=True)
PY
)

run_names() {
  payload | ssh "${ssh_options[@]}" "$server" \
    "cd $runtime && sudo -n bash compose-production.sh exec -T api python -B -c '$remote_code' $1 $locale_group"
}

run_names preview
if [[ $apply == true ]]; then
  # API 컨테이너에는 mysqldump가 없어 기존 서버 백업 명령으로 먼저 백업해요.
  ssh "${ssh_options[@]}" "$server" "sudo -n bash $runtime/backup-db.sh"
  run_names apply
fi
