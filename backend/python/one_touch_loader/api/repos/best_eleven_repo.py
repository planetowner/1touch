from __future__ import annotations

from collections import defaultdict
from typing import Any

from ...core.best_eleven import formation_slots, order_formations
from ..db import fetch_all_dict


# 요약과 선수 행을 한 SELECT로 읽어, 재계산 중에도 두 화면에 같은 시점의 결과를 줘요.
# 프로필은 players에서 읽으므로 선수 이름·사진이 바뀌면 재계산 없이 조회에 반영돼요.
SQL_BEST_ELEVEN = """
SELECT ff.formation, ff.matches_used,
       be.slot_key, be.player_id, be.starts,
       p.display_name AS player_name, p.image_path AS player_image,
       pos.position_group_code, pos.position_code
FROM team_best_eleven_formations ff
LEFT JOIN team_best_eleven be
  ON be.team_id = ff.team_id AND be.season_id = ff.season_id AND be.formation = ff.formation
LEFT JOIN players p ON p.player_id = be.player_id
LEFT JOIN positions pos ON pos.position_id = p.position_id
WHERE ff.team_id = %s AND ff.season_id = %s
"""


def get_best_eleven(
    team_id: int, season_id: int, formation: str | None = None,
) -> dict[str, Any] | None:
    """Overview는 최다 사용 포메이션을, Analysis는 선택한 포메이션의 11명을 읽어요."""
    rows = fetch_all_dict(SQL_BEST_ELEVEN, (team_id, season_id))
    if not rows:
        return None

    matches = {}
    players_by_formation = defaultdict(list)
    for row in rows:
        name = row["formation"]
        matches[name] = int(row["matches_used"])
        if row["player_id"] is not None:
            players_by_formation[name].append({key: row[key] for key in (
                "slot_key", "player_id", "player_name", "player_image",
                "position_group_code", "position_code", "starts",
            )})

    # 사용률의 분모는 실제로 계산에 사용한 경기 수이며 시즌 전체 경기 수가 아니에요.
    ordered = order_formations(matches)
    total_valid_matches = sum(matches.values())
    formations = [{
        "formation": name,
        "matches_used": matches[name],
        "total_valid_matches": total_valid_matches,
        "usage_percentage": round(matches[name] * 100.0 / total_valid_matches, 1),
        "is_default": name == ordered[0],
    } for name in ordered]
    selected = formation if formation is not None else ordered[0]
    if selected not in matches:
        return None

    players = players_by_formation[selected]
    slots = formation_slots(selected)
    if (
        len(players) != 11
        or len({row["player_id"] for row in players}) != 11
        or {row["slot_key"] for row in players} != set(slots)
    ):
        raise ValueError(
            f"Incomplete Best Eleven: team_id={team_id} season_id={season_id} formation={selected}"
        )
    # DB에는 자리를 한 번만 저장하고, 응답의 표시 순서는 같은 자리 정의에서 계산해요.
    for player in players:
        player["slot_index"] = slots.index(player["slot_key"])
    players.sort(key=lambda player: player["slot_index"])
    summary = next(item for item in formations if item["formation"] == selected)
    return {
        "team_id": team_id,
        "season_id": season_id,
        "formation": selected,
        "matches_used": summary["matches_used"],
        "total_valid_matches": total_valid_matches,
        "usage_percentage": summary["usage_percentage"],
        "formations": formations,
        "players": players,
    }
