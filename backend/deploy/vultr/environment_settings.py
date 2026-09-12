"""외부 서비스 설정은 기존 환경 파일의 지정한 키만 바꿔요."""
from pathlib import Path
from dotenv import dotenv_values, set_key


def read_environment(path: Path) -> dict:
    if not path.is_file():
        raise ValueError("기존 환경 설정 파일을 찾을 수 없어요.")
    return dotenv_values(path, interpolate=False)


def save_settings(path: Path, settings: dict[str, str]) -> None:
    # 서비스별 설정은 같은 저장 규칙을 써서 DB 설정과 기존 주석을 유지해요.
    for key, value in settings.items():
        set_key(path, key, value, quote_mode="always")


def merge_client_ids(existing: str | None, selected: str) -> str:
    # Google·Apple 모두 새 앱을 연결할 때 기존 앱의 로그인 허용 ID를 유지해요.
    client_ids = []
    for value in f"{existing or ''},{selected}".split(","):
        client_id = value.strip()
        if client_id and client_id not in client_ids:
            client_ids.append(client_id)
    return ",".join(client_ids)
