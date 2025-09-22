# python/one_touch_loader/loaders/big5_bootstrap.py
from __future__ import annotations

from typing import Dict, Iterable, List, Optional, Tuple, Set, DefaultDict
from collections import defaultdict
from datetime import datetime

from ..core.db import upsert_many, fetch_all
from ..core.sportmonks import SportmonksClient
from ..core.db import execute

# =========================
# Upsert SQL
# =========================
SQL_UPSERT_LEAGUE = """
INSERT INTO leagues (league_id, name, image_path)
VALUES (%s, %s, %s)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  image_path = VALUES(image_path)
"""

SQL_UPSERT_SEASON = """
INSERT INTO seasons (season_id, league_id, name, is_current, starting_at, ending_at)
VALUES (%s, %s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  league_id = VALUES(league_id),
  name = VALUES(name),
  is_current = VALUES(is_current),
  starting_at = VALUES(starting_at),
  ending_at = VALUES(ending_at)
"""

SQL_UPSERT_TEAM = """
INSERT INTO teams (team_id, name, short_code, image_path)
VALUES (%s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  short_code = VALUES(short_code),
  image_path = VALUES(image_path)
"""

# fixtures: stage/group 메타 + 승부차기 스코어 포함 버전
# fixtures: stage/group 메타 + 승부차기 스코어 포함 버전
SQL_UPSERT_FIXTURE = """
INSERT INTO fixtures (
  fixture_id, season_id, league_id,
  home_team_id, away_team_id,
  competition_type, round_name, stage_type_id, stage_id, group_id,
  leg_number, status, starting_at,
  home_score, away_score, home_penalty_score, away_penalty_score
)
VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  season_id          = VALUES(season_id),
  league_id          = VALUES(league_id),
  home_team_id       = VALUES(home_team_id),
  away_team_id       = VALUES(away_team_id),
  competition_type   = VALUES(competition_type),
  round_name         = VALUES(round_name),
  stage_type_id      = VALUES(stage_type_id),
  stage_id           = VALUES(stage_id),
  group_id           = VALUES(group_id),
  leg_number         = VALUES(leg_number),
  status             = VALUES(status),
  starting_at        = VALUES(starting_at),
  home_score         = VALUES(home_score),
  away_score         = VALUES(away_score),
  home_penalty_score = VALUES(home_penalty_score),
  away_penalty_score = VALUES(away_penalty_score)
"""

# stage / group 메타
SQL_UPSERT_STAGE = """
INSERT INTO stages (stage_id, league_id, season_id, type_id, name)
VALUES (%s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  league_id=VALUES(league_id),
  season_id=VALUES(season_id),
  type_id=VALUES(type_id),
  name=VALUES(name)
"""

SQL_UPSERT_GROUP_META = """
INSERT INTO stage_groups (group_id, stage_id, league_id, season_id, name)
VALUES (%s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  stage_id=VALUES(stage_id),
  league_id=VALUES(league_id),
  season_id=VALUES(season_id),
  name=VALUES(name)
"""

# =========================
# Constants
# =========================
BIG5_NAMES = ["Premier League", "La Liga", "Serie A", "Bundesliga", "Ligue 1"]

# 리그 ID들
BIG5_LEAGUE_IDS = [8, 82, 301, 384, 564]
EURO_LEAGUE_IDS = [2, 5, 2286]               # UCL, UEL, UECL
DOMESTIC_CUP_LEAGUE_IDS = [24, 27, 390, 570] # FA, EFL, Coppa Italia, Copa del Rey

STAGE_TYPE_GROUP = 223
STAGE_TYPE_KNOCKOUT = 224
STAGE_TYPE_QUALIFY = 225

