"""파일 참조 변경과 삭제 예약을 같은 DB 트랜잭션으로 처리해요."""


def queue_deletion(cur, object_key: str | None) -> None:
    if object_key:
        cur.execute("INSERT IGNORE INTO media_deletions (object_key) VALUES (%s)", (object_key,))


def remove_attachments(cur, post_id: int, keep: tuple[int, ...] = ()) -> None:
    condition = f" AND attachment_id NOT IN ({','.join(['%s'] * len(keep))})" if keep else ""
    cur.execute(f"SELECT attachment_id,object_key FROM post_attachments WHERE post_id=%s{condition} FOR UPDATE",
                (post_id, *keep))
    for item in cur.fetchall():
        queue_deletion(cur, item["object_key"])
        cur.execute("DELETE FROM post_attachments WHERE attachment_id=%s", (item["attachment_id"],))
