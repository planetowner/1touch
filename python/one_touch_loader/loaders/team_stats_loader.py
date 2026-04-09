from __future__ import annotations

from typing import Dict, List, Optional, Tuple

from ..core.db import fetch_all, upsert_many
from ..core.sportmonks import SportmonksClient


# =========================================================
# SQL
# =========================================================

SQL_SELECT_FIXTURE_META_BY_ID = """
SELECT
    f.fixture_id,
    f.season_id,
    f.league_id,
    f.home_team_id,
    f.away_team_id,
    f.status
FROM fixtures f
WHERE f.fixture_id = %s
"""

SQL_SELECT_FIXTURE_IDS_BY_SEASON = """
SELECT
    f.fixture_id
FROM fixtures f
WHERE f.season_id = %s
ORDER BY f.starting_at, f.fixture_id
"""

SQL_SELECT_FIXTURE_IDS_BY_SEASON_AND_STATUS = """
SELECT
    f.fixture_id
FROM fixtures f
WHERE f.season_id = %s
  AND f.status = %s
ORDER BY f.starting_at, f.fixture_id
"""

SQL_SELECT_CURRENT_SEASON_IDS = """
SELECT s.season_id
FROM seasons s
WHERE s.is_current = 1
ORDER BY s.season_id
"""

SQL_UPSERT_FIXTURE_TEAM_STAT_RAW = """
INSERT INTO fixture_team_stats_raw (
  fixture_id,
  season_id,
  league_id,
  team_id,
  opponent_team_id,
  location,
  stat_type_id,
  stat_code,
  stat_name,
  stat_value_num,
  raw_data_json,
  collected_at
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,NOW())
ON DUPLICATE KEY UPDATE
  season_id        = VALUES(season_id),
  league_id        = VALUES(league_id),
  opponent_team_id = VALUES(opponent_team_id),
  location         = VALUES(location),
  stat_type_id     = VALUES(stat_type_id),
  stat_name        = VALUES(stat_name),
  stat_value_num   = VALUES(stat_value_num),
  raw_data_json    = VALUES(raw_data_json),
  collected_at     = VALUES(collected_at)
"""


# =========================================================
# helpers
# =========================================================

def _safe_int(v) -> Optional[int]:
    try:
        return int(v) if v is not None else None
    except Exception:
        return None


def _safe_float(v) -> Optional[float]:
    if v is None:
        return None
    if isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return float(v)
    if isinstance(v, str):
        s = v.strip()
        if not s:
            return None
        try:
            return float(s)
        except Exception:
            return None
    return None


def _participants_map(participants: List[Dict]) -> Dict[int, str]:
    """
    participant_id -> location(home/away)
    """
    out: Dict[int, str] = {}
    for p in participants or []:
        pid = _safe_int(p.get("id"))
        if pid is None:
            continue
        location = ((p.get("meta") or {}).get("location") or "").lower()
        if location in {"home", "away"}:
            out[pid] = location
    return out


def _extract_stat_numeric_value(stat_data: Dict) -> Optional[float]:
    """
    fixture statistics는 지금까지 확인한 구조상 대부분 {"value": 숫자} 형태.
    혹시 문자열 숫자여도 float로 파싱.
    """
    if not isinstance(stat_data, dict):
        return None
    return _safe_float(stat_data.get("value"))


