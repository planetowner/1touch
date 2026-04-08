"""
Best Eleven loader
==================
1) fetch_and_store_lineups  – Sportmonks fixture → fixture_lineups / fixture_formations
2) compute_best_eleven      – formation_field slot 별 선발 횟수·출장 시간으로 Best 11 계산
3) refresh_best_eleven      – 최근 종료 경기 라인업 적재 → 영향 팀만 재계산
"""
from __future__ import annotations

from typing import Dict, List, Optional, Set, Tuple

from ..core.db import fetch_all, upsert_many, execute
from ..core.sportmonks import SportmonksClient


# ---------------------------------------------------------------------------
# SQL
# ---------------------------------------------------------------------------

SQL_RECENTLY_FINISHED_WITHOUT_LINEUP = """
SELECT f.fixture_id, f.season_id, f.home_team_id, f.away_team_id
FROM fixtures f
WHERE f.status = 'past'
  AND f.starting_at >= DATE_SUB(NOW(), INTERVAL %s DAY)
  AND NOT EXISTS (
    SELECT 1 FROM fixture_lineups fl WHERE fl.fixture_id = f.fixture_id
  )
ORDER BY f.starting_at DESC
"""

SQL_ALL_PAST_WITHOUT_LINEUP = """
SELECT f.fixture_id, f.season_id, f.home_team_id, f.away_team_id
FROM fixtures f
JOIN seasons s ON s.season_id = f.season_id
WHERE f.status = 'past'
  AND s.is_current = 1
  AND NOT EXISTS (
    SELECT 1 FROM fixture_lineups fl WHERE fl.fixture_id = f.fixture_id
  )
ORDER BY f.starting_at ASC
"""

SQL_UPSERT_LINEUP = """
INSERT INTO fixture_lineups (
  fixture_id, season_id, team_id, player_id,
  player_name, player_image,
  position_id, position_name, detailed_position_name,
  formation_field, type_id, minutes_played
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  player_name     = VALUES(player_name),
  player_image    = VALUES(player_image),
  position_id     = VALUES(position_id),
  position_name   = VALUES(position_name),
  detailed_position_name = VALUES(detailed_position_name),
  formation_field = VALUES(formation_field),
  type_id         = VALUES(type_id),
  minutes_played  = VALUES(minutes_played)
"""

SQL_UPSERT_FORMATION = """
INSERT INTO fixture_formations (fixture_id, season_id, team_id, formation)
VALUES (%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  formation = VALUES(formation)
"""

# 최다 사용 포메이션
SQL_DOMINANT_FORMATION = """
SELECT formation, COUNT(*) AS cnt
FROM fixture_formations
WHERE team_id = %s AND season_id = %s
GROUP BY formation
ORDER BY cnt DESC
LIMIT 1
"""

# 해당 포메이션을 쓴 경기 목록
SQL_FIXTURE_IDS_WITH_FORMATION = """
SELECT fixture_id
FROM fixture_formations
WHERE team_id = %s AND season_id = %s AND formation = %s
"""

# slot별 선발 랭킹 (해당 포메이션 경기만)
SQL_SLOT_RANKING = """
SELECT
  fl.formation_field,
  fl.player_id,
  fl.player_name,
  fl.player_image,
  fl.position_id,
  fl.position_name,
  fl.detailed_position_name,
  COUNT(*)             AS starts,
  COALESCE(SUM(fl.minutes_played), 0) AS total_minutes
FROM fixture_lineups fl
WHERE fl.team_id = %s
  AND fl.season_id = %s
  AND fl.type_id = 11
  AND fl.fixture_id IN ({placeholders})
GROUP BY fl.formation_field,
         fl.player_id, fl.player_name, fl.player_image,
         fl.position_id, fl.position_name, fl.detailed_position_name
ORDER BY fl.formation_field, starts DESC, total_minutes DESC
"""

SQL_DELETE_BEST_ELEVEN = """
DELETE FROM team_best_eleven
WHERE team_id = %s AND season_id = %s
"""

SQL_INSERT_BEST_ELEVEN = """
INSERT INTO team_best_eleven (
  team_id, season_id, formation, slot_key, slot_index,
  player_id, player_name, player_image,
  position_name, detailed_position_name,
  starts, total_minutes
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
"""


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def _safe_int(v) -> Optional[int]:
    try:
        return int(v) if v is not None else None
    except Exception:
        return None


