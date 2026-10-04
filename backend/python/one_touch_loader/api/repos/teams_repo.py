from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from ..db import fetch_all_dict, fetch_one_dict, transaction
from live_test import DOMESTIC_COMPETITION_SQL
from ..services.user_preferences import validate_team_selection, favorite_changed_at_after_update
from ..services.profile_changes import check_change_limit, record_change
from ..services.community_periods import utc_now
from .users_repo import lock_user, require_profile


def get_team(team_id: int) -> Optional[Dict[str, Any]]:
    return fetch_one_dict(
        """
        SELECT team_id, name, short_name, short_code, image_path
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
        SELECT team_id, name, short_name, short_code, image_path
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
        ORDER BY position ASC
        """,
        (user_id,),
    )
    return [int(r["team_id"]) for r in rows]


def set_following_and_favorite(
    user_id: int,
    team_ids: List[int],
    favorite_team_id: int,
) -> None:
    """최애팀 제한과 팔로우 목록 변경은 같은 사용자 잠금 안에서 검사해요."""
    with transaction() as conn:
        with conn.cursor(dictionary=True) as cur:
            user = lock_user(cur, user_id)
            require_profile(user)
            cur.execute(f"""SELECT ts.team_id,s.competition_id FROM team_seasons ts
                JOIN seasons s ON s.season_id=ts.season_id JOIN competitions c ON c.competition_id=s.competition_id
                WHERE s.is_current=1 AND s.competition_id IN ({DOMESTIC_COMPETITION_SQL}) AND c.competition_type='league'""")
            leagues = {int(row["team_id"]): int(row["competition_id"]) for row in cur.fetchall()}
            validate_team_selection(team_ids, favorite_team_id, leagues)
            now = utc_now()
            changed_at = favorite_changed_at_after_update(
                user["favorite_team_id"], user["favorite_changed_at"], favorite_team_id, now)
            favorite_changed = user["favorite_team_id"] is not None and user["favorite_team_id"] != favorite_team_id
            if favorite_changed:
                check_change_limit(cur, user_id, "favorite_team", now)
            rows = [(user_id, leagues[tid], tid, position) for position, tid in enumerate(team_ids)]
            cur.execute(
                "DELETE FROM user_following_teams WHERE user_id=%s",
                (user_id,),
            )

            if rows:
                cur.executemany(
                    """
                    INSERT INTO user_following_teams (user_id, competition_id, team_id, position)
                    VALUES (%s, %s, %s, %s)
                    """,
                    rows,
                )

            cur.execute(
                "UPDATE users SET favorite_team_id=%s,favorite_changed_at=%s WHERE user_id=%s",
                (favorite_team_id, changed_at, user_id),
            )
            if favorite_changed:
                record_change(cur, user_id, "favorite_team", now)


def find_team_current_context(team_id: int) -> Optional[Tuple[int, int]]:
    """
    team의 현재 시즌 자국 리그 컨텍스트 (competition_id, season_id).

    standings 기본값(현재 시즌 자국 리그)과 best eleven 시즌 산출에 사용.
    team_seasons와 seasons에서 지원하는 현재 자국 리그 소속을 조회한다. 가장 최근
    경기로 추정하지 않으므로 승강
    직후에도 이전 리그를 붙이지 않고, 해당 시즌 fixture가 아직 없어도(시즌 롤오버)
    소속만 있으면 컨텍스트가 나온다. 현재 시즌 소속이 없으면 None을 반환한다.

    컵·유럽대회 등 다른 대회와 시즌은 호출부에서 명시적으로 받아 처리한다.
    """
    rows = fetch_all_dict(
        f"""
        SELECT s.competition_id, ts.season_id
        FROM team_seasons ts
        JOIN seasons s ON s.season_id = ts.season_id
        JOIN competitions c ON c.competition_id = s.competition_id
        WHERE ts.team_id = %s
          AND s.is_current = 1
          AND s.competition_id IN ({DOMESTIC_COMPETITION_SQL})
          AND c.competition_type = 'league'
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
            f"{[(int(r['competition_id']), int(r['season_id'])) for r in rows]}"
        )

    return int(rows[0]["competition_id"]), int(rows[0]["season_id"])
