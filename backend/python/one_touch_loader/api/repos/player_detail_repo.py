"""저장된 경기·소속·우승 기록으로 선수 상세를 조회해요."""
from __future__ import annotations

from collections import defaultdict
from contextlib import closing
from datetime import datetime, timezone

from ..db import get_conn
from .transfers_repo import get_player_club_history
from ...core.fixture_states import COMPLETED_STATE_IDS, LIVE_STATE_IDS
from ...core.player_detail import (
    MINIMUM_REFERENCE_MINUTES, build_career, dominant_position, match_cards,
    rank_categories, season_categories, stat_index, summarize,
)
from ...core.player_match_metrics import POSITION_GROUPS

COMPLETED = ','.join(map(str, COMPLETED_STATE_IDS))
DISPLAY_STATES = ','.join(map(str, (*COMPLETED_STATE_IDS, *LIVE_STATE_IDS)))
APPEARED = """(fl.lineup_type_id=11 OR fl.minutes_played>0 OR fl.rating IS NOT NULL
    OR EXISTS (SELECT 1 FROM fixture_events ev WHERE ev.fixture_id=fl.fixture_id
      AND ev.team_id=fl.team_id AND ev.event_type_id=18
      AND (ev.player_id=fl.player_id OR ev.related_player_id=fl.player_id)))"""
MATCH_FROM = """
FROM fixture_lineups fl JOIN fixtures f ON f.fixture_id=fl.fixture_id
JOIN stages st ON st.stage_id=f.stage_id JOIN seasons s ON s.season_id=st.season_id
JOIN competitions c ON c.competition_id=s.competition_id
"""
MATCH_SELECT = """
SELECT fl.*, s.season_id, s.name AS season_name, s.competition_id,
       c.name AS competition_name, c.competition_type,
       f.starting_at, f.state_id, f.home_team_id, f.away_team_id, f.home_score, f.away_score,
       r.name AS round_name, t.name AS team_name, t.short_code AS team_code,
       t.image_path AS team_image, op.name AS opponent_name, op.image_path AS opponent_image, x.xg
""" + MATCH_FROM + """
LEFT JOIN rounds r ON r.round_id=f.round_id
JOIN teams t ON t.team_id=fl.team_id
LEFT JOIN teams op ON op.team_id=IF(fl.team_id=f.home_team_id,f.away_team_id,f.home_team_id)
LEFT JOIN fixture_player_expected_goals x ON x.fixture_id=fl.fixture_id AND x.player_id=fl.player_id
"""


