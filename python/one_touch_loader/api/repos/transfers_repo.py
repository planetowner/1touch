from __future__ import annotations

from typing import Any, Dict, List, Optional

from ..db import fetch_all_dict, fetch_one_dict


def get_latest_window() -> Optional[Dict[str, Any]]:
    return fetch_one_dict(
        """
        SELECT id, season_year, window_name, start_date, end_date
        FROM transfer_windows
        WHERE start_date <= CURDATE()
        ORDER BY start_date DESC
        LIMIT 1
        """
    )


def get_team_transfers_by_window(
    team_id: int,
    window_id: int,
) -> List[Dict[str, Any]]:
    return fetch_all_dict(
        """
        SELECT
            transfer_id, player_id, player_name, player_image,
            from_team_id, from_team_name, to_team_id, to_team_name,
            type_id, type_name, amount, transfer_date
        FROM team_transfers
        WHERE (from_team_id = %s OR to_team_id = %s)
          AND window_id = %s
        ORDER BY transfer_date DESC
        """,
        (team_id, team_id, window_id),
    )
