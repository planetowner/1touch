"""기존 카카오 수신 표식을 보존한 공통 알림 테이블 전환을 읽기 전용으로 확인해요."""
import argparse
from contextlib import closing
import json

from one_touch_loader.core.db import get_conn
from diagnostics import verify_community_management as management
from diagnostics import verify_user_community as base

COLUMNS = {key: value for key, value in management.COLUMNS.items() if key != "kakao_webhook_receipts"}
COLUMNS["social_webhook_receipts"] = "provider event_hash"
PRIMARY = {key: value for key, value in management.PRIMARY.items() if key != "kakao_webhook_receipts"}
PRIMARY["social_webhook_receipts"] = "provider event_hash"


def verify_schema(*, before: bool) -> dict:
    if before:
        report = management.verify_schema(before=False, print_report=False)
    else:
        report = base.verify_schema(before=False, columns=COLUMNS, primary=PRIMARY,
                                    foreign_keys=management.FOREIGN_KEYS, print_report=False)
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            absent = "social_webhook_receipts" if before else "kakao_webhook_receipts"
            cur.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=%s", (absent,))
            if cur.fetchone()[0]:
                raise AssertionError(f"Unexpected table: {absent}")
            if not before:
                cur.execute("""SELECT column_type,column_default FROM information_schema.columns
                    WHERE table_schema=DATABASE() AND table_name='social_webhook_receipts' AND column_name='provider'""")
                if cur.fetchone() != ("enum('apple','kakao')", None):
                    raise AssertionError("Unexpected webhook provider contract")
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
    print("Social webhook receipts schema verification passed.")
