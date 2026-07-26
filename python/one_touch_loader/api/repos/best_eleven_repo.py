from __future__ import annotations

from typing import Any, Dict, Optional

from ..db import fetch_all_dict


def get_best_eleven(
    team_id: int,
    season_id: int,
    formation: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    """
    team_best_eleven 테이블에서 팀의 전 대회 통합 Best 11을 조회한다.
    season_id는 team_seasons에 등록된 Big 5 정규리그 대표 시즌 ID다.
    formation을 생략하면 사용 경기 수가 가장 많은 기본 포메이션을 선택한다.
    반환: 포메이션 목록/사용 비율 + 선택 포메이션의 선수 목록, 또는 None
    """
    formation_rows = fetch_all_dict(
        """
        SELECT formation, matches_used, total_valid_matches, is_default
        FROM team_best_eleven_formations
        WHERE team_id = %s AND season_id = %s
        ORDER BY is_default DESC, matches_used DESC, formation ASC
        """,
        (team_id, season_id),
    )
    if not formation_rows:
        return None

    default_rows = [row for row in formation_rows if int(row["is_default"]) == 1]
    if len(default_rows) != 1:
        raise ValueError(
            f"team_id={team_id} season_id={season_id} must have exactly one "
            f"default formation; found={len(default_rows)}"
        )

    selected_formation = formation or str(default_rows[0]["formation"])
    selected_summary = next(
        (
            row
            for row in formation_rows
            if str(row["formation"]) == selected_formation
        ),
        None,
    )
    if selected_summary is None:
        return None

    player_rows = fetch_all_dict(
        """
        SELECT slot_key, slot_index,
               player_id, player_name, player_image,
               position_name, detailed_position_name,
               starts, total_minutes
        FROM team_best_eleven
        WHERE team_id = %s AND season_id = %s AND formation = %s
        ORDER BY slot_index ASC
        """,
        (team_id, season_id, selected_formation),
    )
    if len(player_rows) != 11:
        raise ValueError(
            f"team_id={team_id} season_id={season_id} "
            f"formation={selected_formation} has {len(player_rows)} player rows"
        )

    def build_formation_out(row: Dict[str, Any]) -> Dict[str, Any]:
        matches_used = int(row["matches_used"])
        total_valid_matches = int(row["total_valid_matches"])
        return {
            "formation": str(row["formation"]),
            "matches_used": matches_used,
            "total_valid_matches": total_valid_matches,
            "usage_percentage": round(
                matches_used * 100.0 / total_valid_matches,
                1,
            ),
            "is_default": int(row["is_default"]) == 1,
        }

    selected_out = build_formation_out(selected_summary)
    return {
        "formation": selected_out["formation"],
        "matches_used": selected_out["matches_used"],
        "total_valid_matches": selected_out["total_valid_matches"],
        "usage_percentage": selected_out["usage_percentage"],
        "formations": [build_formation_out(row) for row in formation_rows],
        "players": player_rows,
    }
