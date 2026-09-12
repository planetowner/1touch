"""카카오 로그인 앱 ID와 웹훅 검증용 키를 기존 환경 파일에 저장해요."""
import argparse
from getpass import getpass
from pathlib import Path
import re

from environment_settings import read_environment, save_settings


def configure_kakao(env_file: Path, app_id: str, rest_api_key: str | None = None) -> None:
    read_environment(env_file)
    app_id = app_id.strip()
    # 토큰의 app_id와 대조하는 숫자 ID예요. 네이티브 앱 키나 어드민 키를 넣지 않아요.
    if not re.fullmatch(r"[1-9][0-9]*", app_id):
        raise ValueError("카카오 앱 목록에 표시된 숫자 앱 ID를 입력해 주세요.")
    # Android·iOS가 같은 Kakao 앱을 쓰므로 서버는 앱 ID 하나를 사용해요.
    settings = {"KAKAO_APP_ID": app_id}
    if rest_api_key is not None:
        rest_api_key = rest_api_key.strip()
        if not re.fullmatch(r"[0-9a-f]{32}", rest_api_key):
            raise ValueError("대표 REST API 키를 입력해 주세요.")
        # SET의 aud 검증에만 써요. 비밀값을 명령줄 인수나 출력에 넣지 않아요.
        settings["KAKAO_REST_API_KEY"] = rest_api_key
    save_settings(env_file, settings)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--app-id")
    source.add_argument("--from-env", type=Path)
    parser.add_argument("--prompt-rest-api-key", action="store_true")
    args = parser.parse_args()
    env_file = args.env_file if args.env_file is not None else Path(__file__).resolve().parents[2] / ".env"
    try:
        source_values = read_environment(args.from_env) if args.from_env else {}
        app_id = args.app_id if args.app_id is not None else (source_values.get("KAKAO_APP_ID") or "")
        rest_api_key = getpass("Primary REST API Key (hidden): ") if args.prompt_rest_api_key else source_values.get("KAKAO_REST_API_KEY")
        configure_kakao(env_file, app_id, rest_api_key)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Kakao 설정 실패: {exc}\n")
    print("Kakao 로그인 앱 ID를 저장했어요.")
    if rest_api_key is not None:
        print("웹훅 검증용 대표 REST API 키도 저장했어요. 키 값은 출력하지 않았어요.")
    print("DB 변경·API 재시작은 실행하지 않았어요.")


if __name__ == "__main__":
    main()
