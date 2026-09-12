"""사용자가 허용한 시즌들을 순서대로 적재하고 시즌별 DB 검증을 실행해요."""

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from verify_fixture_details_season_log import verify_season_log


def main() -> None:
    python_dir = Path(__file__).resolve().parents[1]
    reports = python_dir.parent / "logs/diagnostics/fixture-details-season-run"
    reports.mkdir(parents=True, exist_ok=True)
    for season in sys.argv[1:]:
        stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S-%f")[:-3]
        pending = Path(r"C:\dev\terminal-logs") / f"{stamp}.pending"
        finished = pending.with_suffix(".log")
        print(f"SEASON START {season} log={pending}", flush=True)
        # 기존 PowerShell 모니터와 같은 UTF-16 로그·종료 시 이름 변경 규칙을 사용해요.
        with pending.open("x", encoding="utf-16", newline="") as log:
            log.write(f"PS {python_dir}> python -m one_touch_loader.cli fixture-details '{season}'\r\n")
            log.flush()
            env = dict(os.environ, PYTHONIOENCODING="utf-8")
            process = subprocess.Popen(
                [sys.executable, "-u", "-m", "one_touch_loader.cli", "fixture-details", season],
                cwd=python_dir, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding="utf-8",
            )
            for index, line in enumerate(process.stdout, start=1):
                log.write(line.rstrip("\r\n") + "\r\n")
                log.flush()
                if index == 1 or index % 100 == 0 or not line.startswith("[fixture-details "):
                    print(f"{season} {line.rstrip()}", flush=True)
            exit_code = process.wait()
        pending.rename(finished)
        # 실제 적재 오류를 건너뛰지 않고 멈춰야 원인을 고친 뒤 같은 시즌을 재실행할 수 있어요.
        if exit_code != 0:
            raise SystemExit(f"SEASON FAILED {season} exit={exit_code} log={finished}")
        result = verify_season_log(finished)
        report = reports / f"verified-{season.replace('/', '-')}.json"
        report.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"SEASON VERIFIED {season} fixtures={result['fixtures']} report={report}", flush=True)
    print("ALL REQUESTED SEASONS VERIFIED", flush=True)


if __name__ == "__main__":
    main()
