from __future__ import annotations
from typing import Dict, List, Tuple, Optional, Iterable, Set
from collections import defaultdict
from datetime import datetime
import json
import re

from ..core.db import fetch_all, upsert_many
from ..core.sportmonks import SportmonksClient

# ===== 상수 =====
BIG5_LEAGUE_IDS = [8, 82, 301, 384, 564]
EURO_LEAGUE_IDS = [2, 5, 2286]
CUP_LEAGUE_IDS  = [24, 27, 390, 570]

STAGE_TYPE_GROUP      = 223  # group-stage
STAGE_TYPE_KNOCK_OUT  = 224  # knock-out
STAGE_TYPE_QUALIFYING = 225  # qualifying

# ===== 공용 SQL =====
SQL_UPSERT_STANDINGS = """
INSERT INTO standings (
  league_id, season_id, phase, group_name, team_id, position,
  matches_played, won, draw, lost, goals_for, goals_against, goal_diff, points, last5_form
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  position=VALUES(position),
  matches_played=VALUES(matches_played),
  won=VALUES(won), draw=VALUES(draw), lost=VALUES(lost),
  goals_for=VALUES(goals_for), goals_against=VALUES(goals_against),
  goal_diff=VALUES(goal_diff), points=VALUES(points),
  last5_form=VALUES(last5_form)
"""

SQL_UPSERT_TIE = """
INSERT INTO knockout_ties (
  league_id, season_id, round_name, team1_id, team2_id,
  leg1_fixture_id, leg1_home_team_id, leg1_away_team_id, leg1_home_score, leg1_away_score,
  leg2_fixture_id, leg2_home_team_id, leg2_away_team_id, leg2_home_score, leg2_away_score,
  aggregate_team1, aggregate_team2, winner_team_id
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  leg1_fixture_id=VALUES(leg1_fixture_id),
  leg1_home_team_id=VALUES(leg1_home_team_id),
  leg1_away_team_id=VALUES(leg1_away_team_id),
  leg1_home_score=VALUES(leg1_home_score),
  leg1_away_score=VALUES(leg1_away_score),
  leg2_fixture_id=VALUES(leg2_fixture_id),
  leg2_home_team_id=VALUES(leg2_home_team_id),
  leg2_away_team_id=VALUES(leg2_away_team_id),
  leg2_home_score=VALUES(leg2_home_score),
  leg2_away_score=VALUES(leg2_away_score),
  aggregate_team1=VALUES(aggregate_team1),
  aggregate_team2=VALUES(aggregate_team2),
  winner_team_id=VALUES(winner_team_id)
"""

# ===== 공용 유틸 =====
def _normalize_dt(s: Optional[str]) -> Optional[str]:
    if not s: return None
    try:
        s2 = s.replace("Z", "+00:00")
        dt = datetime.fromisoformat(s2).replace(tzinfo=None)
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        s3 = s.replace("T", " ").replace("Z", "")
        if "+" in s3:
            s3 = s3.split("+", 1)[0]
        elif len(s3) >= 6 and s3[-6] in "+-" and s3[-3] == ":":
            s3 = s3[:-6]
        return s3[:19]

def _result_for_team(home_id:int, away_id:int, hs:Optional[int], as_:Optional[int], team_id:int) -> Optional[str]:
    if hs is None or as_ is None:
        return None
    if team_id == home_id:
        if hs > as_: return "W"
        if hs < as_: return "L"
        return "D"
    elif team_id == away_id:
        if as_ > hs: return "W"
        if as_ < hs: return "L"
        return "D"
    return None

def _last5_for_team(fixtures: List[Tuple[int,int,Optional[int],Optional[int],str]], team_id:int) -> List[str]:
    """
    fixtures: [(home_id, away_id, home_score, away_score, starting_at)]
    현재 이 리스트는 '최신순'으로 들어오므로,
    정방향(과거→최근) 5개를 만들기 위해 먼저 역순 순회 후 마지막 5개를 슬라이스한다.
    """
    seq: List[str] = []
    for h,a,hs,as_,_ in reversed(fixtures):  # 오래된 경기부터
        r = _result_for_team(h,a,hs,as_,team_id)
        if r:
            seq.append(r)
    return seq[-5:]  # 마지막 5개(과거→최근)

def _rank_rows(rows: List[Dict]) -> List[Dict]:
    """
    rows: {team_id, mp, w,d,l, gf,ga, gd, pts}
    정렬: pts desc, gd desc, gf desc, team_id asc
    """
    rows.sort(key=lambda r: (-r["pts"], -r["gd"], -r["gf"], r["team_id"]))
    for i, r in enumerate(rows, start=1):
        r["pos"] = i
    return rows

