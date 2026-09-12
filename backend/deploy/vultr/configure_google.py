"""Google 로그인 검증용 Client ID를 기존 환경 파일에 추가해요."""
import argparse
from pathlib import Path

from environment_settings import merge_client_ids, read_environment, save_settings


def configure_google(env_file: Path, selected_ids: str) -> int:
    current = read_environment(env_file)
    selected = [value.strip() for value in selected_ids.split(",")]
    if any(not value.endswith(".apps.googleusercontent.com") for value in selected):
        raise ValueError("Google 화면의 Client ID를 입력해 주세요.")
    client_ids = merge_client_ids(current.get("GOOGLE_CLIENT_IDS"), selected_ids)
    save_settings(env_file, {"GOOGLE_CLIENT_IDS": client_ids})
    return len(client_ids.split(","))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--client-id")
    source.add_argument("--from-env", type=Path)
    args = parser.parse_args()
    env_file = args.env_file if args.env_file is not None else Path(__file__).resolve().parents[2] / ".env"
    try:
        # 서버로 옮길 때도 Google 허용 ID만 선택해 로컬 DB·메일·R2 설정을 유지해요.
        selected_ids = args.client_id if args.client_id is not None else (
            read_environment(args.from_env).get("GOOGLE_CLIENT_IDS") or "")
        count = configure_google(env_file, selected_ids)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Google 설정 실패: {exc}\n")
    print(f"Google 로그인 Client ID를 저장했어요. 허용 ID: {count}개")
    print("Client secret은 사용하지 않아요. DB 변경·API 재시작은 실행하지 않았어요.")


if __name__ == "__main__":
    main()
