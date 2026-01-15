# python/one_touch_loader/loaders/points_pace.py
from __future__ import annotations
import re
from collections import defaultdict
from typing import Dict, List, Tuple

from one_touch_loader.core.db import fetch_all, upsert_many

BIG5_LEAGUE_IDS = [8, 82, 301, 384, 564]

# ────────────────────────────────────────────────────────────────────────────────
# SQL
# ────────────────────────────────────────────────────────────────────────────────

# 리그·시즌별 '완료된' 경기만 조회
# round_name 안의 숫자를 뽑아 라운드 번호로 사용하고(예: "Matchweek 3" → 3),
# 숫자가 없는 경우에는 날짜 순으로 1,2,3,...을 부여해서 정렬 안정성 확보
SQL_SELECT_FIXTURES_FOR_LEAGUE_SEASON = r"""
SELECT
    f.fixture_id,
    f.league_id,
    f.season_id,
    f.starting_at,
    f.round_name,
    f.home_team_id,
    f.away_team_id,
    f.home_score,
    f.away_score,
    COALESCE(
        CAST(REGEXP_SUBSTR(f.round_name, '[0-9]+') AS UNSIGNED),
        ROW_NUMBER() OVER (
            PARTITION BY f.league_id, f.season_id
            ORDER BY f.starting_at, f.fixture_id
        )
    ) AS round_no
FROM fixtures f
WHERE f.league_id = %s
  AND f.season_id = %s
  AND f.competition_type = 'league'
  AND f.home_score IS NOT NULL
  AND f.away_score IS NOT NULL
ORDER BY round_no, f.starting_at, f.fixture_id
"""

SQL_SELECT_SEASONS_SINCE_1718 = r"""
SELECT s.season_id, s.name
FROM seasons s
WHERE s.league_id = %s
  AND (
    -- '2017/18', '2017-2018', '2017–18' 등 모든 표기 허용
    CAST(SUBSTRING_INDEX(REPLACE(REPLACE(REPLACE(s.name,'–','-'),'/', '-'), ' ', ''), '-', 1) AS UNSIGNED) >= 2017
  )
ORDER BY s.name
"""

SQL_UPSERT_POINTS_PACE = r"""
INSERT INTO points_pace (
  league_id, season_id, team_id, round_no, match_date, cumulative_points
) VALUES (%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  -- 동일 라운드가 재계산되면 날짜는 최신으로, 누적 승점은 더 큰 값으로 보존
  match_date = VALUES(match_date),
  cumulative_points = GREATEST(cumulative_points, VALUES(cumulative_points))
"""

# ────────────────────────────────────────────────────────────────────────────────
# 내부 유틸
# ────────────────────────────────────────────────────────────────────────────────

def _calc_points(home_score: int, away_score: int) -> Tuple[int, int]:
    """리그 경기 승점 계산 (승 3, 무 1, 패 0)."""
    if home_score > away_score:
        return 3, 0
    if home_score < away_score:
        return 0, 3
    return 1, 1

def _rows_for_league_season(league_id: int, season_id: int) -> List[Tuple]:
    fixtures = fetch_all(SQL_SELECT_FIXTURES_FOR_LEAGUE_SEASON, (league_id, season_id))

    # team_id -> [(round_no, match_date, gained_points)]
    per_team: Dict[int, List[Tuple[int, str, int]]] = defaultdict(list)

    for (
        fixture_id, lid, sid, starting_at, round_name,
        home_tid, away_tid, home_sc, away_sc, round_no
    ) in fixtures:
        ph, pa = _calc_points(int(home_sc), int(away_sc))
        per_team[int(home_tid)].append((int(round_no), starting_at, ph))
        per_team[int(away_tid)].append((int(round_no), starting_at, pa))

    # 누적 승점으로 변환
    upserts: List[Tuple] = []
    for team_id, items in per_team.items():
        # 라운드 번호, 날짜, fixture_id 순으로 안정 정렬 (동라운드 재편성 대비)
        items.sort(key=lambda t: (t[0], t[1]))
        cum = 0
        last_round = None
        # 동일 라운드에 같은 팀 경기가 2개 이상 들어오는 비정상 데이터 방지:
        # 한 라운드당 하나만 집계(최신 날짜를 우선)
        round_to_latest: Dict[int, Tuple[str, int]] = {}
        for rnd, dt, gain in items:
            if rnd not in round_to_latest or dt > round_to_latest[rnd][0]:
                round_to_latest[rnd] = (dt, gain)
        for rnd in sorted(round_to_latest.keys()):
            dt, gain = round_to_latest[rnd]
            cum += gain
            upserts.append((league_id, season_id, team_id, rnd, dt, cum))

    return upserts

# ────────────────────────────────────────────────────────────────────────────────
# 공개 API
# ────────────────────────────────────────────────────────────────────────────────

def build_points_pace_all() -> None:
    """빅5 전 시즌(2017/18~현재) 누적 승점 곡선 전량 빌드."""
    for lid in BIG5_LEAGUE_IDS:
        seasons = fetch_all(SQL_SELECT_SEASONS_SINCE_1718, (lid,))
        total = 0
        for sid, sname in seasons:
            rows = _rows_for_league_season(int(lid), int(sid))
            if rows:
                upsert_many(SQL_UPSERT_POINTS_PACE, rows)
                total += len(rows)
        print(f"[points_pace] league {lid} upserted rows: {total}")

def refresh_points_pace_current() -> None:
    """빅5 각 리그의 '현재 시즌'만 경량 갱신."""
    for lid in BIG5_LEAGUE_IDS:
        # 가장 최신 시즌을 이름의 시작연도로 판정
        seasons = fetch_all(SQL_SELECT_SEASONS_SINCE_1718, (lid,))
        if not seasons:
            continue
        # s.name의 시작연도 기준으로 최대
        def y1(sname: str) -> int:
            m = re.search(r'(\d{4})\s*[/\-–]', sname or '')
            return int(m.group(1)) if m else -1
        sid, sname = max(seasons, key=lambda r: y1(r[1]))
        rows = _rows_for_league_season(int(lid), int(sid))
        if rows:
            upsert_many(SQL_UPSERT_POINTS_PACE, rows)
        print(f"[points_pace] league {lid} current season {sid} refreshed: {len(rows)} rows")
