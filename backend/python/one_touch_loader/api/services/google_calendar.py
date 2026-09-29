"""Google 요청과 토큰 처리를 모아 로그나 응답에 인증값을 남기지 않아요."""
from datetime import datetime
from urllib.parse import quote

from cryptography.fernet import Fernet
import requests

from .auth_security import required_setting
from .calendar_schedule import CalendarMatch, REMINDER_MINUTES
from .social_login import _verify_token

CALENDAR_SCOPE = "https://www.googleapis.com/auth/calendar.app.created"


def configured() -> None:
    for name in ("GOOGLE_CALENDAR_CLIENT_ID", "GOOGLE_CALENDAR_CLIENT_SECRET", "CALENDAR_TOKEN_ENCRYPTION_KEY"):
        required_setting(name)
    token_cipher()


def token_cipher() -> Fernet:
    return Fernet(required_setting("CALENDAR_TOKEN_ENCRYPTION_KEY").encode())


class GoogleCalendarError(Exception):
    def __init__(self, code: str, status: int = 503):
        super().__init__(code)
        self.code = code
        self.status = status


def _token(data: dict) -> dict:
    try:
        response = requests.post("https://oauth2.googleapis.com/token", data={
            "client_id": required_setting("GOOGLE_CALENDAR_CLIENT_ID"),
            "client_secret": required_setting("GOOGLE_CALENDAR_CLIENT_SECRET"), **data,
        }, timeout=15)
    except requests.RequestException as exc:
        raise GoogleCalendarError("calendar_provider_unavailable") from exc
    if response.status_code != 200:
        code = "calendar_reconnect_required" if response.status_code == 400 and response.json().get("error") == "invalid_grant" else "calendar_provider_unavailable"
        raise GoogleCalendarError(code, 409 if code == "calendar_reconnect_required" else 503)
    return response.json()


def exchange_code(code: str) -> tuple[str, dict]:
    payload = _token({"grant_type": "authorization_code", "code": code, "redirect_uri": ""})
    if CALENDAR_SCOPE not in payload.get("scope", "").split():
        raise GoogleCalendarError("calendar_permission_required", 403)
    claims = _verify_token(payload["id_token"], "https://www.googleapis.com/oauth2/v3/certs",
        ["accounts.google.com", "https://accounts.google.com"], required_setting("GOOGLE_CALENDAR_CLIENT_ID"))
    return claims["sub"], payload


def refresh_access(encrypted_refresh_token: str) -> str:
    refresh_token = token_cipher().decrypt(encrypted_refresh_token.encode()).decode()
    return _token({"grant_type": "refresh_token", "refresh_token": refresh_token})["access_token"]


class GoogleCalendarClient:
    def __init__(self, access_token: str):
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Bearer {access_token}"

    def close(self):
        self.session.close()

    def request(self, method: str, path: str, *, accepted=(200,), **kwargs):
        try:
            response = self.session.request(method, "https://www.googleapis.com/calendar/v3/" + path, timeout=15, **kwargs)
        except requests.RequestException as exc:
            raise GoogleCalendarError("calendar_provider_unavailable") from exc
        if response.status_code == 401:
            raise GoogleCalendarError("calendar_reconnect_required", 409)
        if response.status_code == 403 and any(error.get("reason") == "insufficientPermissions"
                for error in response.json().get("error", {}).get("errors", [])):
            raise GoogleCalendarError("calendar_permission_required", 403)
        if response.status_code not in accepted:
            raise GoogleCalendarError("calendar_provider_unavailable")
        return response

    def create_calendar(self) -> str:
        return self.request("POST", "calendars", json={"summary": "1Touch", "timeZone": "UTC"}).json()["id"]

    def sync(self, calendar_id: str, matches: list[CalendarMatch], now: datetime) -> int:
        path = f"calendars/{quote(calendar_id, safe='')}/events"
        existing = {}
        params = {"privateExtendedProperty": "onetouch=1", "timeMin": now.isoformat(), "maxResults": 2500}
        while True:
            response = self.request("GET", path, params=params, accepted=(200, 404, 410))
            if response.status_code != 200:
                raise GoogleCalendarError("calendar_missing", 409)
            page = response.json()
            existing.update({event["id"]: event for event in page.get("items", [])})
            if not page.get("nextPageToken"):
                break
            params["pageToken"] = page["nextPageToken"]

        desired = {match.event_id: event_body(match) for match in matches}
        for event_id, body in desired.items():
            if event_id in existing:
                if not _same_event(existing[event_id], body):
                    self.request("PATCH", f"{path}/{event_id}", json=body)
            else:
                # 저장 응답이 유실되거나 삭제된 일정이 복구돼도 같은 경기 ID를 재사용해요.
                response = self.request("POST", path, json={"id": event_id, **body}, accepted=(200, 409))
                if response.status_code == 409:
                    self.request("PATCH", f"{path}/{event_id}", json=body)

        for event_id, event in existing.items():
            start = event.get("start", {}).get("dateTime")
            # 경기 시작 뒤에는 지난 기록을 남겨요. 취소되거나 구독에서 빠진 미래 경기만 지워요.
            if event_id not in desired and start and datetime.fromisoformat(start.replace("Z", "+00:00")) > now:
                self.request("DELETE", f"{path}/{event_id}", accepted=(204, 404, 410))
        return len(desired)


def event_body(match: CalendarMatch) -> dict:
    return {"summary": match.title, "location": match.location, "description": "1Touch",
            "start": {"dateTime": match.start.isoformat()}, "end": {"dateTime": match.end.isoformat()},
            "status": "confirmed", "reminders": {"useDefault": False, "overrides": [
                {"method": "popup", "minutes": REMINDER_MINUTES}]},
            "extendedProperties": {"private": {"onetouch": "1"}}}


def _same_event(existing: dict, desired: dict) -> bool:
    for key in ("summary", "location", "description", "status", "reminders"):
        if existing.get(key) != desired[key]:
            return False
    for key in ("start", "end"):
        value = existing.get(key, {}).get("dateTime")
        if not value or datetime.fromisoformat(value.replace("Z", "+00:00")) != datetime.fromisoformat(desired[key]["dateTime"]):
            return False
    return True