def _player_display_name(player: Dict) -> str:
    return (
        player.get("display_name")
        or player.get("common_name")
        or player.get("name")
        or f"player:{player.get('id', '?')}"
    )


MINUTES_PLAYED_TYPE_ID = 119  # Sportmonks type_id for "Minutes Played"

def _extract_minutes_played(details: list) -> int:
    """lineups.details 배열에서 Minutes Played 값을 꺼낸다.
    Sportmonks는 details에 type 객체를 포함하지 않고 type_id만 내려주므로
    type_id=119 (Minutes Played) 로 직접 매칭한다.
    """
    for d in details or []:
        if d.get("type_id") == MINUTES_PLAYED_TYPE_ID:
            val = d.get("data", {}).get("value") if isinstance(d.get("data"), dict) else d.get("value")
            return _safe_int(val) or 0
    return 0


def _parse_formation_to_expected_slots(formation: str) -> List[str]:
    """
    포메이션 문자열 → expected slot_key 목록.
    예: "4-3-3" → ["1:1", "2:1","2:2","2:3","2:4", "3:1","3:2","3:3", "4:1","4:2","4:3"]
    row 1 = GK (항상 1명), row 2~ = 포메이션 숫자 순서.
    """
    parts = formation.split("-")
    slots = ["1:1"]  # GK
    for row_idx, count_str in enumerate(parts, start=2):
        count = int(count_str)
        for col in range(1, count + 1):
            slots.append(f"{row_idx}:{col}")
    return slots


def _formation_field_sort_key(field: str) -> Tuple[int, int]:
    """formation_field "row:col" → (row, col) 로 정렬 키를 만든다."""
    try:
        parts = field.split(":")
        return (int(parts[0]), int(parts[1]))
    except Exception:
        return (99, 99)


# ---------------------------------------------------------------------------
# 1. 라인업 적재
# ---------------------------------------------------------------------------

def fetch_and_store_lineups(fixture_id: int, season_id: int, sm: SportmonksClient) -> Set[int]:
    """
    단일 fixture의 라인업·포메이션을 Sportmonks에서 가져와 DB에 upsert.
    반환: 이 경기에 참여한 team_id set
    """
    data = sm.get_fixture_lineups(fixture_id)
    if not data:
        return set()

    team_ids: Set[int] = set()

    # --- formations ---
    formations = data.get("formations") or []
    formation_rows = []
    for fm in formations:
        tid = _safe_int(fm.get("participant_id")) or _safe_int(fm.get("team_id"))
        formation = fm.get("formation")
        if tid and formation:
            formation_rows.append((fixture_id, season_id, tid, formation))
            team_ids.add(tid)

    if formation_rows:
        upsert_many(SQL_UPSERT_FORMATION, formation_rows)

    # --- lineups ---
    lineups = data.get("lineups") or []
    lineup_rows = []
    for entry in lineups:
        tid = _safe_int(entry.get("team_id"))
        pid = _safe_int(entry.get("player_id"))
        type_id = _safe_int(entry.get("type_id"))
        if not tid or not pid or type_id is None:
            continue

        team_ids.add(tid)

        player = entry.get("player") or {}
        position = entry.get("position") or {}
        detailed_pos = entry.get("detailedposition") or entry.get("detailedPosition") or {}
        details = entry.get("details") or []

        lineup_rows.append((
            fixture_id,
            season_id,
            tid,
            pid,
            _player_display_name(player),
            player.get("image_path"),
            _safe_int(position.get("id")) or _safe_int(entry.get("position_id")),
            position.get("name"),
            detailed_pos.get("name"),
            entry.get("formation_field"),
            type_id,
            _extract_minutes_played(details),
        ))

    if lineup_rows:
        upsert_many(SQL_UPSERT_LINEUP, lineup_rows)

    print(f"  [lineup] fixture {fixture_id}: formations={len(formation_rows)} lineups={len(lineup_rows)}")
    return team_ids


# ---------------------------------------------------------------------------
# 2. Best Eleven 계산
# ---------------------------------------------------------------------------