def _normalize_knockout_round(name: str) -> str:
    n = name.lower()
    if "round of 16" in n or "1/8" in n or "r16" in n: return "Round of 16"
    if "quarter" in n or "qf" in n: return "Quarter-finals"
    if "semi" in n or "sf" in n: return "Semi-finals"
    if "final" in n and "semi" not in n and "quarter" not in n: return "Final"
    if "knockout round" in n: return "Knockout Round Play-offs"
    return name

def _home_away_from_fx(fx: dict) -> Tuple[Optional[int], Optional[int]]:
    """
    participants.meta.location 우선, 없으면 scores[].score.participant ('home'|'away') 보조.
    """
    home = away = None
    for p in fx.get("participants") or []:
        loc = ((p.get("meta") or {}).get("location") or "").lower()
        if loc == "home": home = p.get("id")
        elif loc == "away": away = p.get("id")
    if home is None or away is None:
        for s in fx.get("scores") or []:
            side = ((s.get("score") or {}).get("participant") or "").lower()
            pid = s.get("participant_id") or s.get("team_id") or s.get("participant")
            if side == "home" and isinstance(pid, int): home = home or pid
            elif side == "away" and isinstance(pid, int): away = away or pid
    return home, away

# ===== 1) 빅5 리그 standings (DB fixtures로 계산) =====
def build_league_standings_for_season(league_id:int, season_id:int):
    """
    fixtures 테이블에서 status='past'만 사용하여 standings 생성.
    """
    sql = """
    SELECT home_team_id, away_team_id, home_score, away_score, starting_at
    FROM fixtures
    WHERE league_id=%s AND season_id=%s AND status='past'
    ORDER BY starting_at DESC
    """
    rows = fetch_all(sql, (league_id, season_id))
    # last5 계산을 위해 최신순 그대로 보존
    latest_by_team: Dict[int, List[Tuple[int,int,Optional[int],Optional[int],str]]] = defaultdict(list)
    # 누계 집계
    agg: Dict[int, Dict] = defaultdict(lambda: {"team_id":0,"mp":0,"w":0,"d":0,"l":0,"gf":0,"ga":0,"gd":0,"pts":0})
    for h,a,hs,as_,dt in rows:
        if hs is None or as_ is None:  # 안전
            continue
        # last5용 푸시
        latest_by_team[h].append((h,a,hs,as_,dt))
        latest_by_team[a].append((h,a,hs,as_,dt))
        # 통계
        for tid, gf, ga in [(h, hs, as_), (a, as_, hs)]:
            agg[tid]["team_id"]=tid
            agg[tid]["mp"] += 1
            agg[tid]["gf"] += gf or 0
            agg[tid]["ga"] += ga or 0
        if hs > as_:
            agg[h]["w"] += 1; agg[h]["pts"] += 3
            agg[a]["l"] += 1
        elif hs < as_:
            agg[a]["w"] += 1; agg[a]["pts"] += 3
            agg[h]["l"] += 1
        else:
            agg[h]["d"] += 1; agg[h]["pts"] += 1
            agg[a]["d"] += 1; agg[a]["pts"] += 1
    # gd
    for r in agg.values():
        r["gd"] = r["gf"] - r["ga"]
    ranked = _rank_rows(list(agg.values()))
    # 업서트
    batch = []
    for r in ranked:
        team_id = r["team_id"]
        last5 = _last5_for_team(latest_by_team.get(team_id, []), team_id)
        batch.append((
            league_id, season_id, "league", "", team_id, r["pos"],
            r["mp"], r["w"], r["d"], r["l"], r["gf"], r["ga"], r["gd"], r["pts"],
            json.dumps(last5, ensure_ascii=False),
        ))
    if batch:
        upsert_many(SQL_UPSERT_STANDINGS, batch)

