"""수집 로더가 같은 필드 타입과 빈 문자열 기준을 사용하게 해요."""


def require_dict(value, field_name: str) -> dict:
    if not isinstance(value, dict):
        raise ValueError(f"Missing or invalid object: {field_name}={value!r}")
    return value


def require_int(value, field_name: str) -> int:
    # Python의 bool은 int의 하위 타입이지만 공급자의 정수 ID로 받지 않아요.
    if type(value) is not int:
        raise ValueError(f"Missing or invalid integer: {field_name}={value!r}")
    return value


def require_string(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string: {field_name}={value!r}")
    return value.strip()


def optional_string(value, field_name: str) -> str | None:
    if value is None:
        return None
    return require_string(value, field_name)
