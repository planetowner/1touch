from __future__ import annotations

from typing import Literal, Optional

from fastapi import HTTPException
from mysql.connector import IntegrityError
from ..db import fetch_all_dict, fetch_one_dict, transaction
from ..services.community_periods import utc_now
from .media_repo import queue_deletion
from ..services import social_login
from ..services.auth_security import token_hash


def get_user(user_id: int) -> dict:
    row = fetch_one_dict("SELECT * FROM users WHERE user_id=%s", (user_id,))
    if row is None:
        raise HTTPException(401, "User not found")
    return row


def lock_user(cur, user_id: int) -> dict:
    # 최애팀 변경과 커뮤니티 쓰기가 같은 사용자 행을 잠가 이전 권한으로 쓰는 것을 막아요.
    cur.execute("SELECT * FROM users WHERE user_id=%s FOR UPDATE", (user_id,))
    row = cur.fetchone()
    if row is None:
        raise HTTPException(401, "User not found")
    return row


def require_profile(user: dict) -> None:
    if not all(user[key] for key in ("username", "first_name", "last_name")):
        raise HTTPException(403, "Complete your profile first")
    # 이용 정지는 커뮤니티·채팅 활동에 적용해요. 내 정보 확인과 탈퇴는 계속 가능해요.
    if user["suspended_until"] is not None and user["suspended_until"] > utc_now():
        raise HTTPException(403, "Community access is suspended")


def update_profile(user_id: int, profile: dict) -> None:
    try:
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            lock_user(cur, user_id)
            cur.execute("UPDATE users SET username=%s,first_name=%s,last_name=%s WHERE user_id=%s",
                        (profile["username"], profile["first_name"], profile["last_name"], user_id))
    except IntegrityError as exc:
        if exc.errno != 1062:
            raise
        raise HTTPException(409, "Username is already registered") from exc


def get_favorite_team_id(user_id: int) -> Optional[int]:
    row = fetch_one_dict(
        "SELECT favorite_team_id FROM users WHERE user_id=%s",
        (user_id,),
    )
    if not row:
        return None
    return row["favorite_team_id"]


def list_blocks(user_id: int) -> list[dict]:
    return fetch_all_dict("""SELECT u.user_id,u.username FROM user_blocks b
        JOIN users u ON u.user_id=b.blocked_user_id WHERE b.user_id=%s ORDER BY u.user_id""", (user_id,))


def set_block(user_id: int, blocked_user_id: int, blocked: bool) -> None:
    if user_id == blocked_user_id:
        raise HTTPException(400, "You cannot block yourself")
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, user_id)
        if blocked:
            cur.execute("SELECT user_id FROM users WHERE user_id=%s", (blocked_user_id,))
            if cur.fetchone() is None:
                raise HTTPException(404, "User not found")
            cur.execute("INSERT IGNORE INTO user_blocks (user_id,blocked_user_id) VALUES (%s,%s)",
                        (user_id, blocked_user_id))
        else:
            cur.execute("DELETE FROM user_blocks WHERE user_id=%s AND blocked_user_id=%s", (user_id, blocked_user_id))


def delete_account(user_id: int, provider_proof: dict | None = None) -> None:
    provider_proof = provider_proof or {}
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, user_id)
        cur.execute("SELECT provider,subject FROM user_social_identities WHERE user_id=%s", (user_id,))
        identities = cur.fetchall()
        for identity in identities:
            provider = identity["provider"]
            if provider in ("apple", "kakao") and provider not in provider_proof:
                raise HTTPException(400, {"message": "Provider authentication required to unlink account", "provider": provider})
        for identity in identities:
            if identity["provider"] == "apple":
                social_login.unlink_apple(identity["subject"], **provider_proof["apple"])
            elif identity["provider"] == "kakao":
                social_login.unlink_kakao(identity["subject"], **provider_proof["kakao"])
        # 연결 해제에 실패하면 회원 정보는 유지해요. 공급자 성공과 DB 삭제를 하나의 원격 트랜잭션으로 묶을 수는 없어요.
        _delete_account_rows(cur, user_id)


def _delete_account_rows(cur, user_id: int) -> None:
    # 앱 내부 탈퇴와 공급자 연결 해제 모두 같은 익명화·파일 정리 규칙을 써요.
    # 게시한 첨부는 익명으로 남는 글에 속해요. 프로필 사진과 미게시 파일만 정리해요.
    cur.execute("SELECT object_key FROM user_avatars WHERE user_id=%s", (user_id,))
    avatar = cur.fetchone()
    if avatar:
        queue_deletion(cur, avatar["object_key"])
    cur.execute("SELECT attachment_id,object_key FROM post_attachments WHERE user_id=%s AND post_id IS NULL FOR UPDATE", (user_id,))
    for item in cur.fetchall():
        queue_deletion(cur, item["object_key"])
        cur.execute("DELETE FROM post_attachments WHERE attachment_id=%s", (item["attachment_id"],))
    cur.execute("""DELETE e FROM email_verification_codes e JOIN user_email_credentials c
        ON c.email=e.email WHERE c.user_id=%s""", (user_id,))
    # FK가 로그인·팔로우·좋아요를 삭제하고 게시물·댓글·채팅의 작성자는 NULL로 바꿔요.
    # 탈퇴한 username이나 소셜 ID를 보관해 재가입을 몰래 연결하지 않아요.
    cur.execute("DELETE FROM users WHERE user_id=%s", (user_id,))


def delete_social_account(provider: Literal["apple", "kakao"], subject: str, event_id: str) -> None:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        # 두 공급자의 알림 ID는 독립적이에요. 공급자와 처리 표식을 함께 구분하고 탈퇴와 같은 트랜잭션으로 저장해요.
        cur.execute("INSERT IGNORE INTO social_webhook_receipts (provider,event_hash) VALUES (%s,%s)",
                    (provider, token_hash(event_id)))
        if cur.rowcount == 0:
            return
        cur.execute("SELECT user_id FROM user_social_identities WHERE provider=%s AND subject=%s", (provider, subject))
        identity = cur.fetchone()
        if identity is None:
            return
        user_id = identity["user_id"]
        # 앱 내부 탈퇴와 같은 순서로 사용자 행부터 잠가요. 이미 탈퇴했다면 수신만 확인해요.
        cur.execute("SELECT user_id FROM users WHERE user_id=%s FOR UPDATE", (user_id,))
        if cur.fetchone() is None:
            return
        # 현재 소셜 가입은 공급자별 독립 계정이에요. 이미 연결이 해제된 공급자에 다시 탈퇴 요청하지 않아요.
        _delete_account_rows(cur, user_id)
