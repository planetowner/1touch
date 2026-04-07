from __future__ import annotations

from typing import Dict, List, Optional, Tuple, Set

from ..core.db import fetch_all, upsert_many, execute
from ..core.sportmonks import SportmonksClient


SQL_SELECT_CURRENT_TEAM_IDS = """
SELECT DISTINCT team_id
FROM (
  SELECT f.home_team_id AS team_id
  FROM fixtures f
  JOIN seasons s ON s.season_id = f.season_id
  WHERE s.is_current = 1

  UNION

  SELECT f.away_team_id AS team_id
  FROM fixtures f
  JOIN seasons s ON s.season_id = f.season_id
  WHERE s.is_current = 1
) t
WHERE team_id IS NOT NULL
ORDER BY team_id
"""

SQL_SELECT_ACTIVE_SIDELINE_IDS_BY_TEAM = """
SELECT sideline_id
FROM team_player_injuries
WHERE team_id = %s
  AND is_active = 1
"""

SQL_UPSERT_INJURY = """
INSERT INTO team_player_injuries (
  sideline_id,
  team_id,
  player_id,
  type_id,
  category,
  type_name,
  player_name,
  start_date,
  end_date,
  games_missed,
  completed,
  is_active,
  last_seen_at
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,1,NOW())
ON DUPLICATE KEY UPDATE
  team_id      = VALUES(team_id),
  player_id    = VALUES(player_id),
  type_id      = VALUES(type_id),
  category     = VALUES(category),
  type_name    = VALUES(type_name),
  player_name  = VALUES(player_name),
  start_date   = VALUES(start_date),
  end_date     = VALUES(end_date),
  games_missed = VALUES(games_missed),
  completed    = VALUES(completed),
  is_active    = 1,
  last_seen_at = VALUES(last_seen_at)
"""


def _safe_int(v) -> Optional[int]:
    try:
        return int(v) if v is not None else None
    except Exception:
        return None


def _player_name(player: Dict) -> str:
    return (
        player.get("display_name")
        or player.get("common_name")
        or player.get("name")
        or f"player:{player.get('id', 'unknown')}"
    )


def _type_name(type_obj: Dict) -> Optional[str]:
    return (
        type_obj.get("name")
        or type_obj.get("description")
        or None
    )


def _normalize_sidelined_rows(team_id: int, sidelined: List[Dict]) -> Tuple[List[Tuple], Set[int]]:
    rows: List[Tuple] = []
    incoming_ids: Set[int] = set()

    for item in sidelined or []:
        sideline_id = _safe_int(item.get("id"))
        item_team_id = _safe_int(item.get("team_id")) or team_id
        player_id = _safe_int(item.get("player_id"))

        if sideline_id is None or player_id is None:
            continue

        incoming_ids.add(sideline_id)

        player = item.get("player") or {}
        type_obj = item.get("type") or {}

        rows.append((
            sideline_id,
            item_team_id,
            player_id,
            _safe_int(item.get("type_id")),
            item.get("category"),
            _type_name(type_obj),
            _player_name(player),
            item.get("start_date"),
            item.get("end_date"),
            _safe_int(item.get("games_missed")),
            1 if item.get("completed") else 0,
        ))

    return rows, incoming_ids


def _mark_missing_inactive(team_id: int, incoming_ids: Set[int]) -> int:
    existing_rows = fetch_all(SQL_SELECT_ACTIVE_SIDELINE_IDS_BY_TEAM, (team_id,))
    existing_ids = {int(row[0]) for row in existing_rows}

    if not existing_ids:
        return 0

    missing_ids = existing_ids - incoming_ids
    if not missing_ids:
        return 0

    placeholders = ",".join(["%s"] * len(missing_ids))
    sql = f"""
    UPDATE team_player_injuries
    SET is_active = 0,
        updated_at = NOW()
    WHERE team_id = %s
      AND is_active = 1
      AND sideline_id IN ({placeholders})
    """
    return execute(sql, (team_id, *sorted(missing_ids)))


def refresh_team_injuries(team_id: int) -> None:
    sm = SportmonksClient()
    team = sm.get_team_with_sidelined(team_id)
    sidelined = team.get("sidelined") or []

    rows, incoming_ids = _normalize_sidelined_rows(team_id, sidelined)

    if rows:
        upsert_many(SQL_UPSERT_INJURY, rows)

    inactivated = _mark_missing_inactive(team_id, incoming_ids)

    print(
        f"[injuries] team {team_id}: "
        f"received={len(sidelined)} normalized={len(rows)} inactivated={inactivated}"
    )


def refresh_current_injuries(team_ids: Optional[List[int]] = None) -> None:
    ids = team_ids or [int(row[0]) for row in fetch_all(SQL_SELECT_CURRENT_TEAM_IDS)]
    total = 0

    for team_id in ids:
        refresh_team_injuries(team_id)
        total += 1

    print(f"[injuries] refresh-current done: teams={total}")