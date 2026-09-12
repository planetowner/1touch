"""만료된 인증 자료와 삭제 예약 파일을 정리해요. 기본 실행은 읽기 전용이에요."""
import argparse
from datetime import timedelta
import json
from contextlib import closing
from ..core.db import get_conn, transaction
from ..api.repos.media_repo import queue_deletion, remove_attachments
from ..api.services.community_periods import utc_now
from ..api.services.community_retention import UNPUBLISHED_RETENTION
from ..api.services.media_storage import object_operation


def maintain_community(*, check: bool, limit: int = 100) -> dict:
    now = utc_now()
    cutoff = now - UNPUBLISHED_RETENTION
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
                cur.execute("SELECT COUNT(*) FROM posts WHERE state='draft' AND edited_at<=%s", (cutoff,))
                counts["draft_posts"] = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM post_attachments WHERE post_id IS NULL AND created_at<=%s", (cutoff,))
                counts["unused_attachments"] = cur.fetchone()[0]
            conn.rollback()
        return {"check": True, **counts}

    counts = {"check": False, "draft_posts": 0, "unused_attachments": 0, "deleted_files": 0}
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        for table, (condition, value) in predicates.items():
            cur.execute(f"DELETE FROM {table} WHERE {condition} LIMIT %s", (value, limit))
            counts[table] = cur.rowcount
    # 저장·게시·탈퇴와 같은 사용자 → 글 → 첨부 순서로 잠그고 만료 여부를 다시 확인해요.
    # 대상마다 커밋해 다음 사용자의 활동을 정리 작업 전체가 끝날 때까지 막지 않아요.
    with closing(get_conn()) as conn, conn.cursor(dictionary=True) as cur:
        cur.execute("SELECT post_id,user_id FROM posts WHERE state='draft' AND edited_at<=%s ORDER BY user_id,post_id LIMIT %s", (cutoff, limit))
        drafts = cur.fetchall()
    for draft in drafts:
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            cur.execute("SELECT user_id FROM users WHERE user_id=%s FOR UPDATE", (draft["user_id"],))
            cur.fetchone()
            cur.execute("SELECT post_id FROM posts WHERE post_id=%s AND state='draft' AND edited_at<=%s FOR UPDATE", (draft["post_id"], cutoff))
            if cur.fetchone() is not None:
                remove_attachments(cur, draft["post_id"])
                cur.execute("DELETE FROM posts WHERE post_id=%s", (draft["post_id"],))
                counts["draft_posts"] += 1
    with closing(get_conn()) as conn, conn.cursor(dictionary=True) as cur:
        # 게시한 첨부와 저장된 초안의 첨부는 여기서 제외해요. 프로필 사진은 대상 테이블이 달라요.
        cur.execute("SELECT attachment_id,user_id FROM post_attachments WHERE post_id IS NULL AND created_at<=%s ORDER BY user_id,attachment_id LIMIT %s", (cutoff, limit))
        attachments = cur.fetchall()
    for attachment in attachments:
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            cur.execute("SELECT user_id FROM users WHERE user_id=%s FOR UPDATE", (attachment["user_id"],))
            cur.fetchone()
            cur.execute("SELECT object_key FROM post_attachments WHERE attachment_id=%s AND post_id IS NULL AND created_at<=%s FOR UPDATE", (attachment["attachment_id"], cutoff))
            item = cur.fetchone()
            if item is not None:
                queue_deletion(cur, item["object_key"])
                cur.execute("DELETE FROM post_attachments WHERE attachment_id=%s", (attachment["attachment_id"],))
                counts["unused_attachments"] += 1
    for _ in range(limit):
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            cur.execute("SELECT object_key FROM media_deletions ORDER BY object_key LIMIT 1 FOR UPDATE")
            item = cur.fetchone()
            if item is None:
                break
            # R2 삭제 실패 시 예약을 남겨 다음 정리에서 같은 키부터 이어가요.
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
    args = parser.parse_args(argv)
    print(json.dumps(maintain_community(check=not args.apply, limit=args.limit), ensure_ascii=False))


if __name__ == "__main__":
    main()
