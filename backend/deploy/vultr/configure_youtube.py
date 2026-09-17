"""하이라이트 수집용 YouTube API 키만 내보내요."""
import argparse
from pathlib import Path
from environment_settings import read_environment, save_settings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from-env", type=Path, required=True)
    parser.add_argument("--env-file", type=Path, required=True)
    args = parser.parse_args()
    try:
        value = (read_environment(args.from_env).get("YOUTUBE_API_KEY") or "").strip()
        if not value or any(c.isspace() for c in value):
            raise ValueError("YOUTUBE_API_KEY가 없거나 공백이 있어요.")
        save_settings(args.env_file, {"YOUTUBE_API_KEY": value})
    except (OSError, ValueError) as exc:
        parser.exit(1, f"YouTube 설정 실패: {exc}\n")
    print("YouTube API 키만 저장했어요. 비밀키 출력·DB 변경·API 재시작은 하지 않았어요.")


if __name__ == "__main__":
    main()
