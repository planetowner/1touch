from __future__ import annotations

from typing import Any, Dict, List, Optional, Set, Tuple

from ..db import execute, fetch_all_dict, fetch_one_dict, transaction


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
    team_seasons(자국 리그 소속, teams/seasons 엔드포인트 기반)에서 현재
    시즌(is_current) 소속을 조회한다 — 가장 최근 경기로 추정하지 않으므로 승강
    직후에도 이전 리그를 붙이지 않고, 해당 시즌 fixture가 아직 없어도(시즌 롤오버)
    소속만 있으면 컨텍스트가 나온다. 현재 시즌 소속이 없으면 None을 반환한다.

    (컵/유럽대회 등 다른 대회/시즌은 호출부에서 명시적으로 league_id/season_id를
    받아 처리한다. team_seasons에는 자국 리그 소속만 적재하므로 league_id는 항상
    자국 리그다.)
    """
    rows = fetch_all_dict(
        """
        SELECT ts.league_id, ts.season_id
        FROM team_seasons ts
        JOIN seasons s ON s.season_id = ts.season_id
        WHERE ts.team_id = %s
          AND s.is_current = 1
        LIMIT 2
        """,
        (team_id,),
    )
    if not rows:
        return None

    # 정상이면 정확히 1행(팀은 한 자국 리그의 현재 시즌에만 속한다). 2행 이상이면
    # is_current 중복 등 데이터 불변식이 깨진 것이므로 (#1) 표면화한다.
    if len(rows) > 1:
        raise ValueError(
            f"team_id={team_id} belongs to multiple current seasons: "
            f"{[(int(r['league_id']), int(r['season_id'])) for r in rows]}"
        )

    return int(rows[0]["league_id"]), int(rows[0]["season_id"])
