from __future__ import annotations

import json
from datetime import timezone

from ...core.opta_analysis import RECOVERY_KIND, PROGRESSION_METHOD, defensive_metrics, recovery_baseline, team_analysis
from ...core.opta_chalkboard import COORDINATE_SYSTEM
from ..db import fetch_all_dict


def get_analysis(fixture_id: int) -> dict:
    # 경기 포지션이 없는 기존 적재분은 선수의 기본 그룹으로 골키퍼 여부만 확인해요.
    # 대상 경기와 리그 비교를 한 쿼리로 읽어 서로 다른 갱신 시점의 값이 섞이지 않게 해요.
    rows = fetch_all_dict("""
        WITH target AS (
            SELECT f.fixture_id,f.starting_at,st.season_id,s.competition_id,s.name AS season
            FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
            JOIN seasons s ON s.season_id=st.season_id
            JOIN fixture_opta_analyses m ON m.fixture_id=f.fixture_id
            JOIN fixture_opta_sources src ON src.fixture_id=f.fixture_id
            WHERE f.fixture_id=%s
        ), scope AS (
            SELECT f.fixture_id,f.home_team_id,f.away_team_id,m.collected_at,
                   t.fixture_id AS target_fixture_id,t.starting_at AS through,
                   t.season_id,t.competition_id,t.season,
                   (f.state_id IN (5,7,8) AND f.starting_at<=t.starting_at) AS in_baseline
            FROM target t JOIN stages st ON st.season_id=t.season_id
            JOIN fixtures f ON f.stage_id=st.stage_id
            LEFT JOIN fixture_opta_analyses m ON m.fixture_id=f.fixture_id
            WHERE f.fixture_id=t.fixture_id OR (f.state_id IN (5,7,8) AND f.starting_at<=t.starting_at)
        )
        SELECT src.source_url,f.*,
               e.external_event_id,e.team_id,e.player_id,p.display_name AS player_name,
               e.minute,e.extra_minute,e.kinds,e.start_x,e.start_y,e.end_x,e.end_y,
               COALESCE(fl.match_position_id,pos.position_group_id) AS position_group_id
        FROM scope f LEFT JOIN fixture_opta_sources src ON src.fixture_id=f.fixture_id
        LEFT JOIN fixture_opta_events e ON e.fixture_id=f.fixture_id
            AND (f.fixture_id=f.target_fixture_id OR JSON_CONTAINS(e.kinds,JSON_QUOTE('recovery')))
        LEFT JOIN players p ON p.player_id=e.player_id
        LEFT JOIN fixture_lineups fl ON fl.fixture_id=e.fixture_id
            AND fl.team_id=e.team_id AND fl.player_id=e.player_id
        LEFT JOIN positions pos ON pos.position_id=p.position_id
        ORDER BY f.fixture_id,e.minute,e.extra_minute,e.external_event_id
    """, (fixture_id,))
    result = {
        "fixture_id": fixture_id, "provider": "opta", "available": bool(rows),
        "coordinate_source": "chalkboard_svg", "coordinate_system": COORDINATE_SYSTEM,
        "source_url": None, "collected_at": None, "teams": None, "recovery_baseline": None,
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
            "recovery_thirds": {"order": ["defensive", "middle", "attacking"],
                                "boundaries_x": [100 / 3, 200 / 3], "boundary_belongs_to": "next_third",
                                "denominator": "all_outfield_recoveries", "difference_unit": "percentage_points"},
            "average_regain_height": "from_own_goal_line_on_standardized_105m_pitch",
            "defensive_position_system": "both_teams_attack_right_origin_top_left_range_0_100",
            # 이 DOM은 분 단위 이벤트예요. 주행거리·압박·점유 회복 시간·Carry로 추정하지 않아요.
            "time_precision": "minute", "map_kind": "outfield_recoveries_not_pressure",
        },
    }
    # 미수집은 null, 수집 후 행동이 없으면 개수 0·평균 null로 구분해요.
    if not rows:
        return result
    matches = {}
    for row in rows:
        match_id = row["fixture_id"]
        if match_id not in matches:
            matches[match_id] = {**row, "teams": {
                s: {"team_id": row[f"{s}_team_id"], "events": []} for s in ("home", "away")}}
        teams = matches[match_id]["teams"]
        if row["external_event_id"] is None:
            continue
        side = "home" if row["team_id"] == row["home_team_id"] else "away"
        event = {k: row[k] for k in ("external_event_id", "player_id", "player_name", "minute",
                                    "extra_minute", "position_group_id")}
        event["kinds"] = json.loads(row["kinds"])
        event["start"] = {axis: float(row[f"start_{axis}"]) for axis in ("x", "y")}
        event["end"] = ({axis: float(row[f"end_{axis}"]) for axis in ("x", "y")}
                        if row["end_x"] is not None else None)
        teams[side]["events"].append(event)
    for match_id, match in matches.items():
        for side, team in match["teams"].items():
            if match_id == fixture_id:
                team.update(team_analysis(team["events"], side))
            else:
                team["defensive_activity"] = defensive_metrics(team["events"], side)
    meta = matches[fixture_id]
    teams = meta["teams"]
    baseline = recovery_baseline([m for m in matches.values() if m["in_baseline"]], fixture_id)
    baseline.update(season_id=meta["season_id"], competition_id=meta["competition_id"], season=meta["season"],
                    through=meta["through"].replace(tzinfo=timezone.utc).isoformat())
    for team in teams.values():
        activity = team["defensive_activity"]
        activity["league_comparison"] = [
            {"third": third["third"], "league_percentage": round(league["percentage"], 6)
             if league["percentage"] is not None else None,
             "difference_pp": round(100 * third["count"] / activity["recoveries"] - league["percentage"], 6)
             if third["percentage"] is not None and league["percentage"] is not None else None}
            for third, league in zip(activity["thirds"], baseline["thirds"])]
    for third in baseline["thirds"]:
        if third["percentage"] is not None:
            third["percentage"] = round(third["percentage"], 6)
    result.update(source_url=meta["source_url"],
                  collected_at=meta["collected_at"].replace(tzinfo=timezone.utc).isoformat(),
                  teams=teams, recovery_baseline=baseline)
    return result
