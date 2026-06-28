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


def set_following_and_favorite(
    user_id: int,
    team_ids: List[int],
    favorite_team_id: Optional[int],
) -> None:
    """Replace the following list AND set the favorite in one transaction.

    All three statements (DELETE + INSERT following, UPDATE favorite) commit
    together or not at all, so the invariant "favorite is always one of the
    followed teams" can never be left half-applied by a mid-write failure.
    The caller validates favorite_team_id ∈ team_ids before calling.
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

            cur.execute(
                "UPDATE user_profiles SET favorite_team_id=%s WHERE user_id=%s",
                (favorite_team_id, user_id),
            )


def find_team_current_context(team_id: int) -> Optional[Tuple[int, int]]:
    """
    team의 현재 시즌 자국 리그 컨텍스트 (league_id, season_id).

    standings 기본값(현재 시즌 자국 리그)과 best eleven 시즌 산출에 사용.
    리그는 "팀이 현재 시즌(is_current) 자국 리그 경기에 실제로 참가하는" 사실로
    식별한다 — 가장 최근 경기로 추정하지 않으므로, 승격/강등 직후 이전 리그를
    붙이거나 팀이 참가하지 않는 시즌을 만들어내지 않는다. 현재 시즌 리그 경기가
    아직 없으면(승강 갭/일정 미생성) None을 반환한다(컨텍스트를 꾸며내지 않음).

    (컵/유럽대회 등 다른 대회/시즌은 호출부에서 명시적으로 league_id/season_id를
    받아 처리한다. 정식 해법은 teams/seasons 소속을 저장하는 team_seasons 테이블로
    조회하는 것이며, 현재는 fixtures의 현재-시즌 참가를 그 대용으로 쓴다.)
    """
    row = fetch_one_dict(
        """
        SELECT f.league_id
        FROM fixtures f
        JOIN seasons s ON s.season_id = f.season_id
        WHERE (f.home_team_id=%s OR f.away_team_id=%s)
          AND f.competition_type='league'
          AND s.is_current = 1
        ORDER BY f.starting_at DESC
        LIMIT 1
        """,
        (team_id, team_id),
    )
    if not row:
        return None

    # row는 현재-시즌 자국 리그 경기에서 왔으므로 그 리그엔 is_current 시즌이 있다.
    # get_current_season_id_for_league는 그 시즌을 돌려주고, 한 리그에 is_current가
    # 둘 이상이면 (#1) 에러로 표면화한다.
    league_id = int(row["league_id"])
    season_id = get_current_season_id_for_league(league_id)
    if season_id is None:
        return None

    return league_id, season_id