# =========================
# Utilities
# =========================
def _pick_best_league(search_results: List[Dict], query: str) -> Optional[Dict]:
    """
    검색 결과에서 가장 적합해 보이는 리그를 하나 고른다.
    (서브타입/이름 매칭 점수 기반)
    """
    q = (query or "").lower()
    candidates = []
    for x in search_results:
        name = (x.get("name") or "").lower()
        t = x.get("type")
        st = (x.get("sub_type") or "").lower()
        score = 0
        if t == "league": score += 2
        if q in name: score += 3
        if st == "domestic": score += 2  # 국내 리그 가산점
        if "play" in st: score -= 2      # 플레이오프/플레이아웃 감점
        candidates.append((score, x))
    if not candidates:
        return None
    candidates.sort(key=lambda p: p[0], reverse=True)
    return candidates[0][1]

def _coerce_list(obj) -> list:
    if obj is None: return []
    if isinstance(obj, list): return obj
    if isinstance(obj, dict) and "data" in obj and isinstance(obj["data"], list):
        return obj["data"]
    return []

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

def _parse_iso_to_dt(s: Optional[str]) -> Optional[datetime]:
    if not s: return None
    try:
        s2 = s.replace("Z", "+00:00")
        return datetime.fromisoformat(s2).replace(tzinfo=None)
    except Exception:
        try:
            s3 = s.replace("T", " ").replace("Z", "")
            if "+" in s3:
                s3 = s3.split("+", 1)[0]
            elif len(s3) >= 6 and s3[-6] in "+-" and s3[-3] == ":":
                s3 = s3[:-6]
            return datetime.fromisoformat(s3[:19])
        except Exception:
            return None

def _parse_leg_to_int(leg) -> Optional[int]:
    if leg is None:
        return None
    if isinstance(leg, int):
        return leg
    if isinstance(leg, str):
        s = leg.strip()
        if "/" in s and s.split("/", 1)[0].strip().isdigit():
            return int(s.split("/", 1)[0].strip())
        if s.isdigit():
            return int(s)
    return None

def _safe_round_name(fx: Dict) -> str:
    """
    round_name 보정: round.name -> stage.name -> group.name -> fx.name -> "Round {round_id}" -> "Unknown"
    """
    rnd = fx.get("round")
    if isinstance(rnd, dict):
        name = rnd.get("name") or (rnd.get("data") or {}).get("name")
        if isinstance(name, str) and name.strip():
            return name.strip()
    stg = fx.get("stage")
    if isinstance(stg, dict):
        name = stg.get("name") or (stg.get("data") or {}).get("name")
        if isinstance(name, str) and name.strip():
            return name.strip()
    grp = fx.get("group")
    if isinstance(grp, dict):
        name = grp.get("name") or (grp.get("data") or {}).get("name")
        if isinstance(name, str) and name.strip():
            return name.strip()
    fname = fx.get("name")
    if isinstance(fname, str) and fname.strip():
        return fname.strip()
    rid = fx.get("round_id")
    if isinstance(rid, int):
        return f"Round {rid}"
    return "Unknown"

def _extract_home_away_ids(participants: List[Dict]) -> Tuple[Optional[int], Optional[int]]:
    home = away = None
    for p in participants or []:
        loc = ((p.get("meta") or {}).get("location") or "").lower()
        if loc == "home": home = p.get("id")
        elif loc == "away": away = p.get("id")
    return home, away

def _guess_home_away_by_scores(scores: List[Dict]) -> Tuple[Optional[int], Optional[int]]:
    home_id = away_id = None
    for s in scores or []:
        side = ((s.get("score") or {}).get("participant") or "").lower()
        pid = s.get("participant_id") or s.get("team_id") or s.get("participant")
        if side == "home" and isinstance(pid, int): home_id = pid
        elif side == "away" and isinstance(pid, int): away_id = pid
    return home_id, away_id

def _extract_scores(scores: List[Dict]) -> Tuple[Optional[int], Optional[int]]:
    if not scores: return None, None
    cur_home = cur_away = None
    last_home = last_away = None
    for s in scores:
        score_obj = s.get("score") or {}
        goals = score_obj.get("goals")
        side = (score_obj.get("participant") or "").lower()
        desc = (s.get("description") or "").upper()
        if side == "home" and isinstance(goals, int):
            last_home = goals
            if desc == "CURRENT": cur_home = goals
        elif side == "away" and isinstance(goals, int):
            last_away = goals
            if desc == "CURRENT": cur_away = goals
    if cur_home is not None and cur_away is not None: return cur_home, cur_away
    return last_home, last_away

