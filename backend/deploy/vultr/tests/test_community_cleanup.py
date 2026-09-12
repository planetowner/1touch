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
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copy2(source / "cleanup-community.sh", root / "cleanup-community.sh")
            # Docker·DB·R2 대신 인수를 출력하는 공통 명령만 모사해요.
            (root / "compose-production.sh").write_text('printf "%s\\n" "$@"\nexit "${TEST_EXIT:-0}"\n', encoding="utf-8")
            for arguments in ([], ["--check"], ["--apply", "--limit", "1000"]):
                with self.subTest(arguments=arguments):
                    result = subprocess.run([bash, "cleanup-community.sh", *arguments], cwd=root, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.splitlines(), ["run", "--rm", "--no-deps", "-T", "api", "python", "-m", "one_touch_loader.cli", "community", "cleanup", *arguments])
            failed = subprocess.run([bash, "cleanup-community.sh", "--apply"], cwd=root, env={**os.environ, "TEST_EXIT": "9"}, capture_output=True)
            self.assertEqual(failed.returncode, 9)


if __name__ == "__main__":
    unittest.main()
