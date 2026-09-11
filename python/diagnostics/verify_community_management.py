"""운영 행을 유지하는 커뮤니티 후속 변경의 구조와 탈퇴 관계를 읽기 전용으로 검사해요."""
import argparse
import json
from contextlib import closing
from one_touch_loader.core.db import get_conn
from diagnostics import verify_user_community as base

COLUMNS = {
    **base.COLUMNS,
    "users": base.COLUMNS["users"] + " suspended_until",
    "posts": base.COLUMNS["posts"] + " state edited_at",
    "post_comments": base.COLUMNS["post_comments"] + " state edited_at",
    "fixture_chat_messages": base.COLUMNS["fixture_chat_messages"] + " state",
    "content_reports": base.COLUMNS["content_reports"] + " resolution resolved_by resolved_at",
    "user_blocks": "user_id blocked_user_id",
    "user_avatars": "user_id object_key content_type byte_size",
    "media_deletions": "object_key",
    "community_rules": "rules_id body",
    "kakao_webhook_receipts": "event_hash",
}
PRIMARY = {**base.PRIMARY, "user_blocks": "user_id blocked_user_id", "user_avatars": "user_id", "media_deletions": "object_key", "community_rules": "rules_id"}
PRIMARY["kakao_webhook_receipts"] = "event_hash"
FOREIGN_KEYS = base.FOREIGN_KEYS | {
    ("user_blocks", "user_id", "users", "user_id"),
    ("user_blocks", "blocked_user_id", "users", "user_id"),
    ("user_avatars", "user_id", "users", "user_id"),
    ("content_reports", "resolved_by", "users", "user_id"),
}
ANONYMOUS = {"posts", "post_comments", "fixture_chat_messages", "post_attachments", "content_reports"}


def verify_schema(*, before: bool) -> dict:
    report = base.verify_schema(before=False, print_report=False, **({} if before else {
        "columns": COLUMNS, "primary": PRIMARY, "foreign_keys": FOREIGN_KEYS}))
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            if before:
                for table in COLUMNS.keys() - base.COLUMNS.keys():
                    cur.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=%s", (table,))
                    if cur.fetchone()[0]:
                        raise AssertionError(f"New table already exists: {table}")
            else:
                cur.execute("""SELECT k.table_name,k.column_name,r.delete_rule,c.is_nullable
                    FROM information_schema.key_column_usage k
                    JOIN information_schema.referential_constraints r ON r.constraint_schema=k.constraint_schema
                        AND r.table_name=k.table_name AND r.constraint_name=k.constraint_name
                    JOIN information_schema.columns c ON c.table_schema=k.table_schema AND c.table_name=k.table_name AND c.column_name=k.column_name
                    WHERE k.table_schema=DATABASE() AND k.referenced_table_name='users'""")
                for table, column, deletion, nullable in cur.fetchall():
                    anonymous = table in ANONYMOUS
                    if deletion != ("SET NULL" if anonymous else "CASCADE") or nullable != ("YES" if anonymous else "NO"):
                        raise AssertionError(f"Unexpected account deletion rule: {table}.{column}")
        conn.rollback()
    report["before"] = before
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--before", action="store_true")
    modes.add_argument("--after", action="store_true")
    verify_schema(before=parser.parse_args().before)
    print("Community management schema verification passed.")