def _extract_penalty_shootout_scores(scores: List[dict]) -> Tuple[Optional[int], Optional[int]]:
    """
    include=scores 에서 승부차기 최종 누계를 추출.
    description 에 'PEN' 문자열이 포함된 항목만 집계.
    같은 쪽은 최댓값을 채택(부분 집계 방지).
    """
    pen_h = pen_a = None
    for s in scores or []:
        desc = str(s.get("description") or "").upper()
        if "PEN" not in desc:
            continue
        sc = s.get("score") or {}
        side = str(sc.get("participant") or "").lower()
        goals = sc.get("goals")
        if not isinstance(goals, int):
            continue
        if side == "home":
            pen_h = goals if (pen_h is None or goals > pen_h) else pen_h
        elif side == "away":
            pen_a = goals if (pen_a is None or goals > pen_a) else pen_a
    return pen_h, pen_a

def _map_state_to_status(state_code: Optional[str]) -> str:
    code = (state_code or "").upper()
    if not code: return "upcoming"
    if code.startswith("INPLAY") or code in {"HT", "BREAK"}: return "live"
    if code in {"NS", "TBA"} or code.startswith("POSTP") or code.startswith("DELA"): return "upcoming"
    return "past"

def _map_league_sub_type_to_competition(sub_type: Optional[str]) -> str:
    st = (sub_type or "").lower()
    if st == "domestic": return "league"
    if st == "domestic_cup": return "domestic_cup"
    if st == "cup_international": return "europe"
    return "league"

def _parse_season_start_year(name: Optional[str]) -> Optional[int]:
    if not name: return None
    import re
    m = re.search(r"(\d{4})\s*[/\-–]\s*(\d{2,4})", name)
    if not m: return None
    return int(m.group(1))

# =========================
# Caches
# =========================
class Caches:
    def __init__(self):
        self.league_meta: Dict[int, Dict] = {}                              # league_id -> {name, image_path, sub_type}
        self.league_to_seasons: DefaultDict[int, List[int]] = defaultdict(list)  # league_id -> [season_id]
        self.season_info: Dict[int, Dict] = {}                              # season_id -> {league_id, name, start_year}

# =========================
# DB upsert helpers
# =========================
def upsert_leagues_rows(rows: List[Tuple[int, str, Optional[str]]]):
    if rows: upsert_many(SQL_UPSERT_LEAGUE, rows)

def upsert_teams_rows(rows: List[Tuple[int, str, Optional[str], Optional[str]]]):
    if rows: upsert_many(SQL_UPSERT_TEAM, rows)

def upsert_fixtures_rows(rows: List[Tuple]):
    if rows: upsert_many(SQL_UPSERT_FIXTURE, rows)

# =========================
# API helpers
# =========================
def ensure_leagues(sm: SportmonksClient, names: List[str], caches: Caches) -> None:
    rows = []
    for name in names:
        best = _pick_best_league(sm.search_leagues(name), name)
        if not best: continue
        lgid = best["id"]
        rows.append((lgid, best.get("name"), best.get("image_path")))
        caches.league_meta[lgid] = {
            "name": best.get("name"),
            "image_path": best.get("image_path"),
            "sub_type": best.get("sub_type"),
        }
    upsert_leagues_rows(rows)
    print(f"[leagues] upserted: {len(rows)}")

def ensure_leagues_by_ids(sm: SportmonksClient, league_ids: Iterable[int], caches: Caches):
    rows = []
    for lid in league_ids:
        if lid in caches.league_meta: continue
        info = sm.get_league(lid)
        if not info: continue
        rows.append((info["id"], info.get("name"), info.get("image_path")))
        caches.league_meta[info["id"]] = {
            "name": info.get("name"),
            "image_path": info.get("image_path"),
            "sub_type": info.get("sub_type"),
        }
    upsert_leagues_rows(rows)

