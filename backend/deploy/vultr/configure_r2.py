"""R2 키를 숨김 입력으로 받아 기존 환경 파일에 저장해요."""
import argparse
from getpass import getpass, GetPassWarning
from pathlib import Path
import warnings

from environment_settings import read_environment, save_settings

R2_KEYS = ("R2_ACCOUNT_ID", "R2_BUCKET", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY")


def _select_r2_settings(source: dict) -> dict[str, str]:
    settings = {key: (source.get(key) or "").strip() for key in R2_KEYS}
    if any(not value for value in settings.values()):
        raise ValueError("R2 설정 4개를 모두 입력해 주세요.")
    return settings


def r2_settings(env_file: Path) -> dict[str, str]:
    return _select_r2_settings(read_environment(env_file))


def configure_r2(env_file: Path, settings: dict[str, str]) -> None:
    read_environment(env_file)
    save_settings(env_file, _select_r2_settings(settings))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--prompt", action="store_true")
    source.add_argument("--from-env", type=Path)
    parser.add_argument("--account-id")
    parser.add_argument("--bucket")
    args = parser.parse_args()
    env_file = args.env_file if args.env_file is not None else Path(__file__).resolve().parents[2] / ".env"
    try:
        read_environment(env_file)
        if args.prompt:
            if not args.account_id or not args.bucket:
                parser.error("--prompt에는 --account-id와 --bucket이 필요해요.")
            # 자동 터미널 로그에 키가 남지 않도록 화면에 입력을 표시하지 않아요.
            with warnings.catch_warnings():
                warnings.simplefilter("error", GetPassWarning)
                access_key = getpass("Access Key ID (hidden): ")
                secret = getpass("Secret Access Key (hidden): ")
            settings = dict(zip(R2_KEYS, (args.account_id, args.bucket, access_key, secret)))
        else:
            # 운영 연결에는 R2 키만 옮겨요. 로컬 DB·SMTP 설정은 복사하지 않아요.
            settings = r2_settings(args.from_env)
        configure_r2(env_file, settings)
    except (OSError, ValueError, GetPassWarning) as exc:
        parser.exit(1, f"R2 설정 실패: {exc}\n")
    print("R2 설정 4개를 저장했어요. 키 값은 출력하지 않았어요.")
    print("파일 업로드·DB 변경·서버 재시작은 실행하지 않았어요.")


if __name__ == "__main__":
    main()
