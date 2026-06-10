from __future__ import annotations

from typing import Dict, List, Optional, Set, Tuple

from ..core.db import execute, fetch_all, upsert_many
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


def _require_int(value, field_name: str) -> int:
    if not isinstance(value, int):
        raise ValueError(f"Missing or invalid integer field: {field_name}={value!r}")

    return value


def _require_bool(value, field_name: str) -> bool:
    if not isinstance(value, bool):
        raise ValueError(f"Missing or invalid boolean field: {field_name}={value!r}")

    return value


def _require_non_empty_str(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string field: {field_name}={value!r}")

    return value.strip()


def _require_optional_date_str(value, field_name: str) -> Optional[str]:
    if value is None:
        return None

    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Invalid optional date field: {field_name}={value!r}")

    return value


def _normalize_sidelined_rows(team_id: int, sidelined: List[Dict]) -> Tuple[List[Tuple], Set[int]]:
    rows: List[Tuple] = []
    incoming_ids: Set[int] = set()

    for item in sidelined:
        sideline_id = _require_int(item["id"], "sidelined.id")
        item_team_id = _require_int(item["team_id"], "sidelined.team_id")
        player_id = _require_int(item["player_id"], "sidelined.player_id")
        type_id = _require_int(item["type_id"], "sidelined.type_id")
        category = _require_non_empty_str(item["category"], "sidelined.category")
        start_date = _require_optional_date_str(item["start_date"], "sidelined.start_date")
        end_date = _require_optional_date_str(item["end_date"], "sidelined.end_date")
        games_missed = _require_int(item["games_missed"], "sidelined.games_missed")
        completed = _require_bool(item["completed"], "sidelined.completed")

        player = item["player"]
        type_obj = item["type"]

        player_id_from_player = _require_int(player["id"], "sidelined.player.id")
        type_id_from_type = _require_int(type_obj["id"], "sidelined.type.id")

        if player_id_from_player != player_id:
            raise ValueError(
                f"Player id mismatch for sideline_id={sideline_id}: "
                f"sidelined.player_id={player_id!r}, player.id={player_id_from_player!r}"
            )

        if type_id_from_type != type_id:
            raise ValueError(
                f"Type id mismatch for sideline_id={sideline_id}: "
                f"sidelined.type_id={type_id!r}, type.id={type_id_from_type!r}"
            )

        player_name = _require_non_empty_str(player["display_name"], "sidelined.player.display_name")
        type_name = _require_non_empty_str(type_obj["name"], "sidelined.type.name")

        incoming_ids.add(sideline_id)

        rows.append(
            (
                sideline_id,
                item_team_id,
                player_id,
                type_id,
                category,
                type_name,
                player_name,
                start_date,
                end_date,
                games_missed,
                1 if completed else 0,
            )
        )

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

    returned_team_id = _require_int(team["id"], "team.id")

    if returned_team_id != team_id:
        raise ValueError(
            f"Requested team_id={team_id}, "
            f"but Sportmonks returned team.id={returned_team_id}."
        )

    sidelined = team["sidelined"]

    if not isinstance(sidelined, list):
        raise ValueError(
            f"Expected team.sidelined to be list for team_id={team_id}, "
            f"got {type(sidelined).__name__}."
        )

    rows, incoming_ids = _normalize_sidelined_rows(team_id, sidelined)

    if rows:
        upsert_many(SQL_UPSERT_INJURY, rows)

    inactivated = _mark_missing_inactive(team_id, incoming_ids)

    print(
        f"[injuries] team {team_id}: "
        f"received={len(sidelined)} normalized={len(rows)} inactivated={inactivated}"
    )


def refresh_current_injuries(team_ids: Optional[List[int]] = None) -> None:
    if team_ids is None:
        ids = [int(row[0]) for row in fetch_all(SQL_SELECT_CURRENT_TEAM_IDS)]
    else:
        ids = team_ids

    total = 0

    for team_id in ids:
        refresh_team_injuries(team_id)
        total += 1

    print(f"[injuries] refresh-current done: teams={total}")