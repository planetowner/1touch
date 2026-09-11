"""Linux 임시 폴더와 모의 Docker로 API 중지 시점·키 정리를 확인해요."""
import os
from pathlib import Path
import subprocess
import tempfile

scripts = Path(__file__).resolve().parents[1]


def verify(service, source_name, credential_name, scenario):
    with tempfile.TemporaryDirectory(prefix="onetouch-prepare-") as directory:
        root = Path(directory)
        runtime = root / "runtime"
        runtime.mkdir()
        (runtime / ".env.production").write_text("API_DOMAIN=api.example.test\n")
        (root / credential_name).write_text("test placeholder\n")
        (runtime / "compose-production.sh").write_text('''#!/bin/bash
case "$*" in
  'ps -q api') echo test-api;;
  'stop api') echo stop >> "$TEST_TRACE";;
  *) exit 88;;
esac
''')
        script = root / "prepare.sh"
        script.write_text((scripts / source_name).read_text())
        helper = (scripts / "prepare-service-settings.sh").read_text().replace(
            "runtime_directory=/opt/1touch/backend/deploy/vultr", 'runtime_directory="$TEST_RUNTIME"')
        (root / "prepare-service-settings.sh").write_text(helper)
        docker = root / "docker"
        docker.write_text('''#!/bin/bash
if [[ "$1" == inspect ]]; then echo test-image; exit 0; fi
if [[ "$*" == *"/input/configure_${TEST_SERVICE}.py"* ]]; then
  echo configure >> "$TEST_TRACE"
  [[ "$TEST_SCENARIO" != configure ]] || exit 42
else
  cat >/dev/null
  echo check >> "$TEST_TRACE"
  [[ "$TEST_SCENARIO" != check ]] || exit 42
fi
''')
        docker.chmod(0o700)
        trace = root / "trace"
        result = subprocess.run(["bash", str(script)], capture_output=True, text=True, env={
            **os.environ, "PATH": f"{root}:{os.environ['PATH']}", "TEST_RUNTIME": str(runtime),
            "TEST_TRACE": str(trace), "TEST_SCENARIO": scenario, "TEST_SERVICE": service,
        })
        assert (result.returncode == 0) == (scenario == "success"), result.stderr
        assert not (root / credential_name).exists()
        assert (root / "before.env.production").read_text() == (runtime / ".env.production").read_text()
        stages = trace.read_text().splitlines()
        assert ("stop" in stages) == (scenario == "success" and source_name == "prepare-user-community.sh"), stages


for service, script, credential in (
    ("ses", "prepare-user-community.sh", "smtp.csv"),
    ("ses", "prepare-ses.sh", "ses.env"),
    ("r2", "prepare-r2.sh", "r2.env"),
    ("google", "prepare-google.sh", "google.env"),
    ("apple", "prepare-apple.sh", "apple.env"),
    ("kakao", "prepare-kakao.sh", "kakao.env"),
    ("community", "prepare-community.sh", "community.env"),
):
    for scenario in ("success", "configure", "check"):
        verify(service, script, credential, scenario)
print("PASS: shared settings backup, temporary key cleanup, stop on failure; only SES initial migration preparation stops API (21 mocked cases)")
