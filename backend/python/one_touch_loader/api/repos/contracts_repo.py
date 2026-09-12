from __future__ import annotations

from ..db import fetch_all_dict


def get_team_contracts(team_id: int, season_id: int, *, descending: bool = False) -> dict:
    # 현재 명단을 LEFT JOIN의 기준으로 삼아 계약 미제공 선수도 목록에 남겨요.
    # 남은 기간은 같은 기준일에서 종료일 순서와 같아요. NULL은 양쪽 정렬 모두 마지막이에요.
    direction = "DESC" if descending else "ASC"
    rows = fetch_all_dict(f"""
        SELECT sm.player_id, p.display_name AS player_name, p.image_path AS player_image,
               sm.jersey_number, c.start_date, c.end_date
        FROM team_squad_members sm
        JOIN players p ON p.player_id=sm.player_id
        LEFT JOIN player_contracts c ON c.team_id=sm.team_id AND c.player_id=sm.player_id
        WHERE sm.team_id=%s AND sm.season_id=%s
        ORDER BY (c.end_date IS NULL), c.end_date {direction}, sm.player_id
    """, (team_id, season_id))
    return {"team_id": team_id, "season_id": season_id, "players": rows}
