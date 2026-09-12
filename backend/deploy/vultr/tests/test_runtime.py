from __future__ import annotations

import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient
from mysql.connector import OperationalError

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "python"))
# 이 검사는 실제 DB나 사용자를 만들지 않고 요청 처리만 확인해요.
with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api import main


class RuntimeTests(unittest.TestCase):
    def test_readiness_reads_database(self):
        with patch.object(main, "fetch_one_dict", return_value={"ok": 1}) as query:
            response = TestClient(main.create_app()).get("/v1/ready")
        self.assertEqual(response.status_code, 200)
        query.assert_called_once_with("SELECT 1 AS ok")

    def test_database_failure_is_unready_without_disclosing_error(self):
        with patch.object(main, "fetch_one_dict", side_effect=OperationalError("private connection detail")):
            response = TestClient(main.create_app()).get("/v1/ready")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json(), {"detail": "Database unavailable"})

    def test_liveness_does_not_read_database(self):
        with patch.object(main, "fetch_one_dict") as query:
            response = TestClient(main.create_app()).get("/v1/health")
        self.assertEqual(response.json(), {"ok": True})
        query.assert_not_called()

    def test_web_origin_allowlist(self):
        with patch.dict(os.environ, {"API_CORS_ORIGINS": "https://app.example.test"}):
            client = TestClient(main.create_app())
        headers = {
            "Origin": "https://app.example.test",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization,x-user-id",
        }
        allowed = client.options("/v1/health", headers=headers)
        denied = client.options("/v1/health", headers={**headers, "Origin": "https://other.example.test"})
        self.assertEqual(allowed.status_code, 200)
        self.assertEqual(allowed.headers["access-control-allow-origin"], headers["Origin"])
        self.assertEqual(denied.status_code, 400)
        self.assertNotIn("access-control-allow-origin", denied.headers)

    def test_mobile_only_configuration_has_no_browser_origin(self):
        with patch.dict(os.environ, {"API_CORS_ORIGINS": ""}):
            client = TestClient(main.create_app())
        response = client.get("/v1/health", headers={"Origin": "https://other.example.test"})
        self.assertEqual(response.status_code, 200)
        self.assertNotIn("access-control-allow-origin", response.headers)


if __name__ == "__main__":
    unittest.main()
