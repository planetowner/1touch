"""Google Web Client 설정과 토큰 암호화 키를 기존 운영 설정에 저장해요."""
import argparse
import json
from pathlib import Path

from cryptography.fernet import Fernet
from environment_settings import read_environment, save_settings


def configure_calendar(env_file: Path, client_json: Path) -> None:
    current = read_environment(env_file)
    client = json.loads(client_json.read_text(encoding="utf-8"))["web"]
    client_id, secret = client["client_id"].strip(), client["client_secret"].strip()
    if not client_id.endswith(".apps.googleusercontent.com") or not secret:
        raise ValueError("Google Web Client JSON 파일을 확인해 주세요.")
    allowed = [value.strip() for value in current.get("GOOGLE_CLIENT_IDS", "").split(",")]
    if client_id not in allowed:
        raise ValueError("현재 Google 로그인에 등록한 Web Client ID를 사용해 주세요.")
    # 설정을 다시 적용해도 기존 갱신 토큰을 읽을 수 있도록 암호화 키를 유지해요.
    key = current.get("CALENDAR_TOKEN_ENCRYPTION_KEY") or Fernet.generate_key().decode()
    Fernet(key.encode())
    save_settings(env_file, {"GOOGLE_CALENDAR_CLIENT_ID": client_id,
        "GOOGLE_CALENDAR_CLIENT_SECRET": secret, "CALENDAR_TOKEN_ENCRYPTION_KEY": key})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", required=True, type=Path)
    parser.add_argument("--client-json", required=True, type=Path)
    args = parser.parse_args()
    configure_calendar(args.env_file, args.client_json)
    print("Google Calendar settings saved. Credentials are not printed.")


if __name__ == "__main__":
    main()