def upsert_current_and_historical_seasons(sm: SportmonksClient, caches: Caches):
    """
    BIG5 리그의 17/18~현재 시즌 upsert + 캐시 구축
    """
    rows = []
    total = 0
    for lgid in list(caches.league_meta.keys()):
        league = sm.get_league_with_seasons(lgid)
        seasons = _coerce_list(league.get("seasons"))
        for s in seasons:
            year = int((s.get("starting_at") or "0000")[:4]) if (s.get("starting_at") or "")[:4].isdigit() \
                   else _parse_season_start_year(s.get("name"))
            if year is None or year < 2017 or year > 2025:
                continue
            sid = s["id"]
            rows.append((
                sid, lgid, s.get("name"),
                bool(s.get("is_current")),
                _normalize_dt(s.get("starting_at")),
                _normalize_dt(s.get("ending_at")),
            ))
            caches.league_to_seasons[lgid].append(sid)
            caches.season_info[sid] = {"league_id": lgid, "name": s.get("name"), "start_year": year}
            total += 1
    if rows:
        upsert_many(SQL_UPSERT_SEASON, rows)
    print(f"[seasons] upserted: {total}")

def upsert_teams_for_season(sm: SportmonksClient, season_id: int):
    rows: List[Tuple] = []; count = 0
    for team in sm.iter_teams_by_season(season_id):
        rows.append((team["id"], team.get("name"), team.get("short_code"), team.get("image_path"))); count += 1
        if len(rows) >= 500: upsert_teams_rows(rows); rows.clear()
    if rows: upsert_teams_rows(rows)
    print(f"[teams] season {season_id} upserted: {count}")

def ensure_teams_from_participants(sm: SportmonksClient, participants: List[Dict]) -> None:
    rows: List[Tuple] = []; seen: Set[int] = set()
    for p in participants or []:
        tid = p.get("id")
        if not isinstance(tid, int) or tid in seen: continue
        name = p.get("name"); short_code = p.get("short_code"); image_path = p.get("image_path")
        if not name and hasattr(sm, "get_team"):
            try:
                detail = sm.get_team(tid) or {}
                name = detail.get("name") or name
                short_code = detail.get("short_code") or short_code
                image_path = detail.get("image_path") or image_path
            except Exception:
                pass
        if not name: continue
        rows.append((tid, name, short_code, image_path)); seen.add(tid)
        if len(rows) >= 500: upsert_teams_rows(rows); rows.clear()
    if rows: upsert_teams_rows(rows)

def classify_comp_by_league_id(league_id: Optional[int], caches: Caches, sm: SportmonksClient) -> str:
    if not league_id: return "league"
    if league_id not in caches.league_meta:
        ensure_leagues_by_ids(sm, [league_id], caches)
    sub = (caches.league_meta.get(league_id) or {}).get("sub_type")
    if not sub:
        if league_id in EURO_LEAGUE_IDS: return "europe"
        if league_id in DOMESTIC_CUP_LEAGUE_IDS: return "domestic_cup"
        return "league"
    return _map_league_sub_type_to_competition(sub)

# =========================
# Domestic leagues (BIG5) via fixtures API
# =========================
def upsert_domestic_via_fixtures_api(sm: SportmonksClient, caches: Caches, states_map: Dict[int, str]) -> None:
    rows: List[Tuple] = []; total = 0
    for lid, season_ids in caches.league_to_seasons.items():
        comp_type = classify_comp_by_league_id(lid, caches, sm)  # "league"
        for sid in sorted(set(season_ids)):
            for fx in sm.iter_fixtures_by_season(sid):
                if not fx.get("starting_at"):
                    continue
                parts = _coerce_list(fx.get("participants"))
                ensure_teams_from_participants(sm, parts)

                home_id, away_id = _extract_home_away_ids(parts)
                if home_id is None or away_id is None:
                    g_home, g_away = _guess_home_away_by_scores(_coerce_list(fx.get("scores")))
                    home_id = home_id or g_home
                    away_id = away_id or g_away

                leg_number = _parse_leg_to_int(fx.get("leg"))
                state_code = (fx.get("state") or {}).get("code") or states_map.get(fx.get("state_id"))
                status = _map_state_to_status(state_code)

                st = fx.get("stage") or {}
                grp = fx.get("group") or {}
                scores_inc = _coerce_list(fx.get("scores"))

                hs = fx.get("home_score"); as_ = fx.get("away_score")
                if hs is None and as_ is None:
                    hs, as_ = _extract_scores(scores_inc)
                pen_h, pen_a = _extract_penalty_shootout_scores(scores_inc)

                rows.append((
                    fx["id"], sid, lid,
                    home_id, away_id,
                    comp_type, _safe_round_name(fx),
                    st.get("type_id"), st.get("id"), grp.get("id"),
                    leg_number, status, _normalize_dt(fx.get("starting_at")),
                    hs, as_, pen_h, pen_a
                ))
                total += 1
                if len(rows) >= 500: upsert_fixtures_rows(rows); rows.clear()
    if rows: upsert_fixtures_rows(rows)
    print(f"[fixtures] domestic via fixtures API: upserted {total}")