# ===== 2) 유럽대항전 그룹/리그페이즈 standings (v3 fixtures로 계산) =====
def build_euro_phase_standings_for_season_db(league_id:int, season_id:int):
    """
    fixtures(+stage_groups)만으로 그룹/리그페이즈 standings 계산
    - group-stage(type_id=223) & status='past' 만 사용
    - group_id 가 있으면 phase='group' (group_name별로)
    - group_id 가 NULL이면 phase='league_phase'
    """
    rows = fetch_all("""
      SELECT
        f.home_team_id, f.away_team_id, f.home_score, f.away_score, f.starting_at,
        f.group_id, COALESCE(g.name, '') AS group_name
      FROM fixtures f
      LEFT JOIN stage_groups g ON g.group_id = f.group_id
      WHERE f.league_id = %s AND f.season_id = %s
        AND f.status = 'past'
        AND f.stage_type_id = %s
      ORDER BY f.starting_at ASC
    """, (league_id, season_id, STAGE_TYPE_GROUP))

    # 그룹/리그페이즈로 분배
    from collections import defaultdict
    groups: Dict[str, List[Tuple[int,int,Optional[int],Optional[int],str]]] = defaultdict(list)
    league_phase_games: List[Tuple[int,int,Optional[int],Optional[int],str]] = []

    for h,a,hs,as_,dt, gid, gname in rows:
        tup = (h,a,hs,as_,dt)
        if gid is None:   # 리그 페이즈
            league_phase_games.append(tup)
        else:             # 그룹 스테이지
            name = gname.strip() or f"Group {gid}"
            groups[name].append(tup)

    def _agg(games: List[Tuple]) -> List[Tuple[Dict, List[str]]]:
        latest_by_team = defaultdict(list)  # 최신 경기부터 넣기 위해 뒤에서 last5 처리
        agg = defaultdict(lambda: {"team_id":0,"mp":0,"w":0,"d":0,"l":0,"gf":0,"ga":0,"gd":0,"pts":0})
        # rows는 ASC이므로 최신순 last5를 위해 역방향으로 last5를 만들 때 reversed 사용
        for h,a,hs,as_,dt in games:
            if hs is None or as_ is None: continue
            latest_by_team[h].append((h,a,hs,as_,dt))
            latest_by_team[a].append((h,a,hs,as_,dt))
            for tid, gf, ga in [(h,hs,as_), (a,as_,hs)]:
                agg[tid]["team_id"]=tid
                agg[tid]["mp"] += 1
                agg[tid]["gf"] += gf
                agg[tid]["ga"] += ga
            if hs > as_:
                agg[h]["w"] += 1; agg[h]["pts"] += 3; agg[a]["l"] += 1
            elif hs < as_:
                agg[a]["w"] += 1; agg[a]["pts"] += 3; agg[h]["l"] += 1
            else:
                agg[h]["d"] += 1; agg[h]["pts"] += 1
                agg[a]["d"] += 1; agg[a]["pts"] += 1
        for r in agg.values():
            r["gd"] = r["gf"] - r["ga"]
        ranked = _rank_rows(list(agg.values()))
        out = []
        for r in ranked:
            out.append((r, _last5_for_team(latest_by_team[r["team_id"]], r["team_id"])))
        return out

    # 업서트: 그룹
    for gname, games in groups.items():
        pack = _agg(games)
        batch = [(
            league_id, season_id, "group", gname, r["team_id"], r["pos"],
            r["mp"], r["w"], r["d"], r["l"], r["gf"], r["ga"], r["gd"], r["pts"],
            json.dumps(last5, ensure_ascii=False)
        ) for (r,last5) in pack]
        if batch: upsert_many(SQL_UPSERT_STANDINGS, batch)

    # 업서트: 리그 페이즈
    if league_phase_games:
        pack = _agg(league_phase_games)
        batch = [(
            league_id, season_id, "league_phase", "", r["team_id"], r["pos"],
            r["mp"], r["w"], r["d"], r["l"], r["gf"], r["ga"], r["gd"], r["pts"],
            json.dumps(last5, ensure_ascii=False)
        ) for (r,last5) in pack]
        if batch: upsert_many(SQL_UPSERT_STANDINGS, batch)

