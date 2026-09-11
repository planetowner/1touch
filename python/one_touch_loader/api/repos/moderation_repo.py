"""신고는 운영자가 확인해 처리하며 신고 횟수로 자동 제재하지 않아요."""
import os
from datetime import datetime
from fastapi import HTTPException
from ..db import fetch_all_dict, transaction
from ..services.community_periods import public_row, utc_now
from .users_repo import get_user, lock_user, require_profile


def require_admin(user_id: int) -> int:
    # 운영자 ID는 서버 설정으로만 지정해요. 가입·프로필 요청으로 권한을 바꿀 수 없어요.
    allowed = {value.strip() for value in os.getenv("COMMUNITY_ADMIN_USER_IDS", "").split(",") if value.strip()}
    if str(user_id) not in allowed:
        raise HTTPException(403, "Community administrator required")
    require_profile(get_user(user_id))
    return user_id


def list_reports(admin_id: int, resolved: bool, after_id: int, limit: int) -> list[dict]:
    require_admin(admin_id)
    # 신고 처리자는 홈 최애팀과 무관하게 접수 내용을 확인해야 해요. 회원 목록·이메일은 반환하지 않아요.
    rows = fetch_all_dict(f"""SELECT r.*,u.username AS reporter_username,
        COALESCE(p.body,c.body,m.body) AS content_body,p.title AS post_title,
        COALESCE(p.user_id,c.user_id,m.user_id) AS author_id,
        COALESCE(p.state,c.state,m.state) AS content_state
        FROM content_reports r LEFT JOIN users u ON u.user_id=r.user_id
        LEFT JOIN posts p ON p.post_id=r.post_id
        LEFT JOIN post_comments c ON c.comment_id=r.comment_id
        LEFT JOIN fixture_chat_messages m ON m.message_id=r.message_id
        WHERE r.resolved_at IS {'NOT NULL' if resolved else 'NULL'} AND r.report_id>%s
        ORDER BY r.report_id LIMIT %s""", (after_id, limit))
    return [public_row(row) for row in rows]


def resolve_report(admin_id: int, report_id: int, resolution: str) -> None:
    require_admin(admin_id)
    if resolution not in ("dismissed", "hidden"):
        raise HTTPException(400, "Unknown resolution")
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, admin_id)
        # 다른 운영자와 처리 결과가 엇갈리지 않도록 신고 행을 잠가요.
        cur.execute("SELECT * FROM content_reports WHERE report_id=%s FOR UPDATE", (report_id,))
        report = cur.fetchone()
        if report is None:
            raise HTTPException(404, "Report not found")
        if report["resolved_at"] is not None:
            raise HTTPException(409, "Report already resolved")
        if resolution == "hidden":
            for key, table in (("post_id", "posts"), ("comment_id", "post_comments"), ("message_id", "fixture_chat_messages")):
                if report[key] is not None:
                    # 작성자가 이미 지운 내용은 되살리지 않아요. 다른 신고의 기록도 유지해요.
                    cur.execute(f"UPDATE {table} SET state='hidden' WHERE {key}=%s AND state='active'", (report[key],))
                    break
        cur.execute("UPDATE content_reports SET resolution=%s,resolved_by=%s,resolved_at=%s WHERE report_id=%s",
                    (resolution, admin_id, utc_now(), report_id))


def set_suspension(admin_id: int, user_id: int, until: datetime | None) -> None:
    require_admin(admin_id)
    if until is not None and until <= utc_now():
        raise HTTPException(400, "Suspension must end in the future")
    if admin_id == user_id:
        raise HTTPException(400, "Administrators cannot suspend themselves")
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        # 운영자 두 명이 서로 처리해도 사용자 잠금 순서를 통일해요.
        for target_id in sorted((admin_id, user_id)):
            lock_user(cur, target_id)
        cur.execute("UPDATE users SET suspended_until=%s WHERE user_id=%s", (until, user_id))