def get_player_detail(player_id: int, season_id: int | None = None) -> dict | None:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                def fetch(sql, params=()):
                    cur.execute(sql, params)
                    return cur.fetchall()

                profile = fetch("""SELECT p.player_id, p.display_name AS name, p.image_path AS image,
                    p.height_cm, p.weight_kg, p.date_of_birth, n.name AS nationality, n.image_path AS nationality_image
                    FROM players p LEFT JOIN countries n ON n.country_id=p.nationality_id WHERE p.player_id=%s""", (player_id,))
                if not profile:
                    return None
                profile = profile[0]
                clubs = get_player_club_history(player_id, now.date(), query=fetch)["clubs"]
                roster = fetch("""SELECT sm.*, s.name AS season_name, s.competition_id, s.is_current,
                    c.name AS competition_name, t.name AS team_name, t.image_path AS team_image
                    FROM team_squad_members sm JOIN seasons s ON s.season_id=sm.season_id
                    JOIN competitions c ON c.competition_id=s.competition_id JOIN teams t ON t.team_id=sm.team_id
                    WHERE sm.player_id=%s AND c.competition_type='league'
                    ORDER BY s.is_current DESC,s.name DESC,sm.team_id""", (player_id,))
                history = fetch(MATCH_SELECT + f" WHERE fl.player_id=%s AND f.state_id IN ({DISPLAY_STATES}) AND f.starting_at<=%s AND {APPEARED}", (player_id, now))
                current_name = fetch("SELECT MAX(s.name) AS name FROM seasons s JOIN competitions c ON c.competition_id=s.competition_id WHERE s.is_current=1 AND c.competition_type='league'")[0]["name"]
                current = [r for r in history if r["season_name"] == current_name]
                position = dominant_position(current)
                current_roster = [r for r in roster if r["is_current"]]
                team = current_roster[0] if current_roster else None
                if len(current_roster) > 1 and current:
                    latest_team = max(current, key=lambda r: r["starting_at"])["team_id"]
                    team = next((r for r in current_roster if r["team_id"] == latest_team), team)
                profile.update(team_id=team["team_id"] if team else None,
                               team_name=team["team_name"] if team else None,
                               team_image=team["team_image"] if team else None,
                               jersey_number=team["jersey_number"] if team else None,
                               squad_role=team["squad_role"] if team else None,
                               position_group=POSITION_GROUPS.get(position))
                options = {}
                for row in [r for r in history if r["competition_type"] == "league"] + roster:
                    options[row["season_id"]] = {"season_id": row["season_id"], "season_name": row["season_name"],
                                                "competition_id": row["competition_id"], "competition_name": row["competition_name"]}
                seasons = sorted(options.values(), key=lambda r: (r["season_name"], -r["competition_id"]), reverse=True)
                selected = options.get(season_id) if season_id is not None else next((r for r in seasons if r["season_name"] == current_name and (team is None or r["season_id"] == team["season_id"])), None)
                if season_id is not None and selected is None:
                    raise ValueError("Player has no record for this league season")
                selected_name = selected["season_name"] if selected else current_name
                displayed = [r for r in history if r["season_name"] == selected_name]
                stat_rows = fetch("""SELECT ps.fixture_id,ps.team_id,ps.player_id,ps.stat_type_id,ps.stat_value AS value
                    FROM fixture_player_stats ps JOIN fixtures f ON f.fixture_id=ps.fixture_id
                    JOIN stages st ON st.stage_id=f.stage_id JOIN seasons s ON s.season_id=st.season_id
                    WHERE ps.player_id=%s AND s.name=%s""", (player_id, selected_name))
                stats = stat_index(stat_rows)
                completed = [r for r in history if r["state_id"] in COMPLETED_STATE_IDS]
                competitions = fetch("""SELECT DISTINCT s.season_id,s.competition_id,c.name AS competition_name
                    FROM team_seasons ts JOIN seasons s ON s.season_id=ts.season_id
                    JOIN competitions c ON c.competition_id=s.competition_id
                    WHERE ts.team_id=%s AND s.name=%s AND s.is_current=1 ORDER BY s.competition_id""",
                                     (team["team_id"] if team else None, current_name))
                # 현재 시즌에 실제로 뛴 대회도 포함해요. 고정 UCL 행을 만들지 않아요.
                comp_map = {r["competition_id"]: r for r in competitions}
                for row in current:
                    comp_map.setdefault(row["competition_id"], {k: row[k] for k in ("competition_id", "season_id", "competition_name")})
                for cid, comp in comp_map.items():
                    comp.update(summarize([r for r in completed if r["season_name"] == current_name and r["competition_id"] == cid]))
                honours = fetch("""SELECT h.player_id,h.team_id,h.competition_id,h.season_id,
                    COALESCE(t.name,h.team_name) AS team_name,
                    COALESCE(t.image_path,h.team_image_path) AS team_image,
                    COALESCE(c.name,h.competition_name) AS competition_name,
                    COALESCE(s.name,h.season_name) AS season_name
                    FROM player_team_honours h LEFT JOIN teams t ON t.team_id=h.team_id
                    LEFT JOIN competitions c ON c.competition_id=h.competition_id
                    LEFT JOIN seasons s ON s.season_id=h.season_id WHERE h.player_id=%s
                    ORDER BY COALESCE(s.name,h.season_name) DESC,h.team_id,h.competition_id""", (player_id,))
                analysis = _analysis(fetch, player_id, selected, clubs, roster, now) if selected else None
                return {"player_id": player_id, "profile": profile, "current_season_name": current_name,
                        "current_position": POSITION_GROUPS.get(position), "seasons": seasons, "selected_season": selected,
                        "competitions": list(comp_map.values()), "matches": match_cards(displayed, position, stats),
                        "analysis": analysis, "career": build_career(completed), "clubs": clubs, "honours": honours}
        finally:
            conn.rollback()


