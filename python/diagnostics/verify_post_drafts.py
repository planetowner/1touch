"""기존 관계를 유지하고 게시물 상태에 초안만 추가했는지 읽기 전용으로 확인해요."""
import argparse
from contextlib import closing
import json

from one_touch_loader.core.db import get_conn
from diagnostics import verify_account_management as previous


def verify_schema(*, before: bool) -> dict:
    report = previous.verify_schema(before=False, print_report=False)
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            cur.execute("""SELECT column_type FROM information_schema.columns WHERE table_schema=DATABASE()
                AND table_name='posts' AND column_name='state'""")
            expected = "enum('active','deleted','hidden')" if before else "enum('active','deleted','hidden','draft')"
            if cur.fetchone() != (expected,):
                raise AssertionError("Unexpected post states")
            cur.execute("SELECT state,COUNT(*) FROM posts GROUP BY state")
            report["posts_by_state"] = dict(cur.fetchall())
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
    print("Post drafts schema verification passed.")
