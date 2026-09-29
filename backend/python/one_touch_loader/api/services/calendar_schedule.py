"""Apple 구독과 Google 동기화가 같은 경기·시간·알림 규칙을 사용해요."""
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from ..repos.fixtures_repo import list_team_fixtures

EVENT_DURATION = timedelta(hours=2)
REMINDER_MINUTES = 30


@dataclass(frozen=True)
class CalendarMatch:
    fixture_id: int
    title: str
    start: datetime
    location: str

    @property
    def end(self) -> datetime:
        # 예정 경기에는 확정 종료 시간이 없어 요청한 2시간을 사용해요.
        return self.start + EVENT_DURATION

    @property
    def event_id(self) -> str:
        # Google의 base32hex 문자 제한을 지키고 재시도에도 같은 ID를 사용해요.
        return f"onetouch{self.fixture_id}"


def load_schedule(team_ids: list[int], now: datetime) -> list[CalendarMatch]:
    matches = {}
    for team_id in team_ids:
        offset = 0
        while True:
            page = list_team_fixtures(team_id, status="upcoming", limit=200, offset=offset)
            for row in page:
                if not row["starting_at"]:
                    continue
                # 기존 경기 API는 DB의 UTC DATETIME을 오프셋 없이 반환해요.
                start = datetime.fromisoformat(row["starting_at"]).replace(tzinfo=timezone.utc)
                if start <= now:
                    continue
                match = CalendarMatch(int(row["fixture_id"]),
                    f'{row["home_team_name"]} vs {row["away_team_name"]}', start, row.get("venue_name") or "")
                matches[match.fixture_id] = match
            if len(page) < 200:
                break
            offset += len(page)
    return sorted(matches.values(), key=lambda match: (match.start, match.fixture_id))


def _text(value: str) -> str:
    return value.replace("\\", "\\\\").replace("\r\n", "\n").replace("\r", "\n").replace("\n", "\\n").replace(";", "\\;").replace(",", "\\,")


def _fold(line: str) -> str:
    # RFC 5545의 75바이트 제한은 한글 같은 UTF-8 문자 중간에서 끊으면 안 돼요.
    parts, current = [], ""
    for char in line:
        if len((current + char).encode("utf-8")) > 75:
            parts.append(current)
            current = " "
        current += char
    return "\r\n".join([*parts, current])


def render_icalendar(team_name: str, matches: list[CalendarMatch], now: datetime) -> str:
    stamp = now.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//1Touch//Match Calendar//EN",
             "CALSCALE:GREGORIAN", f"X-WR-CALNAME:{_text('1Touch · ' + team_name)}",
             "REFRESH-INTERVAL;VALUE=DURATION:PT15M", "X-PUBLISHED-TTL:PT15M"]
    for match in matches:
        lines.extend(["BEGIN:VEVENT", f"UID:fixture-{match.fixture_id}@1touch.football",
            f"DTSTAMP:{stamp}", f"DTSTART:{match.start.strftime('%Y%m%dT%H%M%SZ')}",
            f"DTEND:{match.end.strftime('%Y%m%dT%H%M%SZ')}", f"SUMMARY:{_text(match.title)}",
            f"LOCATION:{_text(match.location)}", "STATUS:CONFIRMED", "BEGIN:VALARM",
            f"TRIGGER:-PT{REMINDER_MINUTES}M", "ACTION:DISPLAY", f"DESCRIPTION:{_text(match.title)}",
            "END:VALARM", "END:VEVENT"])
    lines.append("END:VCALENDAR")
    return "\r\n".join(_fold(line) for line in lines) + "\r\n"
