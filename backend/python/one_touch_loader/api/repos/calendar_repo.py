"""앱 연결과 예약 작업이 같은 저장·동기화 경로를 사용해요."""
from datetime import datetime, timezone

from fastapi import HTTPException

from ..db import execute, fetch_all_dict, fetch_one_dict, transaction
from .users_repo import lock_user
from .teams_repo import get_team
from ..services.calendar_schedule import load_schedule
from ..services import google_calendar as google


def status(user_id: int, team_id: int) -> dict:
    google.configured()
    connection = fetch_one_dict("SELECT last_synced_at,last_error FROM user_calendar_connections WHERE user_id=%s", (user_id,))
    subscription = fetch_one_dict("SELECT team_id FROM user_calendar_teams WHERE user_id=%s AND team_id=%s", (user_id, team_id))
    last_sync = connection["last_synced_at"] if connection else None
    return {"connected": connection is not None, "subscribed": subscription is not None,
            "last_synced_at": last_sync.replace(tzinfo=timezone.utc).isoformat() if last_sync else None,
            "last_error": connection["last_error"] if connection else None}


def connect(user_id: int, code: str) -> None:
    google.configured()
    subject, tokens = google.exchange_code(code)
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, user_id)
        cur.execute("SELECT * FROM user_calendar_connections WHERE user_id=%s FOR UPDATE", (user_id,))
        previous = cur.fetchone()
        if previous and previous["google_subject"] != subject:
            raise google.GoogleCalendarError("calendar_account_mismatch", 409)
        refresh_token = tokens.get("refresh_token")
        if refresh_token:
            encrypted = google.token_cipher().encrypt(refresh_token.encode()).decode()
        elif previous:
            encrypted = previous["refresh_token"]
        else:
            raise google.GoogleCalendarError("calendar_reconnect_required", 409)
        calendar_id = previous["calendar_id"] if previous else None
        if calendar_id is None or previous["last_error"] == "calendar_missing":
            client = google.GoogleCalendarClient(tokens["access_token"])
            try:
                calendar_id = client.create_calendar()
            finally:
                client.close()
        cur.execute("""INSERT INTO user_calendar_connections
            (user_id,google_subject,refresh_token,calendar_id) VALUES (%s,%s,%s,%s)
            ON DUPLICATE KEY UPDATE refresh_token=VALUES(refresh_token),calendar_id=VALUES(calendar_id),last_error=NULL""",
            (user_id, subject, encrypted, calendar_id))


def set_subscription(user_id: int, team_id: int, enabled: bool) -> int:
    if get_team(team_id) is None:
        raise HTTPException(404, "Team not found")
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        cur.execute("SELECT user_id FROM user_calendar_connections WHERE user_id=%s FOR UPDATE", (user_id,))
        if cur.fetchone() is None:
            raise google.GoogleCalendarError("calendar_reconnect_required", 409)
        if enabled:
            cur.execute("INSERT IGNORE INTO user_calendar_teams (user_id,team_id) VALUES (%s,%s)", (user_id, team_id))
        else:
            cur.execute("DELETE FROM user_calendar_teams WHERE user_id=%s AND team_id=%s", (user_id, team_id))
    return sync_user(user_id)


def sync_user(user_id: int) -> int:
    try:
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            # 버튼 요청과 예약 작업이 겹쳐도 같은 Google 캘린더는 순서대로 갱신해요.
            cur.execute("SELECT * FROM user_calendar_connections WHERE user_id=%s FOR UPDATE", (user_id,))
            connection = cur.fetchone()
            if connection is None:
                return 0
            cur.execute("SELECT team_id FROM user_calendar_teams WHERE user_id=%s ORDER BY team_id", (user_id,))
            team_ids = [row["team_id"] for row in cur.fetchall()]
            now = datetime.now(timezone.utc)
            matches = load_schedule(team_ids, now)
            client = google.GoogleCalendarClient(google.refresh_access(connection["refresh_token"]))
            try:
                count = client.sync(connection["calendar_id"], matches, now)
            finally:
                client.close()
            cur.execute("UPDATE user_calendar_connections SET last_synced_at=UTC_TIMESTAMP(),last_error=NULL WHERE user_id=%s", (user_id,))
            return count
    except google.GoogleCalendarError as error:
        execute("UPDATE user_calendar_connections SET last_error=%s WHERE user_id=%s", (error.code, user_id))
        raise


def users_to_sync() -> list[int]:
    # 마지막 팀을 해제하다 실패한 경우도 다음 예약 작업에서 남은 일정을 정리해요.
    return [row["user_id"] for row in fetch_all_dict("""SELECT c.user_id FROM user_calendar_connections c
        WHERE c.last_error IS NOT NULL OR EXISTS
        (SELECT 1 FROM user_calendar_teams t WHERE t.user_id=c.user_id) ORDER BY c.user_id""")]


def disconnect(user_id: int) -> None:
    # 연결 해제 뒤에는 인증값과 구독을 보관하지 않아요. 이미 저장된 일정은 그대로 남겨요.
    execute("DELETE FROM user_calendar_connections WHERE user_id=%s", (user_id,))
