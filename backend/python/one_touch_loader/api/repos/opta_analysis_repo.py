from __future__ import annotations

import json
from datetime import timezone

from ...core.opta_analysis import DEFENSIVE_KINDS, PROGRESSION_METHOD, team_analysis
from ...core.opta_chalkboard import COORDINATE_SYSTEM
from ..db import fetch_all_dict


def get_analysis(fixture_id: int) -> dict:
    # 완료 표시와 이벤트를 한 쿼리로 읽어 재수집 전후의 값이 섞이지 않게 해요.
    rows = fetch_all_dict("""
        SELECT m.source_url,m.collected_at,m.home_count,m.away_count,
               f.home_team_id,f.away_team_id,
               e.external_event_id,e.team_id,e.player_id,p.display_name AS player_name,
               e.minute,e.extra_minute,e.kinds,e.start_x,e.start_y,e.end_x,e.end_y
        FROM fixture_opta_analyses m JOIN fixtures f ON f.fixture_id=m.fixture_id
        LEFT JOIN fixture_opta_events e ON e.fixture_id=m.fixture_id
        LEFT JOIN players p ON p.player_id=e.player_id
        WHERE m.fixture_id=%s ORDER BY e.minute,e.extra_minute,e.external_event_id
    """, (fixture_id,))
    result = {
        "fixture_id": fixture_id, "provider": "opta", "available": bool(rows),
        "coordinate_source": "chalkboard_svg", "coordinate_system": COORDINATE_SYSTEM,
        "source_url": None, "collected_at": None, "teams": None,
        "methodology": {
            "progression": PROGRESSION_METHOD,
            "key_passes": "opta_key_passes_excluding_assists",
            "final_third_entries": "completed_pass_crossing_into_final_third",
            "final_third_boundary_x": 200 / 3,
            "defensive_filters": DEFENSIVE_KINDS,
            "regains": "opta_recoveries_only",
            "high_regains": "attacking_x_gte_50",
            "average_regain_height": "from_own_goal_line_on_standardized_105m_pitch",
            "defensive_position_system": "both_teams_attack_right_origin_top_left_range_0_100",
            # 이 DOM은 분 단위 이벤트예요. 주행거리·압박·점유 회복 시간·Carry로 추정하지 않아요.
            "time_precision": "minute", "map_kind": "defensive_actions_not_pressure",
        },
    }
    # 미수집은 null, 수집 후 행동이 없으면 개수 0·평균 null로 구분해요.
    if not rows:
        return result
    meta = rows[0]
    teams = {s: {"team_id": meta[f"{s}_team_id"], "events": []} for s in ("home", "away")}
    for row in rows:
        if row["external_event_id"] is None:
            continue
        side = "home" if row["team_id"] == meta["home_team_id"] else "away"
        event = {k: row[k] for k in ("external_event_id", "player_id", "player_name", "minute", "extra_minute")}
        event["kinds"] = json.loads(row["kinds"])
        event["start"] = {axis: float(row[f"start_{axis}"]) for axis in ("x", "y")}
        event["end"] = ({axis: float(row[f"end_{axis}"]) for axis in ("x", "y")}
                        if row["end_x"] is not None else None)
        teams[side]["events"].append(event)
    for side, team in teams.items():
        team.update(team_analysis(team["events"], side))
    result.update(source_url=meta["source_url"],
                  collected_at=meta["collected_at"].replace(tzinfo=timezone.utc).isoformat(), teams=teams)
    return result
