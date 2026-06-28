from __future__ import annotations

from typing import Any, Dict, List, Optional, Set, Tuple

from ..db import execute, fetch_all_dict, fetch_one_dict, transaction
from .standings_repo import get_current_season_id_for_league


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
    """Replace a user's following list atomically.

    DELETE + executemany INSERT run in a single transaction so a mid-write
    failure either keeps the previous list intact or commits the new one.
    Otherwise a crash between the two statements would leave the user with
    no follows at all.
    """
    rows = [(user_id, int(tid)) for tid in team_ids]

    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM user_following_teams WHERE user_id=%s",
                (user_id,),
            )

            if rows:
                cur.executemany(
                    """
                    INSERT INTO user_following_teams (user_id, team_id)
                    VALUES (%s, %s)
                    """,
                    rows,
                )


def find_team_current_context(team_id: int) -> Optional[Tuple[int, int]]:
    """
    team의 자국 리그 + 현재 시즌 (league_id, season_id).

    standings 기본값(현재 시즌 자국 리그)과 best eleven 시즌 산출에 사용.
    자국 리그는 가장 최근 league 경기로 식별하고, 그 리그의 is_current 시즌을
    현재 시즌으로 본다. (컵/유럽대회 등 다른 대회/시즌은 호출부에서 명시적으로
    league_id/season_id를 받아 처리한다.)
    """
    row = fetch_one_dict(
        """
        SELECT league_id
        FROM fixtures
        WHERE (home_team_id=%s OR away_team_id=%s)
          AND competition_type='league'
        ORDER BY starting_at DESC
        LIMIT 1
        """,
        (team_id, team_id),
    )
    if not row:
        return None

    league_id = int(row["league_id"])
    season_id = get_current_season_id_for_league(league_id)
    if season_id is None:
        return None

    return league_id, season_id
