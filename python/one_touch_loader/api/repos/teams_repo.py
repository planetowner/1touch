from __future__ import annotations

from typing import Any, Dict, List, Optional, Set, Tuple

from ..db import execute, executemany, fetch_all_dict, fetch_one_dict


def get_team(team_id: int) -> Optional[Dict[str, Any]]:
    return fetch_one_dict(
        """
        SELECT team_id, name, short_code, image_path
        FROM teams
        WHERE team_id=%s
        """,
        (team_id,),
    )


def get_teams(team_ids: List[int]) -> List[Dict[str, Any]]:
    if not team_ids:
        return []
    placeholders = ",".join(["%s"] * len(team_ids))
    return fetch_all_dict(
        f"""
        SELECT team_id, name, short_code, image_path
        FROM teams
        WHERE team_id IN ({placeholders})
        ORDER BY name ASC
        """,
        tuple(team_ids),
    )


def list_following_team_ids(user_id: int) -> List[int]:
    rows = fetch_all_dict(
        """
        SELECT team_id
        FROM user_following_teams
        WHERE user_id=%s
        ORDER BY created_at ASC
        """,
        (user_id,),
    )
    return [int(r["team_id"]) for r in rows]


def set_following_teams(user_id: int, team_ids: List[int]) -> None:
    """
    간단 구현:
    - 기존 팔로우 전체 삭제 후 재삽입
    (MVP는 충분. 이후 diff-upsert로 최적화 가능)
    """
    execute("DELETE FROM user_following_teams WHERE user_id=%s", (user_id,))
    rows = [(user_id, int(tid)) for tid in team_ids]
    executemany(
        """
        INSERT INTO user_following_teams (user_id, team_id)
        VALUES (%s, %s)
        """,
        rows,
    )


def find_team_current_context(team_id: int) -> Optional[Tuple[int, int]]:
    """
    team이 속한 최신 league_id/season_id를 fixtures에서 추정.
    - standings 조회/overview 구성에 필요
    """
    row = fetch_one_dict(
        """
        SELECT league_id, season_id
        FROM fixtures
        WHERE (home_team_id=%s OR away_team_id=%s)
        ORDER BY starting_at DESC
        LIMIT 1
        """,
        (team_id, team_id),
    )
    if not row:
        return None
    return int(row["league_id"]), int(row["season_id"])
