from __future__ import annotations

from typing import Optional

from ..db import execute, fetch_one_dict


def ensure_user(user_id: int) -> None:
    execute(
        """
        INSERT IGNORE INTO users (user_id)
        VALUES (%s)
        """,
        (user_id,),
    )
    execute(
        """
        INSERT IGNORE INTO user_profiles (user_id)
        VALUES (%s)
        """,
        (user_id,),
    )


def get_favorite_team_id(user_id: int) -> Optional[int]:
    row = fetch_one_dict(
        "SELECT favorite_team_id FROM user_profiles WHERE user_id=%s",
        (user_id,),
    )
    if not row:
        return None
    return row.get("favorite_team_id")
    

def set_favorite_team_id(user_id: int, team_id: int | None) -> None:
    execute(
        "UPDATE user_profiles SET favorite_team_id=%s WHERE user_id=%s",
        (team_id, user_id),
    )