def _analysis(fetch, player_id, season, clubs, roster, now):
    league = fetch(MATCH_SELECT + f" WHERE s.season_id=%s AND f.state_id IN ({COMPLETED}) AND f.starting_at<=%s AND {APPEARED}", (season["season_id"], now))
    position_rows = fetch("SELECT fl.player_id,fl.match_position_id,fl.minutes_played,f.starting_at,f.state_id " + MATCH_FROM
                          + f" WHERE s.name=%s AND f.state_id IN ({COMPLETED}) AND f.starting_at<=%s AND {APPEARED}", (season["season_name"], now))
    positions = defaultdict(list)
    for row in position_rows:
        positions[row["player_id"]].append(row)
    position = dominant_position(positions[player_id])
    by_player = defaultdict(list)
    for row in league:
        by_player[row["player_id"]].append(row)
    eligible = {pid for pid, rows in by_player.items()
                if dominant_position(positions[pid]) == position and summarize(rows)["minutes"] >= MINIMUM_REFERENCE_MINUTES}
    stat_players = sorted(eligible | {player_id})
    # 전체 리그의 원시 스탯 전송이 느려 실제 순위 비교 대상과 조회 선수만 읽어요.
    stat_rows = fetch("""SELECT ps.fixture_id,ps.team_id,ps.player_id,ps.stat_type_id,ps.stat_value AS value
        FROM fixture_player_stats ps JOIN fixtures f ON f.fixture_id=ps.fixture_id JOIN stages st ON st.stage_id=f.stage_id
        WHERE st.season_id=%s""" + f" AND ps.player_id IN ({','.join(['%s'] * len(stat_players))})", (season["season_id"], *stat_players))
    stats = stat_index(stat_rows)
    own = by_player[player_id]
    categories = season_categories(position, own, stats)
    reference = [season_categories(position, by_player[pid], stats) for pid in sorted(eligible)]
    top = rank_categories(categories, reference, includes_player=summarize(own)["minutes"] >= MINIMUM_REFERENCE_MINUTES)
    teams = {r["team_id"] for r in own} | {r["team_id"] for r in roster if r["season_id"] == season["season_id"]}
    fixtures = fetch(f"""SELECT f.fixture_id,f.home_team_id,f.away_team_id,f.starting_at
        FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
        WHERE st.season_id=%s AND f.state_id IN ({COMPLETED}) AND f.starting_at<=%s""", (season["season_id"], now))
    def belongs(row):
        for team_id in teams & {row["home_team_id"], row["away_team_id"]}:
            spells = [c for c in clubs if c["team_id"] == team_id]
            if not spells or any((c["start_date"] is None or c["start_date"] <= row["starting_at"].date())
                                 and (c["end_date"] is None or row["starting_at"].date() <= c["end_date"]) for c in spells):
                return True
        return False
    team_matches = sum(belongs(r) for r in fixtures)
    summary = summarize(own)
    return {"position_group": POSITION_GROUPS.get(position), "categories": categories, "top_stats": top,
            "reference_minimum_minutes": MINIMUM_REFERENCE_MINUTES, "reference_players": len(reference),
            "appearances": summary["appearances"], "starts": summary["starts"], "team_matches": team_matches,
            "starting_rate": round(summary["starts"] * 100 / team_matches, 1) if team_matches else None,
            "win_rate": summary["win_rate"],
            "performance": [{"fixture_id": r["fixture_id"], "round": int(r["round_name"]), "rating": r["rating"]}
                            for r in sorted(own, key=lambda r: (int(r["round_name"]) if str(r["round_name"]).isdigit() else 0, r["starting_at"]))
                            if str(r["round_name"]).isdigit()]}


def list_player_comparison_candidates(query: str) -> list[dict]:
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                cur.execute("""SELECT DISTINCT p.player_id,p.display_name AS name,p.image_path AS image
                    FROM players p JOIN team_squad_members sm ON sm.player_id=p.player_id
                    JOIN seasons s ON s.season_id=sm.season_id
                    WHERE s.is_current=1 AND p.display_name LIKE %s ORDER BY p.display_name LIMIT 100""", (f"%{query}%",))
                return cur.fetchall()
        finally:
            conn.rollback()
