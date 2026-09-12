"""코드 관리로 전환하는 안내 테이블의 삭제 전후를 읽기 전용으로 확인해요."""
import argparse
from contextlib import closing
import json

from diagnostics.verify_community_rules import verify_schema as verify_previous
from one_touch_loader.core.db import get_conn


def verify_schema(*, before: bool, print_report: bool = True) -> dict:
    if before:
        verify_previous(before=False, print_report=False)
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            cur.execute("""SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema=DATABASE() AND table_name='community_rules'""")
            present = bool(cur.fetchone()[0])
            if present != before:
                raise AssertionError("Unexpected community_rules table presence")
            cur.execute("""SELECT table_name,column_name FROM information_schema.key_column_usage
                WHERE referenced_table_schema=DATABASE() AND referenced_table_name='community_rules'""")
            if cur.fetchall():
                raise AssertionError("Another table still references community_rules")
            count = 0
            if before:
                cur.execute("SELECT COUNT(*) FROM community_rules")
                count = cur.fetchone()[0]
        conn.rollback()
    report = {"before": before, "community_rules_table_exists": present, "stored_rules": count}
    if print_report:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--before", action="store_true")
    modes.add_argument("--after", action="store_true")
    verify_schema(before=parser.parse_args().before)
    print("Static community rules schema verification passed.")