def compute_best_eleven(team_id: int, season_id: int) -> None:
    """
    1) 최다 포메이션 결정
    2) 해당 포메이션 경기만 필터
    3) formation_field slot별 top-1 선발 선수 선택
    4) team_best_eleven 테이블에 저장
    """
    # Step 1: dominant formation
    rows = fetch_all(SQL_DOMINANT_FORMATION, (team_id, season_id))
    if not rows:
        print(f"  [best11] team {team_id} season {season_id}: no formations found, skip")
        return
    formation = rows[0][0]
    formation_count = rows[0][1]

    # Step 2: 해당 포메이션을 쓴 경기 IDs
    fix_rows = fetch_all(SQL_FIXTURE_IDS_WITH_FORMATION, (team_id, season_id, formation))
    fixture_ids = [int(r[0]) for r in fix_rows]
    if not fixture_ids:
        return

    # Step 3: slot별 랭킹
    placeholders = ",".join(["%s"] * len(fixture_ids))
    sql = SQL_SLOT_RANKING.replace("{placeholders}", placeholders)
    params = (team_id, season_id, 11, *fixture_ids)
    # SQL_SLOT_RANKING 에서 type_id = 11 은 이미 하드코딩 되어 있으므로 params 재조정
    params = (team_id, season_id, *fixture_ids)
    ranking_rows = fetch_all(sql, params)

    # ranking_rows를 slot별로 그룹핑 (정렬 유지: starts DESC, total_minutes DESC)
    # r = (formation_field, player_id, player_name, player_image,
    #      position_id, position_name, detailed_position_name, starts, total_minutes)
    from collections import defaultdict
    slot_candidates: Dict[str, List[Tuple]] = defaultdict(list)
    for r in ranking_rows:
        slot = r[0]
        if slot:
            slot_candidates[slot].append(r)

    # 포메이션에서 expected slot 목록 계산
    expected_slots = _parse_formation_to_expected_slots(formation)

    # slot별 top-1 선택 (이미 뽑힌 선수는 제외)
    best: Dict[str, Tuple] = {}
    used_player_ids: Set[int] = set()

    for slot in expected_slots:
        for candidate in slot_candidates.get(slot, []):
            pid = int(candidate[1])
            if pid not in used_player_ids:
                best[slot] = candidate
                used_player_ids.add(pid)
                break

    # fallback: 빈 slot이 있으면 같은 row의 다른 slot 후보 중에서 채우기
    for slot in expected_slots:
        if slot in best:
            continue
        row = slot.split(":")[0]
        # 같은 row에 속한 모든 후보를 모아서 시도
        row_candidates = []
        for s, candidates in slot_candidates.items():
            if s.startswith(f"{row}:"):
                row_candidates.extend(candidates)
        # starts DESC, total_minutes DESC 정렬
        row_candidates.sort(key=lambda x: (-int(x[7]), -int(x[8])))
        for candidate in row_candidates:
            pid = int(candidate[1])
            if pid not in used_player_ids:
                best[slot] = candidate
                used_player_ids.add(pid)
                break

    if not best:
        print(f"  [best11] team {team_id} season {season_id}: no starters found, skip")
        return

    # Step 4: DB 저장 (delete-insert)
    execute(SQL_DELETE_BEST_ELEVEN, (team_id, season_id))

    insert_rows = []
    for idx, slot_key in enumerate(expected_slots):
        if slot_key not in best:
            continue
        r = best[slot_key]
        insert_rows.append((
            team_id, season_id, formation, slot_key, idx,
            int(r[1]),   # player_id
            r[2],        # player_name
            r[3],        # player_image
            r[5],        # position_name
            r[6],        # detailed_position_name
            int(r[7]),   # starts
            int(r[8]),   # total_minutes
        ))

    if insert_rows:
        upsert_many(SQL_INSERT_BEST_ELEVEN, insert_rows)

    slot_count = len(insert_rows)
    missing = [s for s in expected_slots if s not in best]
    warn = f" ⚠ missing slots: {missing}" if missing else ""
    print(
        f"  [best11] team {team_id} season {season_id}: "
        f"formation={formation} (used {formation_count}x), slots={slot_count}/11{warn}"
    )


# ---------------------------------------------------------------------------
# 3. 증분 리프레시 (최근 종료 경기 → 해당 팀만)
# ---------------------------------------------------------------------------

