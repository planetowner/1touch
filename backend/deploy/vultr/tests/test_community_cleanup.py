"""예약 정리가 실제 서버에 접속하지 않고 공통 Compose와 같은 옵션을 쓰는지 확인해요."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class CleanupCommandTests(unittest.TestCase):
    def test_manual_preview_and_scheduled_apply_preserve_arguments_and_exit_code(self):
        source = Path(__file__).resolve().parents[1]
        bash = r"C:\Program Files\Git\bin\bash.exe" if os.name == "nt" else shutil.which("bash")
        cases = (
            ("cleanup-community.sh", ["community", "cleanup"], [[], ["--check"], ["--apply", "--limit", "1000"]]),
            ("sync-live-fixtures.sh", ["fixtures", "live"], [[], ["--apply"]]),
            ("sync-opta.sh", ["opta-shots", "sync", "--dataset", "both", "--recent-days", "7", "--refresh-details", "--output-dir", "/app/logs/opta-sync"], [[], ["--check"], ["--apply"]]),
        )
        for script, command, argument_sets in cases:
            with self.subTest(script=script), tempfile.TemporaryDirectory() as directory:
                self.check_command(source, bash, script, command, argument_sets, directory)

    def check_command(self, source, bash, script, command, argument_sets, directory):
        root = Path(directory)
        shutil.copy2(source / script, root / script)
        # Docker·DB·R2 대신 인수를 출력하는 공통 명령만 모사해요.
        (root / "compose-production.sh").write_text('printf "%s\\n" "$@"\nexit "${TEST_EXIT:-0}"\n', encoding="utf-8")
        for arguments in argument_sets:
            with self.subTest(arguments=arguments):
                result = subprocess.run([bash, script, *arguments], cwd=root, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), ["run", "--rm", "--no-deps", "-T", "api", "python", "-m", "one_touch_loader.cli", *command, *arguments])
        failed = subprocess.run([bash, script, "--apply"], cwd=root, env={**os.environ, "TEST_EXIT": "9"}, capture_output=True)
        self.assertEqual(failed.returncode, 9)


if __name__ == "__main__":
    unittest.main()
