from datetime import datetime, timezone


def utc_datetime(value: datetime | str) -> datetime:
    # DB의 시간대 없는 값과 API의 ISO 문자열을 같은 UTC 기준으로 비교해요.
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00")) if isinstance(value, str) else value
    return parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed.astimezone(timezone.utc)