def refresh_best_eleven(lookback_days: int = 2) -> None:
    """
    최근 N일 내 종료된 경기 중 아직 라인업이 없는 것을 적재하고,
    영향받은 팀만 Best Eleven을 재계산한다.
    """
    rows = fetch_all(SQL_RECENTLY_FINISHED_WITHOUT_LINEUP, (lookback_days,))
    if not rows:
        print("[best11] no new finished fixtures to process")
        return

    sm = SportmonksClient()
    affected: Dict[int, int] = {}  # team_id → season_id

    for fixture_id, season_id, home_id, away_id in rows:
        try:
            team_ids = fetch_and_store_lineups(int(fixture_id), int(season_id), sm)
            for tid in team_ids:
                affected[tid] = int(season_id)
        except Exception as e:
            print(f"  [best11] ERROR fixture {fixture_id}: {e}")
            continue

    print(f"[best11] lineups fetched: fixtures={len(rows)}, affected teams={len(affected)}")

    for tid, sid in affected.items():
        try:
            compute_best_eleven(tid, sid)
        except Exception as e:
            print(f"  [best11] ERROR compute team {tid}: {e}")

    print(f"[best11] refresh done")


def full_build_best_eleven() -> None:
    """
    현재 시즌의 모든 과거 경기에 대해 라인업을 적재하고 Best Eleven을 계산한다.
    초기 구축용.
    """
    rows = fetch_all(SQL_ALL_PAST_WITHOUT_LINEUP)
    if not rows:
        print("[best11] no past fixtures without lineups")
        return

    sm = SportmonksClient()
    affected: Dict[int, int] = {}
    total = len(rows)

    for i, (fixture_id, season_id, home_id, away_id) in enumerate(rows, 1):
        try:
            team_ids = fetch_and_store_lineups(int(fixture_id), int(season_id), sm)
            for tid in team_ids:
                affected[tid] = int(season_id)
        except Exception as e:
            print(f"  [best11] ERROR fixture {fixture_id}: {e}")
            continue

        if i % 50 == 0:
            print(f"[best11] lineups progress: {i}/{total}")

    print(f"[best11] lineups done: fixtures={total}, affected teams={len(affected)}")

    for tid, sid in affected.items():
        try:
            compute_best_eleven(tid, sid)
        except Exception as e:
            print(f"  [best11] ERROR compute team {tid}: {e}")

    print(f"[best11] full build done")


# ---------------------------------------------------------------------------
# 4. 검증
# ---------------------------------------------------------------------------

def validate_best_eleven() -> None:
    """
    team_best_eleven 테이블 전체를 검증한다.
    1) expected slot 수 != 실제 row 수
    2) GK (1:1) 미존재
    3) starter인데 total_minutes = 0
    """
    # 1) slot count 검사
    groups = fetch_all("""
        SELECT team_id, season_id, formation, COUNT(*) as cnt
        FROM team_best_eleven
        GROUP BY team_id, season_id, formation
    """)
    incomplete = []
    for team_id, season_id, formation, cnt in groups:
        expected = _parse_formation_to_expected_slots(str(formation))
        if int(cnt) < len(expected):
            incomplete.append((team_id, season_id, formation, int(cnt), len(expected)))

    print(f"[validate] 1) Incomplete teams: {len(incomplete)} / {len(groups)}")
    for tid, sid, fm, actual, expected in incomplete[:10]:
        print(f"  team={tid} season={sid} formation={fm}: {actual}/{expected} slots")
    if len(incomplete) > 10:
        print(f"  ... and {len(incomplete) - 10} more")

    # 2) GK (1:1) 존재 여부
    no_gk = fetch_all("""
        SELECT team_id, season_id, formation
        FROM team_best_eleven
        GROUP BY team_id, season_id, formation
        HAVING SUM(CASE WHEN slot_key = '1:1' THEN 1 ELSE 0 END) = 0
    """)
    print(f"\n[validate] 2) Teams without GK (1:1): {len(no_gk)}")
    for r in no_gk[:10]:
        print(f"  team={r[0]} season={r[1]} formation={r[2]}")

    # 3) total_minutes = 0
    zero_min = fetch_all("""
        SELECT team_id, season_id, slot_key, player_name, starts, total_minutes
        FROM team_best_eleven
        WHERE total_minutes = 0
        ORDER BY starts DESC
    """)
    print(f"\n[validate] 3) Rows with total_minutes=0: {len(zero_min)}")
    for r in zero_min[:10]:
        print(f"  team={r[0]} season={r[1]} slot={r[2]} player={r[3]} starts={r[4]}")
    if len(zero_min) > 10:
        print(f"  ... and {len(zero_min) - 10} more")

    # summary
    total_teams = len(groups)
    ok_teams = total_teams - len(incomplete)
    print(f"\n[validate] Summary: {ok_teams}/{total_teams} teams fully complete")
