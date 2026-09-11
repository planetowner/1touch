"""다운로드한 Apple 로그인 키를 기존 환경 파일에 저장해요."""
import argparse
import base64
from pathlib import Path

from environment_settings import merge_client_ids, read_environment, save_settings

APPLE_KEYS = ("APPLE_CLIENT_IDS", "APPLE_TEAM_ID", "APPLE_KEY_ID", "APPLE_PRIVATE_KEY")


def _select_apple_settings(source: dict) -> dict[str, str]:
    settings = {key: (source.get(key) or "").strip() for key in APPLE_KEYS}
    if any(not value for value in settings.values()):
        raise ValueError("Apple 설정 4개를 모두 입력해 주세요.")
    if any(not value.strip() for value in settings["APPLE_CLIENT_IDS"].split(",")):
        raise ValueError("Apple Client ID를 입력해 주세요.")
    pem = settings["APPLE_PRIVATE_KEY"].replace("\\n", "\n").strip()
    lines = pem.splitlines()
    if len(lines) < 3 or lines[0] != "-----BEGIN PRIVATE KEY-----" or lines[-1] != "-----END PRIVATE KEY-----":
        raise ValueError("Apple에서 내려받은 .p8 개인 키 파일을 지정해 주세요.")
    try:
        base64.b64decode("".join(lines[1:-1]), validate=True)
    except ValueError:
        raise ValueError(".p8 개인 키 파일의 내용이 올바르지 않아요.") from None
    # PEM 줄바꿈은 기존 API가 해석하는 문자열로 저장해요.
    settings["APPLE_PRIVATE_KEY"] = pem.replace("\r\n", "\n").replace("\n", "\\n")
    return settings


def apple_settings(env_file: Path) -> dict[str, str]:
    return _select_apple_settings(read_environment(env_file))


def configure_apple(env_file: Path, settings: dict[str, str]) -> int:
    current = read_environment(env_file)
    settings = _select_apple_settings(settings)
    settings["APPLE_CLIENT_IDS"] = merge_client_ids(current.get("APPLE_CLIENT_IDS"), settings["APPLE_CLIENT_IDS"])
    save_settings(env_file, settings)
    return len(settings["APPLE_CLIENT_IDS"].split(","))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--private-key-file", type=Path)
    source.add_argument("--from-env", type=Path)
    parser.add_argument("--client-id")
    parser.add_argument("--team-id")
    parser.add_argument("--key-id")
    args = parser.parse_args()
    env_file = args.env_file if args.env_file is not None else Path(__file__).resolve().parents[2] / ".env"
    try:
        if args.private_key_file is not None:
            if not all((args.client_id, args.team_id, args.key_id)):
                parser.error("--private-key-file에는 --client-id, --team-id, --key-id가 필요해요.")
            # 비밀키를 명령 인자로 받지 않아 터미널 명령 기록에 남기지 않아요.
            settings = dict(zip(APPLE_KEYS, (args.client_id, args.team_id, args.key_id,
                                           args.private_key_file.read_text(encoding="utf-8"))))
        else:
            settings = apple_settings(args.from_env)
        count = configure_apple(env_file, settings)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Apple 설정 실패: {exc}\n")
    print(f"Apple 로그인 설정 4개를 저장했어요. 허용 ID: {count}개")
    print("비밀키는 출력하지 않았어요. DB 변경·API 재시작은 실행하지 않았어요.")


if __name__ == "__main__":
    main()
