"""LINE Login 채널 설정만 기존 환경 파일에 저장해요."""
import argparse
from getpass import getpass
from pathlib import Path
import re

from environment_settings import read_environment, save_settings


def configure_line(env_file: Path, channel_id: str, channel_secret: str) -> None:
    read_environment(env_file)
    channel_id, channel_secret = channel_id.strip(), channel_secret.strip()
    if not re.fullmatch(r"[1-9][0-9]*", channel_id):
        raise ValueError("LINE Login의 숫자 Channel ID를 입력해 주세요.")
    if not channel_secret or any(char.isspace() for char in channel_secret):
        raise ValueError("LINE Login의 Channel secret을 입력해 주세요.")
    # iOS·Android가 같은 로그인 채널을 사용해요. 비밀키는 앱에 전달하지 않아요.
    save_settings(env_file, {"LINE_CHANNEL_ID": channel_id, "LINE_CHANNEL_SECRET": channel_secret})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--channel-id")
    source.add_argument("--from-env", type=Path)
    args = parser.parse_args()
    env_file = args.env_file if args.env_file is not None else Path(__file__).resolve().parents[2] / ".env"
    try:
        values = read_environment(args.from_env) if args.from_env else {}
        channel_id = args.channel_id if args.channel_id is not None else (values.get("LINE_CHANNEL_ID") or "")
        secret = (values.get("LINE_CHANNEL_SECRET") or "") if args.from_env else getpass("LINE Channel secret (hidden): ")
        configure_line(env_file, channel_id, secret)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"LINE 설정 실패: {exc}\n")
    print("LINE 로그인 설정 2개를 저장했어요. 비밀키는 출력하지 않았어요.")
    print("DB 변경·API 재시작은 실행하지 않았어요.")


if __name__ == "__main__":
    main()
