"""회원·커뮤니티 교체 전후의 컬럼·관계·데이터 범위를 읽기 전용으로 확인해요."""
import argparse
from contextlib import closing
import json
from one_touch_loader.core.db import get_conn

OLD = {
    "users": "user_id created_at",
    "user_profiles": "user_id favorite_team_id created_at updated_at",
    "user_following_teams": "user_id team_id created_at",
    "posts": "post_id user_id category title body media_url created_at updated_at",
    "post_reports": "report_id post_id user_id reason created_at",
}
COLUMNS = {
    "users": "user_id username first_name last_name timezone favorite_team_id favorite_changed_at created_at",
    "user_email_credentials": "user_id email password_hash",
    "user_social_identities": "provider subject user_id",
    "user_sessions": "token_hash user_id expires_at",
    "email_verification_codes": "challenge_hash email purpose code_hash expires_at attempts",
    "api_rate_limits": "scope_hash window_started_at attempts",
    "user_following_teams": "user_id competition_id team_id position",
    "user_following_players": "user_id player_id position",
    "posts": "post_id team_id user_id category title body created_at",
    "post_likes": "post_id user_id",
    "post_comments": "comment_id post_id user_id reply_to_id body created_at",
    "comment_likes": "comment_id user_id",
    "post_attachments": "attachment_id user_id post_id position object_key link_url content_type byte_size created_at",
    "fixture_chat_messages": "message_id fixture_id user_id body created_at",
    "content_reports": "report_id user_id post_id comment_id message_id reason created_at",
}
PRIMARY = dict(zip(COLUMNS, ["user_id", "user_id", "provider subject", "token_hash", "challenge_hash", "scope_hash",
    "user_id team_id", "user_id player_id", "post_id", "post_id user_id", "comment_id", "comment_id user_id",
    "attachment_id", "message_id", "report_id"]))
FOREIGN_KEYS = {
    ("users", "favorite_team_id", "teams", "team_id"),
    *[(table, "user_id", "users", "user_id") for table in (
        "user_email_credentials", "user_social_identities", "user_sessions", "user_following_teams", "user_following_players",
        "posts", "post_likes", "post_comments", "comment_likes", "post_attachments", "fixture_chat_messages", "content_reports")],
    ("user_following_teams", "competition_id", "competitions", "competition_id"),
    ("user_following_teams", "team_id", "teams", "team_id"),
    ("user_following_players", "player_id", "players", "player_id"),
    ("posts", "team_id", "teams", "team_id"),
    *[(table, "post_id", "posts", "post_id") for table in ("post_likes", "post_comments", "post_attachments", "content_reports")],
    ("post_comments", "reply_to_id", "post_comments", "comment_id"),
    ("comment_likes", "comment_id", "post_comments", "comment_id"),
    ("fixture_chat_messages", "fixture_id", "fixtures", "fixture_id"),
    ("content_reports", "comment_id", "post_comments", "comment_id"),
    ("content_reports", "message_id", "fixture_chat_messages", "message_id"),
}
OLD_FKS = {("post_reports", "post_id", "posts", "post_id"),
           *[(table, "user_id", "users", "user_id") for table in ("post_reports", "posts", "user_following_teams", "user_profiles")]}


def verify_schema(*, before: bool) -> dict:
    report = {"before": before, "tables": {}}
    expected = OLD if before else COLUMNS
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            for table in sorted(OLD.keys() | COLUMNS.keys()):
                cur.execute("SELECT column_name FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name=%s ORDER BY ordinal_position", (table,))
                if [row[0] for row in cur.fetchall()] != expected.get(table, "").split():
                    raise AssertionError(f"Unexpected columns: {table}")
                if table not in expected:
                    continue
                cur.execute(f"SELECT COUNT(*) FROM {table}")
                count = cur.fetchone()[0]
                if before and count:
                    raise AssertionError(f"Audited empty table has changed: {table}, rows={count}")
                report["tables"][table] = count
                if not before:
                    cur.execute("SELECT column_name FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name=%s AND index_name='PRIMARY' ORDER BY seq_in_index", (table,))
                    if [row[0] for row in cur.fetchall()] != PRIMARY[table].split():
                        raise AssertionError(f"Unexpected primary key: {table}")
            cur.execute("""SELECT table_name,column_name,referenced_table_name,referenced_column_name FROM information_schema.key_column_usage
                WHERE table_schema=DATABASE() AND referenced_table_name IS NOT NULL""")
            scope = OLD.keys() | COLUMNS.keys()
            actual_fks = {row for row in cur.fetchall() if row[0] in scope or row[2] in scope}
            if actual_fks != (OLD_FKS if before else FOREIGN_KEYS):
                raise AssertionError(f"Unexpected user/community foreign keys: {actual_fks}")
            for table, key in (("teams", "team_id"), ("players", "player_id"), ("fixtures", "fixture_id"), ("competitions", "competition_id")):
                cur.execute("SELECT column_type FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name=%s AND column_name=%s", (table, key))
                if cur.fetchone() != ("bigint unsigned",):
                    raise AssertionError(f"Unexpected parent ID type: {table}.{key}")
            if not before:
                cur.execute("""SELECT COUNT(*) FROM users u LEFT JOIN user_following_teams f
                    ON f.user_id=u.user_id AND f.team_id=u.favorite_team_id
                    WHERE u.favorite_team_id IS NOT NULL AND f.team_id IS NULL""")
                if cur.fetchone()[0]:
                    raise AssertionError("Home favorite is outside following teams")
                cur.execute("""SELECT COUNT(*) FROM post_comments c JOIN post_comments p ON p.comment_id=c.reply_to_id WHERE c.post_id<>p.post_id""")
                if cur.fetchone()[0]:
                    raise AssertionError("Reply points to another post")
        conn.rollback()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--before", action="store_true")
    modes.add_argument("--after", action="store_true")
    verify_schema(before=parser.parse_args().before)
    print("User/community schema verification passed.")
