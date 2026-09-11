"""신고를 처리할 운영자 회원 ID만 기존 환경 파일에 저장해요."""
import argparse
from pathlib import Path
import re

from environment_settings import read_environment, save_settings


def configure_community(env_file: Path, user_ids: list[str]) -> None:
    read_environment(env_file)
    selected = [value.strip() for value in user_ids]
    if not selected or any(not re.fullmatch(r"[1-9][0-9]*", value) for value in selected):
        raise ValueError("운영자로 지정할 실제 회원 ID를 입력해 주세요.")
    # 가입·프로필 입력으로 권한을 올리지 않고 기존 서버 설정만 사용해요.
    save_settings(env_file, {"COMMUNITY_ADMIN_USER_IDS": ",".join(dict.fromkeys(selected))})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--admin-user-id", nargs="+")
    source.add_argument("--from-env", type=Path)
    args = parser.parse_args()
    env_file = args.env_file if args.env_file is not None else Path(__file__).resolve().parents[2] / ".env"
    try:
        values = read_environment(args.from_env) if args.from_env else {}
        selected = args.admin_user_id if args.admin_user_id is not None else (values.get("COMMUNITY_ADMIN_USER_IDS") or "").split(",")
        configure_community(env_file, selected)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Community 설정 실패: {exc}\n")
    print("운영자 회원 ID를 저장했어요. 다른 서비스 설정은 유지했어요.")
    print("DB 변경·API 재시작은 실행하지 않았어요.")


if __name__ == "__main__":
    main()
