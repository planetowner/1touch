#!/usr/bin/env bash
set -euo pipefail

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
server=ubuntu@3.39.136.116
runtime=/opt/1touch/backend/deploy/vultr
ssh_options=(-i "$HOME/.ssh/onetouch-lightsail-seoul.pem" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no)
if [[ $# -gt 1 || ( $# -eq 1 && $1 != --apply ) ]]; then
  echo 'Usage: bash apply-coach-names.sh [--apply]' >&2
  exit 1
fi

# 기존 API 이미지에서도 검토한 파일을 임시 경로에서 실행할 수 있게 전달해요.
payload() {
  python3 - "$repository/backend/python" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
paths = (
    "diagnostics/migrate_coach_names_ko.py",
    "diagnostics/coach_names.ko.json",
    "one_touch_loader/sql/migrate_coach_names_ko.sql",
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
    migration = runpy.run_path(str(root / "diagnostics/migrate_coach_names_ko.py"))
    options = dict(entities=migration["reviewed_rows"](), specs=migration["SPECS"], locales=migration["LOCALES"])
    ready, summary = shared.preview(**options)
    print(json.dumps(dict(schema_ready=ready, tables=summary), ensure_ascii=False), flush=True)
    if sys.argv[1] == "apply" and any(row["updates"] for row in summary.values()):
        with closing(get_conn()) as conn:
            if not ready:
                with conn.cursor() as cursor:
                    cursor.execute(migration["SQL_PATH"].read_text(encoding="utf-8"))
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
    "cd $runtime && sudo -n bash compose-production.sh exec -T api python -B -c '$remote_code' $1"
}

run_names preview
if [[ ${1:-} == --apply ]]; then
  # API 컨테이너에는 mysqldump가 없어 기존 서버 백업 명령으로 먼저 백업해요.
  ssh "${ssh_options[@]}" "$server" "sudo -n bash $runtime/backup-db.sh"
  run_names apply
fi