# =========================
# Europe: ALL seasons FULL ingest (fixtures + stage/group meta)
# =========================
def ingest_euro_all_seasons_full(sm: SportmonksClient, caches: Caches, states_map: Dict[int, str]) -> None:
    """
    UCL/UEL/UECL: 2017/18~현재 '전 경기' 인제스트
    - fixtures에 stage_type_id/stage_id/group_id + 승부차기 저장
    - stages/stage_groups 메타 upsert
    - seasons.starting_at/ending_at NULL이면 fixtures의 min/max로 보정
    """
    season_upserts = 0
    stage_rows, group_rows, fix_rows = [], [], []
    total_fixtures = 0

    for lid in EURO_LEAGUE_IDS:
        ensure_leagues_by_ids(sm, [lid], caches)
        league = sm.get_league_with_seasons(lid)
        seasons = _coerce_list(league.get("seasons"))

        for s in seasons:
            y1 = _parse_season_start_year(s.get("name")) \
                 or (int((s.get("starting_at") or "0000")[:4]) if (s.get("starting_at") or "")[:4].isdigit() else None)
            if y1 is None or y1 < 2017 or y1 > 2025:
                continue
            sid = s["id"]

            fixtures = list(sm.iter_fixtures_by_season(sid))  # include: participants;state;scores;round;stage;group

            # 시즌 시작/종료 보정
            start_norm = _normalize_dt(s.get("starting_at"))
            end_norm   = _normalize_dt(s.get("ending_at"))
            if start_norm is None or end_norm is None:
                min_dt = max_dt = None
                for fx in fixtures:
                    dt = _parse_iso_to_dt(fx.get("starting_at"))
                    if not dt: continue
                    min_dt = dt if min_dt is None or dt < min_dt else min_dt
                    max_dt = dt if max_dt is None or dt > max_dt else max_dt
                if start_norm is None and min_dt is not None:
                    start_norm = min_dt.strftime("%Y-%m-%d %H:%M:%S")
                if end_norm is None and max_dt is not None:
                    end_norm = max_dt.strftime("%Y-%m-%d %H:%M:%S")

            if start_norm and end_norm:
                upsert_many(SQL_UPSERT_SEASON, [(sid, lid, s.get("name"), bool(s.get("is_current")), start_norm, end_norm)])
                season_upserts += 1

            for fx in fixtures:
                parts = _coerce_list(fx.get("participants"))
                ensure_teams_from_participants(sm, parts)

                st = fx.get("stage") or {}
                st_id   = st.get("id")
                st_type = st.get("type_id")
                st_name = st.get("name")
                if isinstance(st_id, int) and isinstance(st_type, int) and st_name:
                    stage_rows.append((st_id, lid, sid, st_type, st_name))

                grp = fx.get("group") or {}
                g_id   = grp.get("id")
                g_name = grp.get("name")
                if isinstance(g_id, int) and g_name and isinstance(st_id, int):
                    group_rows.append((g_id, st_id, lid, sid, g_name))

                home_id, away_id = _extract_home_away_ids(parts)
                if home_id is None or away_id is None:
                    g_home, g_away = _guess_home_away_by_scores(_coerce_list(fx.get("scores")))
                    home_id = home_id or g_home
                    away_id = away_id or g_away

                state_code = (fx.get("state") or {}).get("code") or states_map.get(fx.get("state_id"))
                status     = _map_state_to_status(state_code)
                round_name = _safe_round_name(fx)
                leg_number = _parse_leg_to_int(fx.get("leg"))

                scores_inc = _coerce_list(fx.get("scores"))
                hs = fx.get("home_score"); as_ = fx.get("away_score")
                if hs is None and as_ is None:
                    hs, as_ = _extract_scores(scores_inc)
                pen_h, pen_a = _extract_penalty_shootout_scores(scores_inc)

                fix_rows.append((
                    fx["id"], sid, lid,
                    home_id, away_id,
                    "europe", round_name, st_type, st_id, g_id,
                    leg_number, status, _normalize_dt(fx.get("starting_at")),
                    hs, as_, pen_h, pen_a
                ))
                total_fixtures += 1

                if len(stage_rows) >= 500:
                    upsert_many(SQL_UPSERT_STAGE, stage_rows); stage_rows.clear()
                if len(group_rows) >= 500:
                    upsert_many(SQL_UPSERT_GROUP_META, group_rows); group_rows.clear()
                if len(fix_rows) >= 500:
                    upsert_fixtures_rows(fix_rows); fix_rows.clear()

    if stage_rows: upsert_many(SQL_UPSERT_STAGE, stage_rows)
    if group_rows: upsert_many(SQL_UPSERT_GROUP_META, group_rows)
    if fix_rows:   upsert_fixtures_rows(fix_rows)

    print(f"[seasons] euro all seasons upserted: {season_upserts}")
    print(f"[fixtures] euro all seasons (full): upserted {total_fixtures}")

