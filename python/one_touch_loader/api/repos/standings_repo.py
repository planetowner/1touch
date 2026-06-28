from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from ..db import fetch_all_dict


def get_current_season_id_for_league(league_id: int) -> Optional[int]:
    # A league holds at most one is_current=1 season, but no DB constraint
    # enforces it. Read LIMIT 2 and check cardinality so a duplicate actually
    # surfaces instead of being silently resolved to whichever row comes first:
    #   0 rows -> None, 1 -> that season, >=2 -> error.
    rows = fetch_all_dict(
        """
        SELECT season_id
        FROM seasons
        WHERE league_id=%s AND is_current=1
        LIMIT 2
        """,
        (league_id,),
    )
    if not rows:
        return None
    if len(rows) > 1:
        raise ValueError(
            f"league_id={league_id} has multiple is_current=1 seasons: "
            f"{[int(r['season_id']) for r in rows]}"
        )
    return int(rows[0]["season_id"])


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

    # standings.last5_form is a NOT NULL JSON column always written as a
    # JSON list by standings_loader. Parse directly; any decode error is a
    # real data corruption that should surface, not be masked into [].
    for r in rows:
        r["last5_form"] = json.loads(r["last5_form"])

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
