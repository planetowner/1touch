from __future__ import annotations

from typing import Any, Dict, List, Optional

from ..db import fetch_all_dict


def get_latest_window() -> Optional[Dict[str, Any]]:
    # is_latest=1인 기간은 하나만 있어야 하지만 DB 고유 제약 조건은 없어요.
    # is_latest에는 일반 인덱스만 있어요. LIMIT 2로 읽고 개수를 확인해 중복을 드러내요.
    # 0개 → None, 1개 → 해당 기간, 2개 이상 → 오류
    rows = fetch_all_dict(
        """
        SELECT id, season_year, window_name, start_date, end_date
        FROM transfer_windows
        WHERE is_latest = 1
        LIMIT 2
        """
    )
    if not rows:
        return None
    if len(rows) > 1:
        raise ValueError(
            f"transfer_windows has multiple is_latest=1 rows: "
            f"{[int(r['id']) for r in rows]}"
        )
    return rows[0]


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
