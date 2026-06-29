"""
Best Eleven loader
==================
1) fetch_and_store_lineups  – Sportmonks fixture → fixture_lineups / fixture_formations
2) compute_best_eleven      – formation_field slot 별 선발 횟수·출장 시간으로 Best 11 계산
3) refresh_best_eleven      – 최근 종료 경기 라인업 적재 → 영향 팀만 재계산
"""
from __future__ import annotations

from typing import Dict, List, Set, Tuple

import requests

from ..core.db import fetch_all, upsert_many, execute
from ..core.sportmonks import SportmonksClient


# ---------------------------------------------------------------------------
# SQL
# ---------------------------------------------------------------------------

# Every current-season past fixture that still lacks lineups. This is the exact
# set of work, so the sync is self-healing: it always retries any missing
# lineup regardless of age (no time-window assumption that lineups arrive — and
# that the job runs — within N days). The is_current scope keeps the set small
# in steady state (only the latest matchday before lineups load) and avoids
# forever-rescanning historical fixtures that may never get lineup data.
SQL_CURRENT_PAST_FIXTURES_WITHOUT_LINEUP = """
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
ORDER BY cnt DESC, formation ASC
LIMIT 1
"""
# formation ASC is a deterministic tiebreak when two formations are used the
# same number of times: it only breaks exact ties (cnt is the real criterion),
# so the chosen dominant formation is reproducible instead of DB-order-arbitrary.

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
ORDER BY fl.formation_field, starts DESC, total_minutes DESC, fl.player_id ASC
"""
# player_id ASC is a deterministic final tiebreak: starts/total_minutes are the
# real ranking, but slot assignment seeds greedily from this candidate order, so
# without a stable tie-break two players equal on both would make the Best
# Eleven non-deterministic across runs.

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

MINUTES_PLAYED_TYPE_ID = 119  # Sportmonks type_id for "Minutes Played"
STARTING_LINEUP_TYPE_ID = 11


def _extract_minutes_played(details: list, *, require_minutes: bool) -> int | None:
    """
    Sportmonks v3 lineup details에서 minutes played를 읽는다.

    확인된 구조:
      detail["type_id"] == 119
      detail["data"]["value"] = minutes played
    """
    for detail in details:
        if detail["type_id"] == MINUTES_PLAYED_TYPE_ID:
            return int(detail["data"]["value"])

    if require_minutes:
        raise RuntimeError("Starting lineup player is missing minutes played detail type_id=119.")

    return None


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


# ---------------------------------------------------------------------------
# 1. 라인업 적재
# ---------------------------------------------------------------------------

def fetch_and_store_lineups(fixture_id: int, season_id: int, sm: SportmonksClient) -> Set[int]:
    """
    단일 fixture의 라인업·포메이션을 Sportmonks에서 가져와 DB에 upsert.
    반환: 이 경기에 참여한 team_id set
    """
    data = sm.get_fixture_lineups(fixture_id)

    team_ids: Set[int] = set()

    # --- formations ---
    formations = data["formations"]
    formation_rows = []

    for formation_entry in formations:
        participant_id = formation_entry["participant_id"]
        formation = formation_entry["formation"]

        # Skip formation rows without an identified team or a formation string.
        if participant_id is None or not formation:
            continue

        team_id = int(participant_id)
        formation_rows.append((fixture_id, season_id, team_id, formation))
        team_ids.add(team_id)

    if formation_rows:
        upsert_many(SQL_UPSERT_FORMATION, formation_rows)

    # --- lineups ---
    lineups = data["lineups"]
    lineup_rows = []

    for entry in lineups:
        # Sportmonks occasionally returns a lineup slot with no identified
        # player (player_id/player are null). It can't be stored (player_id is
        # NOT NULL) and is unusable for Best Eleven, so skip it rather than
        # aborting the whole fixture.
        if entry.get("player_id") is None:
            continue

        team_id = int(entry["team_id"])
        player_id = int(entry["player_id"])
        type_id = int(entry["type_id"])

        player = entry["player"]
        position = entry["position"]
        detailed_position = entry["detailedposition"]
        details = entry["details"]

        # Minutes can be absent even for starters (Sportmonks sometimes omits the
        # type_id=119 detail). Store NULL instead of dropping the whole fixture —
        # otherwise one such starter loses every other player in the lineup too.
        minutes_played = _extract_minutes_played(details, require_minutes=False)

        position_id = entry["position_id"]

        team_ids.add(team_id)

        lineup_rows.append(
            (
                fixture_id,
                season_id,
                team_id,
                player_id,
                player["display_name"] if player is not None else None,
                player["image_path"] if player is not None else None,
                int(position_id) if position_id is not None else None,
                position["name"] if position is not None else None,
                detailed_position["name"] if detailed_position is not None else None,
                entry["formation_field"],
                type_id,
                minutes_played,
            )
        )

    if lineup_rows:
        upsert_many(SQL_UPSERT_LINEUP, lineup_rows)

    print(
        f"  [lineup] fixture {fixture_id}: "
        f"formations={len(formation_rows)} lineups={len(lineup_rows)}"
    )

    return team_ids


# ---------------------------------------------------------------------------
# 2. Best Eleven 계산
# ---------------------------------------------------------------------------

def _assign_players_to_slots(
    expected_slots: List[str],
    slot_candidates: Dict[str, List[Tuple]],
) -> Dict[str, Tuple]:
    """slot ↔ 선수 최대 이분매칭. 한 선수는 한 slot에만.

    먼저 slot 순서대로 "그 slot의 1순위 미사용 선수"를 집는 greedy로 시드한다
    (후보가 겹치지 않는 일반 팀은 이 단계에서 끝나고 기존 동작과 동일하다).
    그 뒤 표본이 적어 선수가 여러 포지션을 오간 탓에 비어버린 slot이 있으면,
    이미 배정된 선수를 그 선수의 다른 후보 slot으로 양보시키는 증강 경로(Kuhn)로
    최대한 채운다. 증강은 빈 slot에서 끝나는 경로에서만 커밋되므로, 이미 11칸이
    모두 찬 팀은 절대 재배치되지 않는다(결과 불변).
    """
    candidate_ids: Dict[str, List[int]] = {
        slot: [int(c[1]) for c in slot_candidates.get(slot, [])]
        for slot in expected_slots
    }
    row_by_slot_player: Dict[str, Dict[int, Tuple]] = {
        slot: {int(c[1]): c for c in slot_candidates.get(slot, [])}
        for slot in expected_slots
    }

    match_slot: Dict[str, int] = {}  # slot -> player_id
    match_player: Dict[int, str] = {}  # player_id -> slot

    def augment(player_id: int, seen_slots: Set[str]) -> bool:
        for slot in expected_slots:
            if player_id in candidate_ids[slot] and slot not in seen_slots:
                seen_slots.add(slot)
                if slot not in match_slot or augment(match_slot[slot], seen_slots):
                    match_slot[slot] = player_id
                    match_player[player_id] = slot
                    return True
        return False

    # 1) greedy 시드 (기존 동작 보존)
    used: Set[int] = set()
    for slot in expected_slots:
        for player_id in candidate_ids[slot]:
            if player_id not in used:
                match_slot[slot] = player_id
                match_player[player_id] = slot
                used.add(player_id)
                break

    # 2) 남은 빈 slot을 증강 경로로 채움. 미배정 선수를 후보 등장 순서(SQL의
    #    starts DESC, total_minutes DESC, player_id ASC를 그대로 보존)대로
    #    결정적으로 순회한다. set으로 순회하면 hash 버킷 순서라 비결정적이고,
    #    다중 매칭 상황에서 랭킹 낮은 선수가 먼저 빈 slot을 차지할 수 있다.
    seen_player_ids: Set[int] = set()
    ordered_player_ids: List[int] = []
    for slot in expected_slots:
        for player_id in candidate_ids[slot]:
            if player_id not in seen_player_ids:
                seen_player_ids.add(player_id)
                ordered_player_ids.append(player_id)

    for player_id in ordered_player_ids:
        if player_id not in match_player:
            augment(player_id, set())

    return {
        slot: row_by_slot_player[slot][player_id]
        for slot, player_id in match_slot.items()
    }


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
    params = (team_id, season_id, *fixture_ids)
    ranking_rows = fetch_all(sql, params)

    # ranking_rows를 slot별로 그룹핑 (정렬 유지: starts DESC, total_minutes DESC)
    # r = (formation_field, player_id, player_name, player_image,
    #      position_id, position_name, detailed_position_name, starts, total_minutes)
    from collections import defaultdict

    slot_candidates: Dict[str, List[Tuple]] = defaultdict(list)

    for row in ranking_rows:
        slot = row[0]
        if slot:
            slot_candidates[slot].append(row)

    # 포메이션에서 expected slot 목록 계산
    expected_slots = _parse_formation_to_expected_slots(formation)

    # slot별 선수 배정 (한 선수는 한 slot)
    best = _assign_players_to_slots(expected_slots, slot_candidates)

    # 기존 row 제거 후 새 결과 저장
    execute(SQL_DELETE_BEST_ELEVEN, (team_id, season_id))

    insert_rows = []

    for index, slot_key in enumerate(expected_slots):
        if slot_key not in best:
            continue

        row = best[slot_key]

        insert_rows.append(
            (
                team_id,
                season_id,
                formation,
                slot_key,
                index,
                int(row[1]),   # player_id
                row[2],        # player_name
                row[3],        # player_image
                row[5],        # position_name
                row[6],        # detailed_position_name
                int(row[7]),   # starts
                int(row[8]),   # total_minutes
            )
        )

    if insert_rows:
        upsert_many(SQL_INSERT_BEST_ELEVEN, insert_rows)

    slot_count = len(insert_rows)
    missing = [slot for slot in expected_slots if slot not in best]
    warn = f" ⚠ missing slots: {missing}" if missing else ""

    print(
        f"  [best11] team {team_id} season {season_id}: "
        f"formation={formation} (used {formation_count}x), slots={slot_count}/11{warn}"
    )


# ---------------------------------------------------------------------------
# 3. Best Eleven 동기화 (라인업 없는 현재 시즌 과거 경기 → 영향 팀 재계산)
# ---------------------------------------------------------------------------

def refresh_best_eleven() -> None:
    """
    라인업이 아직 없는 현재 시즌 과거 경기의 라인업을 적재하고, 영향받은 팀의
    Best Eleven을 재계산한다.

    "채워야 할 집합"(is_current + 라인업 없음)을 그대로 처리하므로 초기 구축과
    증분 갱신을 겸한다. 누락된 라인업은 경기 시점과 무관하게 항상 재시도되어
    시간 윈도우 밖으로 새는 경기가 없고, 정상 상태에서는 처리 대상이 작다.
    """
    rows = fetch_all(SQL_CURRENT_PAST_FIXTURES_WITHOUT_LINEUP)

    if not rows:
        print("[best11] no current-season fixtures awaiting lineups")
        return

    sm = SportmonksClient()
    affected: Dict[int, int] = {}  # team_id → season_id
    total = len(rows)

    for index, (fixture_id, season_id, home_id, away_id) in enumerate(rows, 1):
        try:
            team_ids = fetch_and_store_lineups(int(fixture_id), int(season_id), sm)

            for team_id in team_ids:
                affected[team_id] = int(season_id)

        except (requests.RequestException, ValueError) as error:
            # Sportmonks network/HTTP failures, plus malformed Sportmonks
            # payloads (SportmonksClient raises ValueError on shape mismatch)
            # and bad int() conversions — skip this fixture and continue the
            # batch. Code-logic errors (KeyError, TypeError, AttributeError,
            # mysql errors) bubble up so they surface immediately instead of
            # silently dropping fixtures.
            print(f"  [best11] ERROR fixture {fixture_id}: {error}")
            continue

        if index % 50 == 0:
            print(f"[best11] lineups progress: {index}/{total}")

    print(f"[best11] lineups done: fixtures={total}, affected teams={len(affected)}")

    for team_id, season_id in affected.items():
        try:
            compute_best_eleven(team_id, season_id)

        except ValueError as error:
            # compute_best_eleven is DB-only; ValueError here means a malformed
            # formation string in fixture_formations (int(parts[0]) in
            # _parse_formation_to_expected_slots). Everything else (KeyError,
            # mysql errors) bubbles up.
            print(f"  [best11] ERROR compute team {team_id}: {error}")

    print("[best11] refresh done")


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
    groups = fetch_all(
        """
        SELECT team_id, season_id, formation, COUNT(*) as cnt
        FROM team_best_eleven
        GROUP BY team_id, season_id, formation
        """
    )

    incomplete = []

    for team_id, season_id, formation, count in groups:
        expected = _parse_formation_to_expected_slots(str(formation))

        if int(count) < len(expected):
            incomplete.append((team_id, season_id, formation, int(count), len(expected)))

    print(f"[validate] 1) Incomplete teams: {len(incomplete)} / {len(groups)}")

    for team_id, season_id, formation, actual, expected in incomplete[:10]:
        print(f"  team={team_id} season={season_id} formation={formation}: {actual}/{expected} slots")

    if len(incomplete) > 10:
        print(f"  ... and {len(incomplete) - 10} more")

    # 2) GK (1:1) 존재 여부
    no_gk = fetch_all(
        """
        SELECT team_id, season_id, formation
        FROM team_best_eleven
        GROUP BY team_id, season_id, formation
        HAVING SUM(CASE WHEN slot_key = '1:1' THEN 1 ELSE 0 END) = 0
        """
    )

    print(f"\n[validate] 2) Teams without GK (1:1): {len(no_gk)}")

    for row in no_gk[:10]:
        print(f"  team={row[0]} season={row[1]} formation={row[2]}")

    # 3) total_minutes = 0
    zero_min = fetch_all(
        """
        SELECT team_id, season_id, slot_key, player_name, starts, total_minutes
        FROM team_best_eleven
        WHERE total_minutes = 0
        ORDER BY starts DESC
        """
    )

    print(f"\n[validate] 3) Rows with total_minutes=0: {len(zero_min)}")

    for row in zero_min[:10]:
        print(
            f"  team={row[0]} season={row[1]} "
            f"slot={row[2]} player={row[3]} starts={row[4]}"
        )

    if len(zero_min) > 10:
        print(f"  ... and {len(zero_min) - 10} more")

    # summary
    total_teams = len(groups)
    ok_teams = total_teams - len(incomplete)

    print(f"\n[validate] Summary: {ok_teams}/{total_teams} teams fully complete")