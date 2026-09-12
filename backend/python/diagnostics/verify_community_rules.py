"""공통 안내의 언어별 저장 구조를 읽기 전용으로 확인해요."""
import argparse
from contextlib import closing
import json

from one_touch_loader.core.db import get_conn


def verify_schema(*, before: bool, print_report: bool = True) -> dict:
    expected = [("rules_id", "tinyint unsigned"), ("body", "text")] if before else [
        ("language", "enum('ko','en')"), ("body", "text")]
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cur:
            cur.execute("""SELECT column_name,column_type,is_nullable FROM information_schema.columns
                WHERE table_schema=DATABASE() AND table_name='community_rules' ORDER BY ordinal_position""")
            if cur.fetchall() != [(name, kind, "NO") for name, kind in expected]:
                raise AssertionError("Unexpected community_rules columns")
            cur.execute("""SELECT column_name FROM information_schema.statistics WHERE table_schema=DATABASE()
                AND table_name='community_rules' AND index_name='PRIMARY' ORDER BY seq_in_index""")
            if cur.fetchall() != [(expected[0][0],)]:
                raise AssertionError("Unexpected community_rules primary key")
            cur.execute("SELECT COUNT(*) FROM community_rules")
            count = cur.fetchone()[0]
            # 현재 빈 테이블만 확인했어요. 이후 등록된 본문의 언어를 임의로 지정하지 않아요.
            if before and count:
                raise AssertionError("community_rules is no longer empty; review existing text before migration")
            cur.execute("""SELECT constraint_name FROM information_schema.table_constraints
                WHERE table_schema=DATABASE() AND table_name='community_rules' AND constraint_type='CHECK'""")
            if cur.fetchall() != ([("community_rules_chk_1",)] if before else []):
                raise AssertionError("Unexpected community_rules check constraint")
            if not before:
                cur.execute("SELECT language FROM community_rules ORDER BY language")
                languages = [row[0] for row in cur.fetchall()]
                if any(language not in ("ko", "en") for language in languages):
                    raise AssertionError("Unsupported community rules language")
        conn.rollback()
    report = {"before": before, "tables": {"community_rules": count}}
    if not before:
        report["languages"] = languages
    if print_report:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--before", action="store_true")
    modes.add_argument("--after", action="store_true")
    verify_schema(before=parser.parse_args().before)
    print("Community rules schema verification passed.")
