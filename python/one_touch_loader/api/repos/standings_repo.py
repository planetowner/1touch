from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from ..db import fetch_all_dict, fetch_one_dict


def get_current_season_id_for_league(league_id: int) -> Optional[int]:
    row = fetch_one_dict(
        """
        SELECT season_id
        FROM seasons
        WHERE league_id=%s AND is_current=1
        ORDER BY starting_at DESC
        LIMIT 1
        """,
        (league_id,),
    )
    return int(row["season_id"]) if row else None


def list_standings(
    league_id: int,
    season_id: int,
    phase: str = "league",
    group_name: str = "",
) -> List[Dict[str, Any]]:
    rows = fetch_all_dict(
        """
        SELECT
          s.position, s.team_id,
          t.name AS team_name,
          t.image_path AS team_logo,
          s.matches_played, s.won, s.draw, s.lost,
          s.goals_for, s.goals_against, s.goal_diff, s.points,
          s.last5_form
        FROM standings s
        LEFT JOIN teams t ON t.team_id = s.team_id
        WHERE s.league_id=%s AND s.season_id=%s
          AND s.phase=%s AND s.group_name=%s
        ORDER BY s.position ASC
        """,
        (league_id, season_id, phase, group_name),
    )

    for r in rows:
        try:
            r["last5_form"] = json.loads(r.get("last5_form") or "[]")
        except Exception:
            r["last5_form"] = []
    return rows


def get_team_standing(
    league_id: int,
    season_id: int,
    team_id: int,
    phase: str = "league",
    group_name: str = "",
) -> Optional[Dict[str, Any]]:
    rows = list_standings(league_id, season_id, phase, group_name)
    for r in rows:
        if int(r["team_id"]) == int(team_id):
            return r
    return None
