"""회원 정보 보존과 계정 관리 변경 전후의 최소 스키마를 읽기 전용으로 확인해요."""
import argparse
from contextlib import closing
import json

from one_touch_loader.core.db import get_conn
from diagnostics import verify_social_webhook_receipts as previous
from diagnostics import verify_user_community as base

COLUMNS = dict(previous.COLUMNS)
COLUMNS["users"] = " ".join(column for column in COLUMNS["users"].split() if column != "timezone")


def verify_schema(*, before: bool) -> dict:
    report = (previous.verify_schema(before=False, print_report=False) if before else
              base.verify_schema(before=False, columns=COLUMNS, primary=previous.PRIMARY,
                                 foreign_keys=previous.management.FOREIGN_KEYS, print_report=False))
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            cur.execute("""SELECT column_type FROM information_schema.columns WHERE table_schema=DATABASE()
                AND table_name='email_verification_codes' AND column_name='purpose'""")
            expected = "enum('signup','password_reset')" if before else "enum('signup','password_reset','username_recovery','email_change')"
            if cur.fetchone() != (expected,):
                raise AssertionError("Unexpected email verification purposes")
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
    print("Account management schema verification passed.")
