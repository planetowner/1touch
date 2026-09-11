"""운영 서버를 건드리지 않고 실제 Caddy와 Compose로 경계를 검사해요."""
from __future__ import annotations

import base64
import http.server
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request


deploy = Path(__file__).resolve().parents[1]
caddy, compose = map(str, map(Path.resolve, map(Path, sys.argv[1:3])))
password = "test-only-not-an-operational-password"
hashed = subprocess.run([caddy, "hash-password"], input=password + "\n", text=True, capture_output=True, check=True).stdout.strip()


class Upstream(http.server.BaseHTTPRequestHandler):
    calls = 0

    def do_GET(self):
        type(self).calls += 1
        payload = json.dumps({"ok": True, "scheme": self.headers.get("X-Forwarded-Proto"), "authorization": self.headers.get("Authorization")}).encode()
        self.send_response(401 if self.path == '/v1/home' and self.headers.get('Authorization') != 'Bearer test-session' else 200)
        self.end_headers()
        self.wfile.write(payload)

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def log_message(self, *args):
        pass


with tempfile.TemporaryDirectory(prefix="onetouch-proxy-test-") as temporary:
    root = Path(temporary)
    env_file = root / "test.env"
    env_file.write_text(f"COLLAB_PASSWORD_HASH='{hashed}'\nSES_FEEDBACK_EMAIL='operator@example.com'\n")
    environment = {
        **os.environ,
        "MYSQL_PASSWORD": "test-only",
        "MYSQL_ROOT_PASSWORD": "test-only-root",
        "RELEASE_TAG": "test",
        "API_DOMAIN": "api.example.test",
        "COLLAB_USER": "developer",
        "COLLAB_PASSWORD_HASH": hashed,
        "XDG_DATA_HOME": str(root / "data"),
        "XDG_CONFIG_HOME": str(root / "config"),
    }
    result = subprocess.run([
        compose, "--env-file", str(env_file), "-f", str(deploy / "compose.yaml"),
        "-f", str(deploy / "compose.production.yaml"), "config", "--format", "json",
    ], env={key: value for key, value in environment.items() if key != "COLLAB_PASSWORD_HASH"}, capture_output=True, text=True, check=True)
    model = json.loads(result.stdout)
    # Compose config는 재사용 가능한 출력에서 달러 기호를 두 번 써요.
    assert model["services"]["proxy"]["environment"]["COLLAB_PASSWORD_HASH"] == hashed.replace("$", "$$")
    assert model["name"] == "onetouch-dev"
    assert model["volumes"]["mysql_data"]["name"] == "onetouch-dev_mysql_data"
    for service in ("db", "api"):
        assert all(port["host_ip"] == "127.0.0.1" for port in model["services"][service]["ports"])
    api = model["services"]["api"]
    # 설정 파일 저장에 성공해도 API 환경에 빠지면 인증 메일이 503으로 실패해요.
    assert api["environment"]["SES_FEEDBACK_EMAIL"] == "operator@example.com"
    assert not any(mount["target"] == "/app/python" for mount in api["volumes"])
    assert "--reload" not in api["command"] and api["user"] == "1001:1001"
    assert {port["published"] for port in model["services"]["proxy"]["ports"]} == {"80", "443"}
    assert all(service["logging"]["options"]["max-file"] == "3" for service in model["services"].values())
    print("PASS: existing DB volume, private API/DB ports, non-root immutable API and bounded logs")

    # 실제 운영 설정도 먼저 검증한 뒤, 이 PC만 사용하는 TLS 테스트 주소로 바꿔요.
    subprocess.run([caddy, "validate", "--config", str(deploy / "Caddyfile"), "--adapter", "caddyfile"], env=environment, capture_output=True, check=True)
    upstream = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
    thread = threading.Thread(target=upstream.serve_forever, daemon=True)
    thread.start()
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        proxy_port = reservation.getsockname()[1]
    configuration = deploy.joinpath("Caddyfile").read_text()
    configuration = configuration.replace("{$API_DOMAIN} {", "{$API_DOMAIN} {\n\tbind 127.0.0.1\n\ttls internal", 1)
    configuration = configuration.replace("reverse_proxy api:8000", f"reverse_proxy 127.0.0.1:{upstream.server_port}")
    configuration = "{\n admin off\n skip_install_trust\n auto_https disable_redirects\n}\n" + configuration
    test_config = root / "Caddyfile"
    test_config.write_text(configuration)
    environment["API_DOMAIN"] = f"localhost:{proxy_port}"
    with (root / "caddy.log").open("w") as logs:
        process = subprocess.Popen([caddy, "run", "--config", str(test_config)], env=environment, stdout=logs, stderr=logs)
        try:
            certificate = root / "data/caddy/pki/authorities/local/root.crt"
            deadline = time.monotonic() + 15
            while not certificate.exists() and time.monotonic() < deadline and process.poll() is None:
                time.sleep(0.1)
            assert certificate.exists(), (root / "caddy.log").read_text()
            # 시스템 신뢰 저장소는 변경하지 않고 이 테스트의 CA만 요청에 지정해요.
            context = ssl.create_default_context(cafile=str(certificate))

            def request(path, headers=None, method="GET"):
                req = urllib.request.Request(f"https://localhost:{proxy_port}{path}", headers=headers or {}, method=method)
                try:
                    with urllib.request.urlopen(req, context=context, timeout=5) as response:
                        return response.status, response.read()
                except urllib.error.HTTPError as exc:
                    return exc.code, exc.read()

            # CA 파일이 생긴 직후에는 서버 인증서 발급이 아직 끝나지 않을 수 있어요.
            while True:
                try:
                    assert request("/v1/health")[0] == 200
                    break
                except urllib.error.URLError:
                    if time.monotonic() >= deadline or process.poll() is not None:
                        raise
                    time.sleep(0.1)
            assert request("/v1/auth/providers?country_code=KR")[0] == 200
            before = Upstream.calls
            assert request("/docs")[0] == 401
            assert request("/docs", {"Authorization": "Basic " + base64.b64encode(b"developer:wrong").decode()})[0] == 401
            assert Upstream.calls == before
            # 앱 인증은 백엔드 책임이며 Bearer 헤더를 그대로 전달해야 해요.
            assert request("/v1/home", {"X-User-Id": "123"})[0] == 401
            assert Upstream.calls == before + 1
            status, body = request("/v1/home", {"Authorization": "Bearer test-session"})
            assert status == 200 and json.loads(body)["authorization"] == "Bearer test-session"
            credentials = base64.b64encode(f"developer:{password}".encode()).decode()
            status, body = request("/docs", {"Authorization": f"Basic {credentials}"})
            assert status == 200 and json.loads(body)["scheme"] == "https"
            assert request("/v1/home", method="OPTIONS")[0] == 204
            print("PASS: verified local TLS, unauthenticated/spoofed/wrong-password requests blocked, authenticated proxy and OPTIONS")
        except Exception:
            print((root / "caddy.log").read_text(), file=sys.stderr)
            raise
        finally:
            process.terminate()
            process.wait(timeout=10)
            upstream.shutdown()
