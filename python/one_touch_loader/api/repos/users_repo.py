from __future__ import annotations

from typing import Optional

from fastapi import HTTPException
from mysql.connector import IntegrityError
from ..db import fetch_one_dict, transaction


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
    if not all(user[key] for key in ("username", "first_name", "last_name", "timezone")):
        raise HTTPException(403, "Complete your profile first")


def update_profile(user_id: int, profile: dict) -> None:
    try:
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            lock_user(cur, user_id)
            cur.execute("UPDATE users SET username=%s,first_name=%s,last_name=%s,timezone=%s WHERE user_id=%s",
                        (profile["username"], profile["first_name"], profile["last_name"], profile["timezone"], user_id))
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