# =========================
# Domestic Cups: BIG5 팀 연관 경기만 (모든 시즌)
# =========================
def upsert_domestic_cups_big5_only(sm: SportmonksClient, caches: Caches, states_map: Dict[int, str]) -> None:
    """
    FA/EFL/Coppa/Copa del Rey: 2017/18~현재 모든 시즌에서
    '그 시즌의 빅5 1부 팀'이 한 팀이라도 참가한 경기만 적재.
    stage/group 메타 + 승부차기 스코어도 함께 저장.
    """
    # 시즌 시작연도 -> 빅5 팀 집합
    year_to_big5_teams: Dict[int, Set[int]] = defaultdict(set)
    for sid, info in caches.season_info.items():
        y1 = info.get("start_year")
        if y1 is None: continue
        for t in sm.iter_teams_by_season(sid):
            tid = t.get("id")
            if isinstance(tid, int):
                year_to_big5_teams[y1].add(tid)

    stage_rows, group_rows, fix_rows = [], [], []
    total = 0

    for lid in DOMESTIC_CUP_LEAGUE_IDS:
        ensure_leagues_by_ids(sm, [lid], caches)
        league = sm.get_league_with_seasons(lid)
        seasons = _coerce_list(league.get("seasons"))

        for s in seasons:
            y1 = _parse_season_start_year(s.get("name")) \
                 or (int((s.get("starting_at") or "0000")[:4]) if (s.get("starting_at") or "")[:4].isdigit() else None)
            if y1 is None or y1 < 2017 or y1 > 2025:
                continue
            allowed = year_to_big5_teams.get(y1, set())
            if not allowed:
                continue

            sid = s["id"]
            fixtures = list(sm.iter_fixtures_by_season(sid))

            # 시즌 시작/종료 보정
            start_norm = _normalize_dt(s.get("starting_at"))
            end_norm   = _normalize_dt(s.get("ending_at"))
            if start_norm is None or end_norm is None:
                min_dt = max_dt = None
                for fx in fixtures:
                    dt = _parse_iso_to_dt(fx.get("starting_at"))
                    if not dt: continue
                    min_dt = dt if min_dt is None or dt < min_dt else min_dt
                    max_dt = dt if max_dt is None or dt > max_dt else max_dt
                if start_norm is None and min_dt is not None:
                    start_norm = min_dt.strftime("%Y-%m-%d %H:%M:%S")
                if end_norm is None and max_dt is not None:
                    end_norm = max_dt.strftime("%Y-%m-%d %H:%M:%S")
            if start_norm and end_norm:
                upsert_many(SQL_UPSERT_SEASON, [(sid, lid, s.get("name"), bool(s.get("is_current")), start_norm, end_norm)])

            for fx in fixtures:
                parts = _coerce_list(fx.get("participants"))
                pids = {p.get("id") for p in parts if isinstance(p.get("id"), int)}
                if not pids or not (pids & allowed):
                    continue

                ensure_teams_from_participants(sm, parts)

                st = fx.get("stage") or {}
                st_id   = st.get("id")
                st_type = st.get("type_id")
                st_name = st.get("name")
                if isinstance(st_id, int) and isinstance(st_type, int) and st_name:
                    stage_rows.append((st_id, lid, sid, st_type, st_name))

                grp = fx.get("group") or {}
                g_id   = grp.get("id")
                g_name = grp.get("name")
                if isinstance(g_id, int) and g_name and isinstance(st_id, int):
                    group_rows.append((g_id, st_id, lid, sid, g_name))

                home_id, away_id = _extract_home_away_ids(parts)
                if home_id is None or away_id is None:
                    g_home, g_away = _guess_home_away_by_scores(_coerce_list(fx.get("scores")))
                    home_id = home_id or g_home
                    away_id = away_id or g_away

                state_code = (fx.get("state") or {}).get("code") or states_map.get(fx.get("state_id"))
                status     = _map_state_to_status(state_code)
                round_name = _safe_round_name(fx)
                leg_number = _parse_leg_to_int(fx.get("leg"))

                scores_inc = _coerce_list(fx.get("scores"))
                hs = fx.get("home_score"); as_ = fx.get("away_score")
                if hs is None and as_ is None:
                    hs, as_ = _extract_scores(scores_inc)
                pen_h, pen_a = _extract_penalty_shootout_scores(scores_inc)

                fix_rows.append((
                    fx["id"], sid, lid,
                    home_id, away_id,
                    "domestic_cup", round_name, st_type, st_id, g_id,
                    leg_number, status, _normalize_dt(fx.get("starting_at")),
                    hs, as_, pen_h, pen_a
                ))
                total += 1

                if len(stage_rows) >= 500:
                    upsert_many(SQL_UPSERT_STAGE, stage_rows); stage_rows.clear()
                if len(group_rows) >= 500:
                    upsert_many(SQL_UPSERT_GROUP_META, group_rows); group_rows.clear()
                if len(fix_rows) >= 500:
                    upsert_fixtures_rows(fix_rows); fix_rows.clear()

    if stage_rows: upsert_many(SQL_UPSERT_STAGE, stage_rows)
    if group_rows: upsert_many(SQL_UPSERT_GROUP_META, group_rows)
    if fix_rows:   upsert_fixtures_rows(fix_rows)

    print(f"[fixtures] domestic cups (big5-related, all seasons): upserted {total}")

