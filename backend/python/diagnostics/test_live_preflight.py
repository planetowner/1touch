"""서버 점검이 키를 출력하지 않고, 실패하면 배포 전에 멈추는지 확인해요."""
import contextlib
import io
from pathlib import Path
import unittest
from unittest.mock import patch

import requests

from one_touch_loader.core.sportmonks import LIVE_FIXTURE_INCLUDE, SportmonksClient


PROBE = (Path(__file__).resolve().parents[2] / "deploy/vultr/check-live-fixtures.ps1").read_text(encoding="utf-8").split("@'\n", 1)[1].split("\n'@", 1)[0]


class LivePreflightTests(unittest.TestCase):
    @patch.object(SportmonksClient, "_get")
    @patch.dict("os.environ", {"SPORTMONKS_API_TOKEN": ""})
    def test_missing_key_stops_without_provider_request(self, read):
        with self.assertRaisesRegex(SystemExit, "TOKEN is empty"):
            exec(PROBE, {})
        read.assert_not_called()

    @patch.object(SportmonksClient, "_get", return_value={"data": []})
    @patch.dict("os.environ", {"SPORTMONKS_API_TOKEN": "test-secret-not-for-output"})
    def test_success_checks_runtime_includes_and_never_prints_key(self, read):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            exec(PROBE, {})
        read.assert_called_once_with("livescores", params={"include": LIVE_FIXTURE_INCLUDE})
        self.assertIn("HTTP 200", output.getvalue())
        self.assertNotIn("test-secret", output.getvalue())

    @patch.object(SportmonksClient, "_get")
    @patch.dict("os.environ", {"SPORTMONKS_API_TOKEN": "test-secret-not-for-output"})
    def test_denied_or_unreachable_provider_stops_without_dumping_response(self, read):
        response = requests.Response()
        response.status_code = 403
        for error in (requests.HTTPError("private response", response=response), requests.Timeout("private response")):
            read.side_effect = error
            with self.subTest(error=type(error).__name__), self.assertRaises(SystemExit) as failure:
                exec(PROBE, {})
            self.assertIn("No changes made", str(failure.exception))
            self.assertNotIn("private response", str(failure.exception))


if __name__ == "__main__":
    unittest.main()
