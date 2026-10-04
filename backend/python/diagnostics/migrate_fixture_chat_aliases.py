"""경기 채팅의 익명 닉네임을 준비해요. DB 변경은 사용자가 --apply로 실행해요."""
import argparse
from pathlib import Path

from one_touch_loader.api.db import fetch_all_dict, fetch_one_dict, transaction
from one_touch_loader.api.repos.chat_repo import get_or_create_alias
from one_touch_loader.api.repos.users_repo import lock_user


SQL_DIRECTORY = Path(__file__).resolve().parents[1] / "one_touch_loader/sql"
TABLES = ("chat_alias_players", "fixture_chat_aliases")


def pending_authors(table_exists: bool) -> list[dict]:
    join = "LEFT JOIN fixture_chat_aliases a ON a.fixture_id=m.fixture_id AND a.user_id=m.user_id" if table_exists else ""
    condition = "AND a.user_id IS NULL" if table_exists else ""
    return fetch_all_dict(f"""SELECT DISTINCT m.fixture_id,m.user_id FROM fixture_chat_messages m {join}
        WHERE m.user_id IS NOT NULL {condition} ORDER BY m.user_id,m.fixture_id""")


def backfill_aliases() -> int:
    authors = pending_authors(table_exists=True)
    for author in authors:
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            # 새 메시지 전송과 같은 배정 함수를 써야 기존·신규 대화의 이름이 일치해요.
            lock_user(cur, author["user_id"])
            get_or_create_alias(cur, author["user_id"], author["fixture_id"])
    return len(authors)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    existing = {}
    # 기존 대화에 이름을 배정하기 전에 후보 목록부터 준비해요.
    for table in TABLES:
        existing[table] = fetch_one_dict("""SELECT 1 FROM information_schema.tables
            WHERE table_schema=DATABASE() AND table_name=%s""", (table,)) is not None
        if args.apply and not existing[table]:
            with transaction() as conn, conn.cursor() as cur:
                cur.execute((SQL_DIRECTORY / f"migrate_{table}.sql").read_text(encoding="utf-8"))
    player_count = fetch_one_dict("SELECT COUNT(*) AS count FROM chat_alias_players")["count"] \
        if args.apply or existing["chat_alias_players"] else 0
    if not args.apply:
        print(f"Player catalog present: {existing['chat_alias_players']}; players: {player_count}; "
              f"alias table present: {existing['fixture_chat_aliases']}; "
              f"authors pending: {len(pending_authors(existing['fixture_chat_aliases']))}")
        return
    assigned = backfill_aliases()
    if pending_authors(table_exists=True):
        raise RuntimeError("Chat nickname backfill is incomplete")
    print(f"Chat nicknames ready. Players: {player_count}; assigned {assigned} existing authors; messages were preserved.")


if __name__ == "__main__":
    main()
