from __future__ import annotations

from ..db import fetch_all_dict, fetch_one_dict


def get_team_contracts(team_id: int, season_id: int, *, descending: bool = False) -> dict | None:
    season = fetch_one_dict("""
        SELECT s.is_current
        FROM team_seasons ts
        JOIN seasons s ON s.season_id=ts.season_id
        WHERE ts.team_id=%s AND ts.season_id=%s
          AND s.competition_id IN (8,82,301,384,564)
    """, (team_id, season_id))
    if season is None:
        return None
    is_current = bool(season["is_current"])
    # 명단을 기준으로 조회해 계약·주급이 없는 선수도 목록에 남겨요.
    # 남은 기간은 같은 기준일에서 종료일 순서와 같아요. NULL은 양쪽 정렬 모두 마지막이에요.
    direction = "DESC" if descending else "ASC"
    order_by = f"(c.end_date IS NULL), c.end_date {direction}, sm.player_id" if is_current else "sm.player_id"
    # 계약 이력은 저장하지 않아서 과거 시즌에는 현재 계약을 붙이거나 계약순으로 정렬하지 않아요.
    rows = fetch_all_dict(f"""
        SELECT sm.player_id, p.display_name AS player_name, p.image_path AS player_image,
               sm.position_group_id, sm.jersey_number, p.date_of_birth,
               w.estimated_weekly_gross_eur, sm.leadership_role,
               c.start_date, c.end_date
        FROM team_squad_members sm
        JOIN players p ON p.player_id=sm.player_id
        LEFT JOIN player_contracts c ON c.team_id=sm.team_id AND c.player_id=sm.player_id AND %s=1
        LEFT JOIN player_wages w ON w.team_id=sm.team_id AND w.season_id=sm.season_id
                               AND w.player_id=sm.player_id
        WHERE sm.team_id=%s AND sm.season_id=%s
        ORDER BY {order_by}
    """, (is_current, team_id, season_id))
    return {"team_id": team_id, "season_id": season_id, "is_current": is_current, "players": rows}
