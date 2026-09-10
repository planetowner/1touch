"""Linux 임시 폴더와 모의 Docker로 API 중지 시점·키 정리를 확인해요."""
import os
from pathlib import Path
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1] / "prepare-user-community.sh"
for scenario in ("success", "configure", "smtp"):
    with tempfile.TemporaryDirectory(prefix="onetouch-prepare-") as directory:
        root = Path(directory)
        runtime = root / "runtime"
        runtime.mkdir()
        (runtime / ".env.production").write_text("API_DOMAIN=api.example.test\n")
        (root / "smtp.csv").write_text("test placeholder\n")
        (runtime / "compose-production.sh").write_text('''#!/bin/bash
case "$*" in
  'ps -q api') echo test-api;;
  'stop api') echo stop >> "$TEST_TRACE";;
  *) exit 88;;
esac
''')
        script = root / "prepare.sh"
        text = source.read_text().replace("runtime_directory=/opt/1touch/backend/deploy/vultr", 'runtime_directory="$TEST_RUNTIME"')
        script.write_text(text)
        docker = root / "docker"
        docker.write_text('''#!/bin/bash
if [[ "$1" == inspect ]]; then echo test-image; exit 0; fi
if [[ "$*" == *'/input/configure_ses.py'* ]]; then
  echo configure >> "$TEST_TRACE"
  [[ "$TEST_SCENARIO" != configure ]] || exit 42
else
  cat >/dev/null
  echo smtp >> "$TEST_TRACE"
  [[ "$TEST_SCENARIO" != smtp ]] || exit 42
fi
''')
        docker.chmod(0o700)
        trace = root / "trace"
        result = subprocess.run(["bash", str(script)], capture_output=True, text=True, env={
            **os.environ, "PATH": f"{root}:{os.environ['PATH']}", "TEST_RUNTIME": str(runtime),
            "TEST_TRACE": str(trace), "TEST_SCENARIO": scenario,
        })
        assert (result.returncode == 0) == (scenario == "success"), result.stderr
        assert not (root / "smtp.csv").exists()
        assert (root / "before.env.production").read_text() == (runtime / ".env.production").read_text()
        stages = trace.read_text().splitlines()
        assert ("stop" in stages) == (scenario == "success"), stages
print("PASS: settings backup, temporary credential cleanup and no API stop before successful SMTP authentication (mocked)")
