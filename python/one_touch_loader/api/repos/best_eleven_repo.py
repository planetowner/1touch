from __future__ import annotations

from typing import Any, Dict, List, Optional

from ..db import fetch_all_dict


def get_best_eleven(team_id: int, season_id: int) -> Optional[Dict[str, Any]]:
    """
    team_best_eleven 테이블에서 팀의 Best 11을 조회한다.
    반환: {"formation": "4-3-3", "players": [...]} 또는 None
    """
    rows = fetch_all_dict(
        """
        SELECT formation, slot_key, slot_index,
               player_id, player_name, player_image,
               position_name, detailed_position_name,
               starts, total_minutes
        FROM team_best_eleven
        WHERE team_id = %s AND season_id = %s
        ORDER BY slot_index ASC
        """,
        (team_id, season_id),
    )
    if not rows:
        return None

    return {
        "formation": rows[0]["formation"],
        "players": rows,
    }