# ===== 3) 토너먼트 브래킷 (유럽/리그컵) =====
def build_knockout_brackets_for_season(league_id:int, season_id:int):
    """
    fixtures(DB)에서 토너먼트 라운드(16강 이상)를 tie 단위로 저장.
    승자 결정 우선순위:
      1) 합계 다득점
      2) (UEFA 2020/21 시즌까지) 원정 다득점
      3) 승부차기 스코어 (마지막으로 승부차기가 있었던 경기 기준)
    단판이면 그 경기 스코어/승부차기로 판정.
    """
    # 시즌 시작연도(UEFA 원정다득점 규정 적용 여부 판단용)
    row = fetch_all("SELECT name, starting_at FROM seasons WHERE season_id=%s", (season_id,))
    start_year = None
    if row:
        n = row[0][0] or ""
        import re
        m = re.search(r"(\d{4})\s*[/\-–]", n)
        if m:
            start_year = int(m.group(1))
        elif row[0][1]:
            try:
                start_year = int(str(row[0][1])[:4])
            except:
                start_year = None

    # 필요한 컬럼에 '승부차기 스코어' 포함
    rows = fetch_all("""
      SELECT fixture_id, home_team_id, away_team_id,
             home_score, away_score, home_penalty_score, away_penalty_score,
             round_name, COALESCE(leg_number, 1) AS leg_number, starting_at
      FROM fixtures
      WHERE league_id=%s AND season_id=%s AND status='past'
        AND (
          LOWER(round_name) LIKE 'round of 16%%' OR
          LOWER(round_name) LIKE 'quarter%%'     OR
          LOWER(round_name) LIKE 'semi%%'        OR
          LOWER(round_name) = 'final'            OR
          LOWER(round_name) LIKE '1/8%%'         OR
          LOWER(round_name) LIKE 'knockout round%%'
        )
    """, (league_id, season_id))

    # 라운드/페어 정규화
    grouped = defaultdict(list)
    for fxid, h, a, hs, as_, p_h, p_a, rnd, leg, dt in rows:
        rname = _normalize_knockout_round(rnd or "")
        t1, t2 = (h, a) if h < a else (a, h)  # pair normalization
        grouped[(rname, t1, t2)].append((fxid, h, a, hs, as_, p_h, p_a, leg, dt))

    batch = []
    for (rname, t1, t2), games in grouped.items():
        # 시간 기준 정렬(동시킷 대비 fixture_id 보조 키)
        games.sort(key=lambda x: (x[8], x[7], x[0]))  # (starting_at, leg_number, fixture_id)

        # 합계/원정/승부차기 집계
        agg1 = agg2 = 0
        away1 = away2 = 0

        # 마지막으로 '승부차기 스코어가 기록된' 경기 찾기
        last_pen_game = None

        for fxid, h, a, hs, as_, p_h, p_a, leg, dt in games:
            team1_home = (h == t1)
            g1 = (hs if team1_home else as_) or 0
            g2 = (as_ if team1_home else hs) or 0
            agg1 += g1
            agg2 += g2

            # UEFA 원정다득점은 2021/22 폐지 → 2020/21(=start_year <= 2020)까지만 적용
            if league_id in (2, 5, 2286) and (start_year is not None and start_year <= 2020):
                if team1_home:
                    # team2가 원정
                    away2 += g2
                else:
                    # team1이 원정
                    away1 += g1

            if (p_h is not None) or (p_a is not None):
                last_pen_game = (fxid, h, a, p_h, p_a)

        # 단판/2차전 고정 표기를 위해 첫 경기와 마지막 경기를 뽑음
        l1 = games[0] if len(games) >= 1 else None
        l2 = games[-1] if len(games) >= 2 else None

        # 승자 판정
        winner = None
        if agg1 != agg2:
            winner = t1 if agg1 > agg2 else t2
        elif league_id in (2, 5, 2286) and (start_year is not None and start_year <= 2020) and (away1 != away2):
            winner = t1 if away1 > away2 else t2
        elif last_pen_game:
            _, h, a, p_h, p_a = last_pen_game
            pen1 = p_h if h == t1 else p_a
            pen2 = p_a if h == t1 else p_h
            # 승부차기 스코어가 둘 다 0/NULL일 수는 없지만, 방어적으로 처리
            if (pen1 or 0) != (pen2 or 0):
                winner = t1 if (pen1 or 0) > (pen2 or 0) else t2

        # 업서트 페이로드 준비
        def _parts(g):
            if not g: return (None, None, None, None, None)
            fxid, h, a, hs, as_, p_h, p_a, leg, dt = g
            return (fxid, h, a, hs, as_)

        fx1, h1, a1, hs1, as1 = _parts(l1)
        fx2, h2, a2, hs2, as2 = _parts(l2)

        batch.append((
            league_id, season_id, rname, t1, t2,
            fx1, h1, a1, hs1, as1,
            fx2, h2, a2, hs2, as2,
            agg1, agg2, winner
        ))

    if batch:
        upsert_many(SQL_UPSERT_TIE, batch)

