"""다운로드한 SES 키를 기존 설정 파일에 넣어요. 실제 값은 출력하지 않아요."""
import argparse
import csv
from email.headerregistry import Address
from pathlib import Path
import secrets

from environment_settings import read_environment, save_settings


def configure_feedback(env_file: Path, feedback_email: str) -> None:
    read_environment(env_file)
    address = Address(addr_spec=feedback_email.strip())
    if not address.username or not address.domain:
        raise ValueError("반송·신고를 받을 이메일 주소를 입력해 주세요.")
    # SMTP 키를 다시 옮기지 않고, 수신자가 확정된 피드백 주소 하나만 저장해요.
    save_settings(env_file, {"SES_FEEDBACK_EMAIL": address.addr_spec})


def configure_ses(credentials_csv: Path, env_file: Path, sender: str) -> None:
    # 기존 DB·배포 설정이 있는 파일에 필요한 키만 추가해요.
    existing = read_environment(env_file)
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
    # 다시 실행해도 발급 중인 인증번호가 무효화되지 않도록 기존 비밀값은 유지해요.
    if not existing.get("AUTH_CODE_SECRET"):
        settings["AUTH_CODE_SECRET"] = secrets.token_urlsafe(48)
    save_settings(env_file, settings)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--credentials-csv", type=Path)
    source.add_argument("--feedback-email")
    source.add_argument("--from-env", type=Path)
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--from-email")
    args = parser.parse_args()
    # 서버에서는 /input 아래에서 실행해요. 경로를 지정했다면 로컬 저장소 경로를 계산하지 않아요.
    env_file = args.env_file if args.env_file is not None else Path(__file__).resolve().parents[2] / ".env"
    try:
        if args.credentials_csv:
            if not args.from_email:
                parser.error("--credentials-csv에는 --from-email이 필요해요.")
            configure_ses(args.credentials_csv, env_file, args.from_email)
        else:
            if args.from_email:
                parser.error("--from-email은 SMTP CSV를 저장할 때만 사용해요.")
            # 공통 서버 전송에서는 피드백 주소만 추출해 기존 SMTP 설정을 유지해요.
            selected = read_environment(args.from_env).get("SES_FEEDBACK_EMAIL", "") if args.from_env else args.feedback_email
            configure_feedback(env_file, selected)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"SES 설정 실패: {exc}\n")
    print("SES 설정을 저장했어요. 비밀값은 출력하지 않았어요." if args.credentials_csv else
          "SES 반송·신고 수신 주소 1개를 저장했어요. 기존 SMTP 키와 발신 주소는 유지해요.")
    print("이 명령은 메일 발송이나 서버 재시작을 실행하지 않아요.")


if __name__ == "__main__":
    main()
