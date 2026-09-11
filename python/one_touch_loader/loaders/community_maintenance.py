"""만료된 인증 자료와 삭제 예약 파일을 정리해요. 기본 실행은 읽기 전용이에요."""
import argparse
from datetime import datetime, timedelta, timezone
import json
from contextlib import closing
from ..core.db import get_conn, transaction
from ..api.repos.media_repo import queue_deletion
from ..api.services.community_periods import utc_now
from ..api.services.media_storage import object_operation


def maintain_community(*, check: bool, draft_before: datetime | None = None, limit: int = 100) -> dict:
    now = utc_now()
    if draft_before is not None and draft_before >= now:
        raise ValueError("Draft cutoff must be in the past")
    if not 1 <= limit <= 1000:
        raise ValueError("Limit must be between 1 and 1000")
    predicates = {
        "user_sessions": ("expires_at<=%s", now),
        "email_verification_codes": ("expires_at<=%s", now),
        # 현재 인증·업로드·채팅 제한 중 가장 긴 구간이 1시간이에요.
        "api_rate_limits": ("window_started_at<=%s", now - timedelta(hours=1)),
    }
    if check:
        with closing(get_conn()) as conn:
            conn.start_transaction(readonly=True, consistent_snapshot=True)
            with conn.cursor() as cur:
                counts = {}
                for table, (condition, value) in predicates.items():
                    cur.execute(f"SELECT COUNT(*) FROM {table} WHERE {condition}", (value,))
                    counts[table] = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM media_deletions")
                counts["queued_files"] = cur.fetchone()[0]
                counts["drafts"] = 0
                if draft_before is not None:
                    cur.execute("SELECT COUNT(*) FROM post_attachments WHERE post_id IS NULL AND created_at<%s", (draft_before,))
                    counts["drafts"] = cur.fetchone()[0]
            conn.rollback()
        return {"check": True, **counts}

    counts = {"check": False, "drafts": 0, "deleted_files": 0}
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        for table, (condition, value) in predicates.items():
            cur.execute(f"DELETE FROM {table} WHERE {condition} LIMIT %s", (value, limit))
            counts[table] = cur.rowcount
        if draft_before is not None:
            cur.execute("SELECT attachment_id,user_id FROM post_attachments WHERE post_id IS NULL AND created_at<%s ORDER BY user_id,attachment_id LIMIT %s",
                        (draft_before, limit))
            drafts = cur.fetchall()
            for draft in drafts:
                # 게시·탈퇴와 같은 사용자 → 첨부 순서로 잠그고, 방금 게시된 파일은 지우지 않아요.
                cur.execute("SELECT user_id FROM users WHERE user_id=%s FOR UPDATE", (draft["user_id"],))
                cur.fetchone()
                cur.execute("SELECT object_key FROM post_attachments WHERE attachment_id=%s AND post_id IS NULL AND created_at<%s FOR UPDATE",
                            (draft["attachment_id"], draft_before))
                item = cur.fetchone()
                if item is not None:
                    queue_deletion(cur, item["object_key"])
                    cur.execute("DELETE FROM post_attachments WHERE attachment_id=%s", (draft["attachment_id"],))
                    counts["drafts"] += 1
    for _ in range(limit):
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            cur.execute("SELECT object_key FROM media_deletions ORDER BY object_key LIMIT 1 FOR UPDATE")
            item = cur.fetchone()
            if item is None:
                break
            # R2 삭제 실패 시 예약을 남겨 다음 수동 실행에서 같은 키부터 이어가요.
            object_operation("delete_object", Key=item["object_key"])
            cur.execute("DELETE FROM media_deletions WHERE object_key=%s", (item["object_key"],))
            counts["deleted_files"] += 1
    return counts


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--apply", action="store_true")
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--draft-before", help="미게시 첨부를 지울 기준 시각. UTC 또는 시간대가 있는 ISO 시각")
    args = parser.parse_args(argv)
    cutoff = None
    if args.draft_before is not None:
        cutoff = datetime.fromisoformat(args.draft_before.replace("Z", "+00:00"))
        if cutoff.tzinfo is None:
            parser.error("--draft-before requires a timezone offset")
        cutoff = cutoff.astimezone(timezone.utc).replace(tzinfo=None)
    print(json.dumps(maintain_community(check=not args.apply, draft_before=cutoff, limit=args.limit), ensure_ascii=False))


if __name__ == "__main__":
    main()
