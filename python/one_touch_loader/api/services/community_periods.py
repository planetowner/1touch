"""사용자의 달력 경계를 UTC 조회 범위로 바꿔요."""
from datetime import datetime, timedelta, timezone
from enum import Enum
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from fastapi import HTTPException


class PostPeriod(str, Enum):
    all_time = "all_time"
    today = "today"
    week = "week"
    month = "month"
    year = "year"


def utc_now() -> datetime:
    # 새 회원·커뮤니티 DATETIME 컬럼은 시간대 없는 UTC로 통일해요.
    return datetime.now(timezone.utc).replace(tzinfo=None)


def public_row(row: dict) -> dict:
    # 새 기능의 UTC DATETIME이 지역 시각으로 해석되지 않도록 응답에 Z를 붙여요.
    return {key: value.isoformat() + "Z" if isinstance(value, datetime) else value for key, value in row.items()}


def period_bounds(period: PostPeriod, timezone_name: str | None, now: datetime) -> tuple[datetime, datetime] | None:
    if period == PostPeriod.all_time:
        return None
    # 기기마다 현재 시간대가 다를 수 있어 회원 설정 대신 조회 요청의 시간대를 사용해요.
    if not timezone_name:
        raise HTTPException(422, "Device timezone is required for a date period")
    try:
        device_zone = ZoneInfo(timezone_name)
    except (ZoneInfoNotFoundError, ValueError) as exc:
        raise HTTPException(422, "Use an IANA device timezone such as Asia/Seoul") from exc
    local = now.replace(tzinfo=timezone.utc).astimezone(device_zone)
    start = local.replace(hour=0, minute=0, second=0, microsecond=0)
    if period == PostPeriod.today:
        end = start + timedelta(days=1)
    elif period == PostPeriod.week:
        # 모든 지역에서 월요일 시작이에요. UTC에 168시간을 더하면 서머타임 주가 틀려요.
        start -= timedelta(days=start.weekday())
        end = start + timedelta(days=7)
    elif period == PostPeriod.month:
        start = start.replace(day=1)
        end = (start + timedelta(days=32)).replace(day=1)
    else:
        start = start.replace(month=1, day=1)
        end = start.replace(year=start.year + 1)
    return tuple(value.astimezone(timezone.utc).replace(tzinfo=None) for value in (start, end))
