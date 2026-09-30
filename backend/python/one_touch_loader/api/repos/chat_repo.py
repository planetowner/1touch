from fastapi import HTTPException
from mysql.connector import IntegrityError
from ...core.fixture_states import LIVE_STATE_IDS
from ..db import fetch_all_dict, fetch_one_dict, transaction
from ..services.chat_aliases import new_nickname, public_chat_message
from ..services.community_access import require_favorite_team_access
from ..services.community_periods import utc_now
from .users_repo import get_user, lock_user, require_profile
from ..services.content_visibility import blocked_sql


def live_fixture_teams(fixture_id: int, cur=None) -> tuple[int, int]:
    sql = "SELECT home_team_id,away_team_id,state_id FROM fixtures WHERE fixture_id=%s"
    if cur is None:
        row = fetch_one_dict(sql, (fixture_id,))
    else:
        # 전송 검사와 저장 사이에 경기 종료가 끼어들지 않게 같은 트랜잭션에서 잠가요.
        cur.execute(sql + " FOR SHARE", (fixture_id,))
        row = cur.fetchone()
    if row is None:
        raise HTTPException(404, "Fixture not found")
    # 화면의 라이브 분류를 함께 써서 하프타임·연장전에도 같은 규칙을 적용해요.
    if row["state_id"] not in LIVE_STATE_IDS:
        raise HTTPException(410, "Live chat is only available during the match.")
    return row["home_team_id"], row["away_team_id"]


def check_chat_user(user: dict, fixture_id: int, cur=None) -> None:
    require_profile(user)
    require_favorite_team_access(user["favorite_team_id"], live_fixture_teams(fixture_id, cur))


def history(user_id: int, fixture_id: int, before_id: int | None, after_id: int | None, limit: int):
    check_chat_user(get_user(user_id), fixture_id)
    if before_id is not None and after_id is not None:
        raise HTTPException(400, "Use either before_id or after_id")
    condition, params = "", [fixture_id, user_id]
    if before_id is not None:
        condition = "AND m.message_id<%s"
        params.append(before_id)
    if after_id is not None:
        condition = "AND m.message_id>%s"
        params.append(after_id)
    order = "ASC" if after_id is not None else "DESC"
    rows = fetch_all_dict(f"""SELECT m.message_id,m.fixture_id,m.user_id,m.body AS text,m.created_at,
        a.nickname_en,a.nickname_ko
        FROM fixture_chat_messages m LEFT JOIN fixture_chat_aliases a
            ON a.fixture_id=m.fixture_id AND a.user_id=m.user_id
        WHERE m.fixture_id=%s AND m.state='active' AND NOT {blocked_sql('m.user_id')}
        {condition} ORDER BY m.message_id {order} LIMIT %s""", tuple(params + [limit]))
    if after_id is None:
        rows.reverse()
    return [public_chat_message(row, user_id) for row in rows]


def get_or_create_alias(cur, user_id: int, fixture_id: int) -> dict:
    # 호출자가 회원 행을 잠가 같은 회원의 동시 전송·경기 이동에도 배정이 한 번만 일어나요.
    cur.execute("SELECT nickname_en,nickname_ko FROM fixture_chat_aliases WHERE fixture_id=%s AND user_id=%s",
                (fixture_id, user_id))
    existing = cur.fetchone()
    if existing is not None:
        return existing
    while True:
        nickname = new_nickname()
        try:
            cur.execute("""INSERT INTO fixture_chat_aliases (fixture_id,user_id,nickname_en,nickname_ko)
                VALUES (%s,%s,%s,%s)""", (fixture_id, user_id, nickname["nickname_en"], nickname["nickname_ko"]))
            return nickname
        except IntegrityError as exc:
            # 4자리 코드는 겹칠 수 있어요. DB가 중복을 거절한 경우에만 다시 뽑아요.
            if exc.errno != 1062:
                raise


def create_message(user_id: int, fixture_id: int, text: str) -> dict:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        user = lock_user(cur, user_id)
        check_chat_user(user, fixture_id, cur)
        nickname = get_or_create_alias(cur, user_id, fixture_id)
        now = utc_now()
        cur.execute("INSERT INTO fixture_chat_messages (fixture_id,user_id,body,created_at) VALUES (%s,%s,%s,%s)",
                    (fixture_id, user_id, text, now))
        result = {"message_id": cur.lastrowid, "fixture_id": fixture_id, "user_id": user_id,
                  **nickname, "text": text, "created_at": now}
    # DB 저장에 실패한 메시지를 실시간으로 먼저 전달하지 않아요.
    return result
