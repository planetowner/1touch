from __future__ import annotations

import json
from datetime import timezone

from ...core.opta_analysis import RECOVERY_KIND, PROGRESSION_METHOD, team_analysis
from ...core.opta_chalkboard import COORDINATE_SYSTEM
from ..db import fetch_all_dict


def get_analysis(fixture_id: int) -> dict:
    # 경기 포지션이 없는 기존 적재분은 선수의 기본 그룹으로 골키퍼 여부만 확인해요.
    # 완료 표시·이벤트·포지션을 한 쿼리로 읽어 서로 다른 갱신 시점의 값이 섞이지 않게 해요.
    rows = fetch_all_dict("""
        SELECT src.source_url,m.collected_at,
               f.home_team_id,f.away_team_id,
               e.external_event_id,e.team_id,e.player_id,p.display_name AS player_name,
               e.minute,e.extra_minute,e.kinds,e.start_x,e.start_y,e.end_x,e.end_y,
               COALESCE(fl.match_position_id,pos.position_group_id) AS position_group_id
        FROM fixture_opta_analyses m JOIN fixtures f ON f.fixture_id=m.fixture_id
        JOIN fixture_opta_sources src ON src.fixture_id=m.fixture_id
        LEFT JOIN fixture_opta_events e ON e.fixture_id=m.fixture_id
        LEFT JOIN players p ON p.player_id=e.player_id
        LEFT JOIN fixture_lineups fl ON fl.fixture_id=e.fixture_id
            AND fl.team_id=e.team_id AND fl.player_id=e.player_id
        LEFT JOIN positions pos ON pos.position_id=p.position_id
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
            "defensive_filters": (RECOVERY_KIND,),
            "regains": "opta_outfield_recoveries_only",
            "position_basis": "match_position_then_player_position_group",
            "missing_position": "known_points_only_team_totals_averages_percentages_null",
            "high_regains": "attacking_x_gte_50",
            "regain_halves": "own_x_lt_50_opponent_x_gte_50_denominator_all_outfield_recoveries",
            "average_regain_height": "from_own_goal_line_on_standardized_105m_pitch",
            "defensive_position_system": "both_teams_attack_right_origin_top_left_range_0_100",
            # 이 DOM은 분 단위 이벤트예요. 주행거리·압박·점유 회복 시간·Carry로 추정하지 않아요.
            "time_precision": "minute", "map_kind": "outfield_recoveries_not_pressure",
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
        event = {k: row[k] for k in ("external_event_id", "player_id", "player_name", "minute",
                                    "extra_minute", "position_group_id")}
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
