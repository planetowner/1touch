from fastapi import HTTPException
from ..db import fetch_all_dict, fetch_one_dict, transaction
from ..services.community_access import require_favorite_team_access
from ..services.community_periods import public_row, utc_now
from .users_repo import get_user, lock_user, require_profile


def fixture_teams(fixture_id: int) -> tuple[int, int]:
    row = fetch_one_dict("SELECT home_team_id,away_team_id FROM fixtures WHERE fixture_id=%s", (fixture_id,))
    if row is None:
        raise HTTPException(404, "Fixture not found")
    return row["home_team_id"], row["away_team_id"]


def check_chat_user(user: dict, fixture_id: int) -> None:
    require_profile(user)
    require_favorite_team_access(user["favorite_team_id"], fixture_teams(fixture_id))


def history(user_id: int, fixture_id: int, before_id: int | None, after_id: int | None, limit: int):
    check_chat_user(get_user(user_id), fixture_id)
    if before_id is not None and after_id is not None:
        raise HTTPException(400, "Use either before_id or after_id")
    condition, params = "", [fixture_id]
    if before_id is not None:
        condition = "AND m.message_id<%s"
        params.append(before_id)
    if after_id is not None:
        condition = "AND m.message_id>%s"
        params.append(after_id)
    order = "ASC" if after_id is not None else "DESC"
    rows = fetch_all_dict(f"""SELECT m.message_id,m.fixture_id,m.user_id,u.username,m.body AS text,m.created_at
        FROM fixture_chat_messages m JOIN users u ON u.user_id=m.user_id
        WHERE m.fixture_id=%s {condition} ORDER BY m.message_id {order} LIMIT %s""", tuple(params + [limit]))
    if after_id is None:
        rows.reverse()
    return [public_row(row) for row in rows]


def create_message(user_id: int, fixture_id: int, text: str) -> dict:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        user = lock_user(cur, user_id)
        check_chat_user(user, fixture_id)
        now = utc_now()
        cur.execute("INSERT INTO fixture_chat_messages (fixture_id,user_id,body,created_at) VALUES (%s,%s,%s,%s)",
                    (fixture_id, user_id, text, now))
        result = {"message_id": cur.lastrowid, "fixture_id": fixture_id, "user_id": user_id,
                  "username": user["username"], "text": text, "created_at": now}
    # DB 저장에 실패한 메시지를 실시간으로 먼저 전달하지 않아요.
    return public_row(result)