def _normalize_rows_from_fixture_payload(
    fixture_meta: Tuple,
    fixture_payload: Dict,
) -> List[Tuple]:
    """
    fixture_payload(data.statistics[]) -> fixture_team_stats_raw upsert rows
    """
    fixture_id, season_id, league_id, home_team_id, away_team_id, _status = fixture_meta

    participants = fixture_payload.get("participants") or []
    participant_location = _participants_map(participants)

    rows: List[Tuple] = []

    for item in fixture_payload.get("statistics") or []:
        participant_id = _safe_int(item.get("participant_id"))
        if participant_id is None:
            continue

        location = (item.get("location") or participant_location.get(participant_id) or "").lower()
        if location not in {"home", "away"}:
            # location 판단 실패 시 participant_id로 추정
            if participant_id == int(home_team_id):
                location = "home"
            elif participant_id == int(away_team_id):
                location = "away"
            else:
                continue

        if participant_id == int(home_team_id):
            team_id = int(home_team_id)
            opponent_team_id = int(away_team_id)
        elif participant_id == int(away_team_id):
            team_id = int(away_team_id)
            opponent_team_id = int(home_team_id)
        else:
            # participants include와 fixtures 테이블이 어긋난 경우 방어
            continue

        type_obj = item.get("type") or {}
        stat_type_id = _safe_int(item.get("type_id"))
        stat_code = type_obj.get("code")
        stat_name = type_obj.get("name")
        stat_data = item.get("data") or {}

        if stat_type_id is None or not stat_code:
            continue

        stat_value_num = _extract_stat_numeric_value(stat_data)

        rows.append((
            int(fixture_id),
            int(season_id),
            int(league_id),
            int(team_id),
            int(opponent_team_id),
            location,
            int(stat_type_id),
            str(stat_code),
            stat_name,
            stat_value_num,
            __import__("json").dumps(stat_data, ensure_ascii=False),
        ))

    return rows


# =========================================================
# main functions
# =========================================================

def refresh_fixture_team_stats(fixture_id: int) -> None:
    """
    단일 fixture의 경기별 팀 통계를 Sportmonks에서 불러와
    fixture_team_stats_raw 테이블에 upsert.
    """
    fixture_rows = fetch_all(SQL_SELECT_FIXTURE_META_BY_ID, (fixture_id,))
    if not fixture_rows:
        print(f"[team-stats] fixture not found in DB: fixture_id={fixture_id}")
        return

    fixture_meta = fixture_rows[0]
    sm = SportmonksClient()
    fixture_payload = sm.get_fixture_with_statistics(fixture_id)

    rows = _normalize_rows_from_fixture_payload(fixture_meta, fixture_payload)

    if rows:
        upsert_many(SQL_UPSERT_FIXTURE_TEAM_STAT_RAW, rows)

    print(
        f"[team-stats] fixture {fixture_id}: "
        f"normalized_rows={len(rows)}"
    )


def refresh_fixture_team_stats_for_season(
    season_id: int,
    only_status: Optional[str] = None,
) -> None:
    """
    시즌 내 fixture 전체에 대해 경기별 팀 통계를 적재.
    only_status:
      - None: 시즌 내 모든 fixture
      - 'past' / 'live' / 'upcoming'
    """
    if only_status:
        fixture_rows = fetch_all(SQL_SELECT_FIXTURE_IDS_BY_SEASON_AND_STATUS, (season_id, only_status))
    else:
        fixture_rows = fetch_all(SQL_SELECT_FIXTURE_IDS_BY_SEASON, (season_id,))

    fixture_ids = [int(row[0]) for row in fixture_rows]
    total = 0

    for fixture_id in fixture_ids:
        refresh_fixture_team_stats(fixture_id)
        total += 1

    print(
        f"[team-stats] season {season_id}: "
        f"fixtures_processed={total} status_filter={only_status or 'ALL'}"
    )


def refresh_fixture_team_stats_for_current_seasons(
    only_status: Optional[str] = "past",
) -> None:
    """
    현재 시즌들에 대해 경기별 팀 통계를 적재.
    기본은 finished('past') 경기만 적재.
    """
    season_rows = fetch_all(SQL_SELECT_CURRENT_SEASON_IDS)
    season_ids = [int(row[0]) for row in season_rows]

    total_seasons = 0
    for season_id in season_ids:
        refresh_fixture_team_stats_for_season(season_id, only_status=only_status)
        total_seasons += 1

    print(
        f"[team-stats] current seasons refresh done: "
        f"seasons={total_seasons} status_filter={only_status or 'ALL'}"
    )