# ===== 4) 엔트리: 전체 빌드 & 현재 시즌 갱신 =====
def build_all_standings():
    sm = SportmonksClient()

    # 빅5 리그 시즌 목록
    seasons = fetch_all("""
      SELECT season_id, league_id FROM seasons
      WHERE league_id IN (%s,%s,%s,%s,%s)
        AND (starting_at IS NOT NULL AND ending_at IS NOT NULL)
    """ % tuple(["%s"]*5), BIG5_LEAGUE_IDS)
    # 리그 standings
    for sid, lid in seasons:
        build_league_standings_for_season(lid, sid)

    # 유럽/컵 시즌 목록(2017~현재)
    euro_cup = fetch_all("""
      SELECT season_id, league_id FROM seasons
      WHERE league_id IN (2,5,2286)
    """)
    for sid, lid in euro_cup:
        build_euro_phase_standings_for_season_db(lid, sid)
        # 브래킷은 기존 build_knockout_brackets_for_season(lid, sid) 그대로 사용

def refresh_current_standings():
    current = fetch_all("""
      SELECT season_id, league_id FROM seasons WHERE is_current=1
        AND league_id IN (8,82,301,384,564, 2,5,2286, 24,27,390,570)
    """)
    for sid, lid in current:
        if lid in (8,82,301,384,564):
            build_league_standings_for_season(lid, sid)
        if lid in (2,5,2286):
            build_euro_phase_standings_for_season_db(lid, sid)
        if lid in (2,5,2286,24,27,390,570):
            build_knockout_brackets_for_season(lid, sid)

# ===== 5) 순위 등락 계산: "전경기 대비" =====
def compute_rank_delta_since_last_match(team_id:int, league_id:int, season_id:int) -> Tuple[int,str]:
    """
    팀의 '직전 경기' 전후 standings를 비교해 등락 산출.
    리그(빅5) 한정.
    반환: (delta, symbol)  ex) (+2, '▲'), (-1, '▼'), (0, '—')
    """
    # 마지막 종료 경기 시각
    row = fetch_all("""
      SELECT starting_at, fixture_id, home_team_id, away_team_id
      FROM fixtures
      WHERE league_id=%s AND season_id=%s AND status='past'
        AND (home_team_id=%s OR away_team_id=%s)
      ORDER BY starting_at DESC LIMIT 1
    """, (league_id, season_id, team_id, team_id))
    if not row:
        return (0, "—")
    last_dt = row[0][0]

    # 직전 경기 이전까지의 standings
    # (임시 계산: standings 테이블을 사용하지 않고, fixtures 시점 조건으로 계산)
    before = _compute_position_asof(league_id, season_id, cutoff=last_dt, include_cutoff=False)
    after  = _compute_position_asof(league_id, season_id, cutoff=last_dt, include_cutoff=True)

    pos_b = before.get(team_id)
    pos_a = after.get(team_id)
    if pos_b is None or pos_a is None:
        return (0, "—")
    delta = pos_b - pos_a  # 순위가 올라가면 + (ex: 7->5 => +2)
    symbol = "▲" if delta > 0 else ("▼" if delta < 0 else "—")
    return (delta, symbol)

def _compute_position_asof(league_id:int, season_id:int, cutoff:str, include_cutoff:bool) -> Dict[int,int]:
    """
    cutoff 시각 이전(포함여부 선택)의 경기만으로 리그 standings를 재계산하여 {team_id: position}
    """
    cmp = "<=" if include_cutoff else "<"
    sql = f"""
    SELECT home_team_id, away_team_id, home_score, away_score
    FROM fixtures
    WHERE league_id=%s AND season_id=%s AND status='past'
      AND starting_at {cmp} %s
    """
    rows = fetch_all(sql, (league_id, season_id, cutoff))
    agg: Dict[int, Dict] = defaultdict(lambda: {"team_id":0,"mp":0,"w":0,"d":0,"l":0,"gf":0,"ga":0,"gd":0,"pts":0})
    for h,a,hs,as_ in rows:
        if hs is None or as_ is None: continue
        for tid, gf, ga in [(h, hs, as_), (a, as_, hs)]:
            agg[tid]["team_id"]=tid
            agg[tid]["mp"] += 1
            agg[tid]["gf"] += gf
            agg[tid]["ga"] += ga
        if hs > as_:
            agg[h]["w"] += 1; agg[h]["pts"] += 3
            agg[a]["l"] += 1
        elif hs < as_:
            agg[a]["w"] += 1; agg[a]["pts"] += 3
            agg[h]["l"] += 1
        else:
            agg[h]["d"] += 1; agg[h]["pts"] += 1
            agg[a]["d"] += 1; agg[a]["pts"] += 1
    for r in agg.values():
        r["gd"] = r["gf"] - r["ga"]
    ranked = _rank_rows(list(agg.values()))
    return { r["team_id"]: r["pos"] for r in ranked }