def finalize_knockout_winners():
    sql_pen_leg2 = """
    UPDATE knockout_ties kt
    JOIN fixtures f2 ON f2.fixture_id = kt.leg2_fixture_id
    SET kt.winner_team_id = CASE
      WHEN f2.home_penalty_score > f2.away_penalty_score THEN f2.home_team_id
      WHEN f2.home_penalty_score < f2.away_penalty_score THEN f2.away_team_id
      ELSE kt.winner_team_id
    END,
        kt.updated_at = NOW()
    WHERE kt.winner_team_id IS NULL
      AND kt.aggregate_team1 = kt.aggregate_team2
      AND kt.leg2_fixture_id IS NOT NULL
      AND f2.home_penalty_score IS NOT NULL
      AND f2.away_penalty_score IS NOT NULL;
    """
    sql_pen_single = """
    UPDATE knockout_ties kt
    JOIN fixtures f1 ON f1.fixture_id = kt.leg1_fixture_id
    LEFT JOIN fixtures f2 ON f2.fixture_id = kt.leg2_fixture_id
    SET kt.winner_team_id = CASE
      WHEN f1.home_penalty_score > f1.away_penalty_score THEN f1.home_team_id
      WHEN f1.home_penalty_score < f1.away_penalty_score THEN f1.away_team_id
      ELSE kt.winner_team_id
    END,
        kt.updated_at = NOW()
    WHERE kt.winner_team_id IS NULL
      AND kt.aggregate_team1 = kt.aggregate_team2
      AND kt.leg2_fixture_id IS NULL
      AND f1.home_penalty_score IS NOT NULL
      AND f1.away_penalty_score IS NOT NULL;
    """
    sql_away_goals = """
    UPDATE knockout_ties kt
    JOIN seasons s           ON s.season_id = kt.season_id
    JOIN fixtures l1         ON l1.fixture_id = kt.leg1_fixture_id
    JOIN fixtures l2         ON l2.fixture_id = kt.leg2_fixture_id
    SET kt.winner_team_id = CASE
      WHEN
        (CASE
           WHEN l1.away_team_id = kt.team1_id THEN l1.away_score
           WHEN l2.away_team_id = kt.team1_id THEN l2.away_score
           ELSE 0
         END)
        >
        (CASE
           WHEN l1.away_team_id = kt.team2_id THEN l1.away_score
           WHEN l2.away_team_id = kt.team2_id THEN l2.away_score
           ELSE 0
         END)
      THEN kt.team1_id

      WHEN
        (CASE
           WHEN l1.away_team_id = kt.team1_id THEN l1.away_score
           WHEN l2.away_team_id = kt.team1_id THEN l2.away_score
           ELSE 0
         END)
        <
        (CASE
           WHEN l1.away_team_id = kt.team2_id THEN l1.away_score
           WHEN l2.away_team_id = kt.team2_id THEN l2.away_score
           ELSE 0
         END)
      THEN kt.team2_id

      ELSE kt.winner_team_id
    END,
        kt.updated_at = NOW()
    WHERE kt.winner_team_id IS NULL
      AND kt.aggregate_team1 = kt.aggregate_team2
      AND kt.leg1_fixture_id IS NOT NULL
      AND kt.leg2_fixture_id IS NOT NULL
      AND kt.league_id IN (2,5)
      AND YEAR(s.starting_at) <= 2020;
    """
    updated = 0
    updated += execute(sql_pen_leg2)
    updated += execute(sql_pen_single)
    updated += execute(sql_away_goals)
    return updated

