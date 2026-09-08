from __future__ import annotations

from ..db import fetch_all_dict


# 스쿼드가 갱신되면 부상 재적재 전에도 떠난 선수를 화면에서 제외해요.
# 등번호와 프로필은 부상 테이블에 복사하지 않고 현재 소속 관계로 읽어요.
SQL_TEAM_INJURIES = """
SELECT i.player_id, p.display_name AS player_name, p.image_path AS player_image,
       sm.jersey_number, i.sideline_id, i.type_id, t.name AS type_name,
       i.start_date, i.end_date
FROM team_player_injuries i
JOIN players p ON p.player_id = i.player_id
JOIN injury_types t ON t.type_id = i.type_id
JOIN team_squad_members sm ON sm.team_id = i.team_id AND sm.player_id = i.player_id
WHERE i.team_id = %s AND sm.season_id = %s
ORDER BY p.display_name, i.player_id, i.start_date, i.sideline_id
"""


def get_team_injuries(team_id: int, season_id: int) -> dict:
    rows = fetch_all_dict(SQL_TEAM_INJURIES, (team_id, season_id))
    players = {}
    for row in rows:
        player_id = row["player_id"]
        if player_id not in players:
            players[player_id] = {key: row[key] for key in (
                "player_id", "player_name", "player_image", "jersey_number",
            )}
            players[player_id]["injuries"] = []
        # 한 선수의 복수 부상을 임의로 대표 한 건으로 줄이지 않아요.
        players[player_id]["injuries"].append({key: row[key] for key in (
            "sideline_id", "type_id", "type_name", "start_date", "end_date",
        )})
    return {"team_id": team_id, "season_id": season_id, "players": list(players.values())}
