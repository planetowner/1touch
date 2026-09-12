"""LINE 공급자 추가 전후의 연결 테이블을 읽기 전용으로 검사해요."""
import argparse
from contextlib import closing
import json

from one_touch_loader.core.db import get_conn


def verify_schema(*, before: bool, print_report: bool = True) -> dict:
    provider_type = "enum('google','apple','kakao')" if before else "enum('google','apple','kakao','line')"
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            cur.execute("""SELECT column_name,column_type,is_nullable,collation_name FROM information_schema.columns
                WHERE table_schema=DATABASE() AND table_name='user_social_identities' ORDER BY ordinal_position""")
            expected = [("provider", provider_type, "NO", "utf8mb4_0900_ai_ci"),
                        ("subject", "varchar(255)", "NO", "utf8mb4_bin"),
                        ("user_id", "bigint unsigned", "NO", None)]
            if cur.fetchall() != expected:
                raise AssertionError("Unexpected user_social_identities columns")
            cur.execute("""SELECT index_name,column_name,non_unique FROM information_schema.statistics
                WHERE table_schema=DATABASE() AND table_name='user_social_identities' ORDER BY index_name,seq_in_index""")
            if cur.fetchall() != [("one_identity_per_provider", "user_id", 0), ("one_identity_per_provider", "provider", 0),
                                  ("PRIMARY", "provider", 0), ("PRIMARY", "subject", 0)]:
                raise AssertionError("Unexpected social identity indexes")
            cur.execute("""SELECT k.column_name,k.referenced_table_name,k.referenced_column_name,r.delete_rule
                FROM information_schema.key_column_usage k JOIN information_schema.referential_constraints r
                ON r.constraint_schema=k.constraint_schema AND r.constraint_name=k.constraint_name
                AND r.table_name=k.table_name WHERE k.table_schema=DATABASE() AND k.table_name='user_social_identities'""")
            if cur.fetchall() != [("user_id", "users", "user_id", "CASCADE")]:
                raise AssertionError("Unexpected social identity deletion rule")
            cur.execute("SELECT provider,COUNT(*) FROM user_social_identities GROUP BY provider ORDER BY provider")
            counts = dict(cur.fetchall())
        conn.rollback()
    report = {"before": before, "provider_rows": counts}
    if print_report:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--before", action="store_true")
    modes.add_argument("--after", action="store_true")
    verify_schema(before=parser.parse_args().before)
    print("LINE login schema verification passed.")
