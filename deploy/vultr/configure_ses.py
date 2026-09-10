"""다운로드한 SES 키를 기존 설정 파일에 넣어요. 실제 값은 출력하지 않아요."""
import argparse
import csv
from pathlib import Path
import secrets

from dotenv import dotenv_values, set_key


def configure_ses(credentials_csv: Path, env_file: Path, sender: str) -> None:
    # 기존 DB·배포 설정이 있는 파일에 필요한 키만 추가해요.
    if not env_file.is_file():
        raise ValueError("기존 환경 설정 파일을 찾을 수 없어요.")
    with credentials_csv.open(encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream))
    # 실제 내려받은 한국어 CSV 형식을 사용해요. 예전 AWS 계정 CSV와 구분해요.
    if len(rows) != 1 or rows[0].get("IAM 사용자 이름") != "1touch-auth-smtp":
        raise ValueError("1touch-auth-smtp에서 내려받은 SMTP CSV 파일을 지정해 주세요.")
    row = rows[0]
    username = row.get("SMTP 사용자 이름", "").strip()
    password = row.get("SMTP 비밀번호", "").strip()
    if not username or not password:
        raise ValueError("CSV에 SMTP 사용자 이름 또는 비밀번호가 없어요.")
    settings = {
        "SES_SMTP_HOST": "email-smtp.ap-northeast-2.amazonaws.com",
        "SES_SMTP_USERNAME": username,
        "SES_SMTP_PASSWORD": password,
        "SES_FROM_EMAIL": sender,
    }
    existing = dotenv_values(env_file, interpolate=False)
    # 다시 실행해도 발급 중인 인증번호가 무효화되지 않도록 기존 비밀값은 유지해요.
    if not existing.get("AUTH_CODE_SECRET"):
        settings["AUTH_CODE_SECRET"] = secrets.token_urlsafe(48)
    for key, value in settings.items():
        set_key(env_file, key, value, quote_mode="always")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credentials-csv", required=True, type=Path)
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--from-email", required=True)
    args = parser.parse_args()
    # 서버에서는 /input 아래에서 실행해요. 경로를 지정했다면 로컬 저장소 경로를 계산하지 않아요.
    env_file = args.env_file if args.env_file is not None else Path(__file__).resolve().parents[2] / ".env"
    try:
        configure_ses(args.credentials_csv, env_file, args.from_email)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"SES 설정 실패: {exc}\n")
    print("SES 설정을 저장했어요. 비밀값은 출력하지 않았어요.")
    print("이 명령은 메일 발송이나 서버 재시작을 실행하지 않아요.")


if __name__ == "__main__":
    main()
