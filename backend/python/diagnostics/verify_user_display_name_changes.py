"""회원 공개 이름과 변경 이력의 운영 마이그레이션 전후를 읽기 전용으로 확인해요."""
import argparse
from contextlib import closing
import json

from one_touch_loader.core.db import get_conn


def verify_schema(*, before: bool) -> dict:
    report = {"before": before}
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            cur.execute("""SELECT column_name,column_type FROM information_schema.columns
                WHERE table_schema=DATABASE() AND table_name='users'""")
            columns = dict(cur.fetchall())
            if not {"user_id", "username", "favorite_changed_at"} <= columns.keys():
                raise AssertionError("Expected existing user identity and favorite-team columns")
            cur.execute("SELECT COUNT(*) FROM users")
            report["members"] = cur.fetchone()[0]
            cur.execute("""SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()
                AND table_name='user_profile_changes'""")
            history_exists = bool(cur.fetchone()[0])
            if before:
                if "display_name" in columns or history_exists:
                    raise AssertionError("Display-name migration has already started")
            else:
                if columns.get("display_name") != "varchar(100)" or not history_exists:
                    raise AssertionError("Display-name migration schema is incomplete")
                cur.execute("""SELECT column_name FROM information_schema.columns
                    WHERE table_schema=DATABASE() AND table_name='user_profile_changes' ORDER BY ordinal_position""")
                if [row[0] for row in cur.fetchall()] != ["change_id", "user_id", "change_type", "changed_at"]:
                    raise AssertionError("Unexpected change history columns")
                cur.execute("""SELECT delete_rule FROM information_schema.referential_constraints
                    WHERE constraint_schema=DATABASE() AND table_name='user_profile_changes'""")
                if cur.fetchall() != [("CASCADE",)]:
                    raise AssertionError("Change history must be deleted with the user")
                cur.execute("""SELECT COUNT(*) FROM users u WHERE u.favorite_changed_at IS NOT NULL
                    AND NOT EXISTS (SELECT 1 FROM user_profile_changes h WHERE h.user_id=u.user_id
                        AND h.change_type='favorite_team' AND h.changed_at=u.favorite_changed_at)""")
                if cur.fetchone()[0]:
                    raise AssertionError("A previous favorite-team change is missing")
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