# =========================
# Entry point
# =========================
def run_big5_bootstrap(league_names: Optional[List[str]] = None) -> None:
    sm = SportmonksClient()
    caches = Caches()
    names = league_names or BIG5_NAMES

    # 1) BIG5 리그 메타 upsert
    ensure_leagues(sm, names, caches)

    # 2) BIG5 시즌 upsert + season_info/league->seasons 캐시
    upsert_current_and_historical_seasons(sm, caches)
    states_map = sm.get_states_map()

    # 3) 시즌별 팀 upsert
    for league_id, season_ids in caches.league_to_seasons.items():
        for season_id in sorted(set(season_ids)):
            upsert_teams_for_season(sm, season_id)

    # 4) BIG5 리그: fixtures API로 전 경기 적재(플레이오프 포함)
    upsert_domestic_via_fixtures_api(sm, caches, states_map)

    # 5) 유럽대항전(UCL/UEL/UECL): 17/18~현재 '전 경기' + stage/group 메타 + 승부차기 저장
    ingest_euro_all_seasons_full(sm, caches, states_map)

    # 6) 국내컵(FA/EFL/Coppa/Copa del Rey): 17/18~현재, BIG5 팀 관련 경기만 저장
    upsert_domestic_cups_big5_only(sm, caches, states_map)

    print("Big5 bootstrap done.")

    updated = finalize_knockout_winners()
    
    print(f"[knockout_winners] backfilled: {updated}")