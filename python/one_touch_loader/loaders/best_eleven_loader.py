"""
Best Eleven loader
==================
1) fetch_and_store_lineups  – Sportmonks fixture → fixture_lineups / fixture_formations
2) compute_best_eleven      – Big 5 팀의 동일 시즌명 전 대회 라인업을 합산해 Best 11 계산
3) refresh_best_eleven      – 현재 캠페인의 미완 라인업 적재 → 영향 팀만 재계산
"""
from __future__ import annotations

from typing import Dict, List, Optional, Set, Tuple

import requests

from ..core.db import fetch_all, transaction, upsert_many
from ..core.sportmonks import SportmonksClient


# ---------------------------------------------------------------------------
# SQL
# ---------------------------------------------------------------------------

BIG5_LEAGUE_IDS: Tuple[int, ...] = (8, 82, 301, 384, 564)
BIG5_LEAGUE_IDS_SQL = ", ".join(str(league_id) for league_id in BIG5_LEAGUE_IDS)

# A team-fixture lineup is usable only when it has a non-empty formation and
# exactly 11 distinct starters occupying 11 distinct, non-empty formation
# slots. Keep this predicate in one place so refresh selection and Best Eleven
# computation cannot disagree about which fixtures are complete.
def _sql_has_valid_starters(fixture_id_expr: str, team_id_expr: str) -> str:
    return f"""
    EXISTS (
      SELECT 1
      FROM fixture_lineups fl_valid
      WHERE fl_valid.fixture_id = {fixture_id_expr}
        AND fl_valid.team_id = {team_id_expr}
        AND fl_valid.type_id = 11
        AND fl_valid.formation_field IS NOT NULL
        AND TRIM(fl_valid.formation_field) <> ''
      GROUP BY fl_valid.fixture_id, fl_valid.team_id
      HAVING COUNT(*) = 11
         AND COUNT(DISTINCT fl_valid.player_id) = 11
         AND COUNT(DISTINCT fl_valid.formation_field) = 11
    )
    """.strip()


def _sql_has_valid_team_lineup(fixture_id_expr: str, team_id_expr: str) -> str:
    return f"""
    EXISTS (
      SELECT 1
      FROM fixture_formations ff_valid
      WHERE ff_valid.fixture_id = {fixture_id_expr}
        AND ff_valid.team_id = {team_id_expr}
        AND TRIM(ff_valid.formation) <> ''
        AND {_sql_has_valid_starters(fixture_id_expr, team_id_expr)}
    )
    """.strip()


# Every past fixture in a current Big 5 club campaign for which either
# participant does not yet have a valid formation plus 11 complete starter
# slots. Competition season IDs differ (league/cup/Europe), so the fixture's
# season name is matched to the tracked club's current domestic-league season
# name instead of trusting the competition season's is_current flag.
SQL_CURRENT_PAST_FIXTURES_INCOMPLETE_LINEUP = f"""
SELECT f.fixture_id, f.season_id, f.home_team_id, f.away_team_id
FROM fixtures f
JOIN seasons source_season ON source_season.season_id = f.season_id
WHERE f.status = 'past'
  AND EXISTS (
    SELECT 1
    FROM team_seasons ts
    JOIN seasons canonical_season
      ON canonical_season.season_id = ts.season_id
    WHERE ts.team_id IN (f.home_team_id, f.away_team_id)
      AND canonical_season.league_id IN ({BIG5_LEAGUE_IDS_SQL})
      AND canonical_season.is_current = 1
      AND canonical_season.name = source_season.name
  )
  AND (
    NOT {_sql_has_valid_team_lineup("f.fixture_id", "f.home_team_id")}
    OR NOT {_sql_has_valid_team_lineup("f.fixture_id", "f.away_team_id")}
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

# Source competition season -> tracked Big 5 team's canonical domestic season.
# LIMIT 2 lets the caller surface duplicate canonical memberships rather than
# silently picking one.
SQL_CANONICAL_SEASON_FOR_TEAM_SOURCE_SEASON = f"""
SELECT canonical_season.season_id
FROM seasons source_season
JOIN seasons canonical_season
  ON canonical_season.name = source_season.name
JOIN team_seasons ts
  ON ts.season_id = canonical_season.season_id
WHERE source_season.season_id = %s
  AND ts.team_id = %s
  AND canonical_season.league_id IN ({BIG5_LEAGUE_IDS_SQL})
LIMIT 2
"""


# 포메이션별 사용 경기 수. 대표 정규리그 season_id의 시즌명을 기준으로 모든
# 대회를 합산하고, 부분 라인업 경기는 포메이션 횟수와 선수 집계 모두에서 제외한다.
SQL_FORMATION_COUNTS = f"""
SELECT ff.formation, COUNT(*) AS cnt
FROM fixture_formations ff
JOIN fixtures f
  ON f.fixture_id = ff.fixture_id
 AND f.season_id = ff.season_id
JOIN seasons source_season
  ON source_season.season_id = ff.season_id
JOIN seasons canonical_season
  ON canonical_season.season_id = %s
 AND canonical_season.name = source_season.name
JOIN team_seasons ts
  ON ts.team_id = ff.team_id
 AND ts.season_id = canonical_season.season_id
WHERE ff.team_id = %s
  AND canonical_season.league_id IN ({BIG5_LEAGUE_IDS_SQL})
  AND f.status = 'past'
  AND TRIM(ff.formation) <> ''
  AND {_sql_has_valid_starters("ff.fixture_id", "ff.team_id")}
GROUP BY ff.formation
ORDER BY cnt DESC, ff.formation ASC
"""
# formation ASC is a deterministic tiebreak when two formations are used the
# same number of times. The first row is the default/dominant formation.

# Retained for read-only diagnostics and compatibility with existing commands.
SQL_DOMINANT_FORMATION = SQL_FORMATION_COUNTS + "\nLIMIT 1"

# 같은 캠페인의 전 대회 중 해당 포메이션을 썼고 선발 11개 슬롯이 완전한 경기 목록
SQL_FIXTURE_IDS_WITH_FORMATION = f"""
SELECT ff.fixture_id
FROM fixture_formations ff
JOIN fixtures f
  ON f.fixture_id = ff.fixture_id
 AND f.season_id = ff.season_id
JOIN seasons source_season
  ON source_season.season_id = ff.season_id
JOIN seasons canonical_season
  ON canonical_season.season_id = %s
 AND canonical_season.name = source_season.name
JOIN team_seasons ts
  ON ts.team_id = ff.team_id
 AND ts.season_id = canonical_season.season_id
WHERE ff.team_id = %s
  AND canonical_season.league_id IN ({BIG5_LEAGUE_IDS_SQL})
  AND f.status = 'past'
  AND ff.formation = %s
  AND {_sql_has_valid_starters("ff.fixture_id", "ff.team_id")}
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

SQL_DELETE_BEST_ELEVEN_FORMATIONS = """
DELETE FROM team_best_eleven_formations
WHERE team_id = %s AND season_id = %s
"""

SQL_INSERT_BEST_ELEVEN_FORMATION = """
INSERT INTO team_best_eleven_formations (
  team_id, season_id, formation,
  matches_used, total_valid_matches, is_default
) VALUES (%s,%s,%s,%s,%s,%s)
"""


SQL_BIG5_CANONICAL_TEAM_SEASONS = f"""
SELECT ts.team_id, ts.season_id
FROM team_seasons ts
JOIN seasons s ON s.season_id = ts.season_id
WHERE s.league_id IN ({BIG5_LEAGUE_IDS_SQL})
  AND (%s = 0 OR s.is_current = 1)
ORDER BY s.starting_at ASC, ts.team_id ASC
"""


# Old code stored separate rows under cup/European competition season IDs.
# Only (team_id, domestic Big 5 season_id) is canonical after aggregation.
SQL_DELETE_NONCANONICAL_BEST_ELEVEN = f"""
DELETE tbe
FROM team_best_eleven tbe
LEFT JOIN team_seasons ts
  ON ts.team_id = tbe.team_id
 AND ts.season_id = tbe.season_id
LEFT JOIN seasons s
  ON s.season_id = ts.season_id
WHERE ts.team_id IS NULL
   OR s.league_id NOT IN ({BIG5_LEAGUE_IDS_SQL})
"""


SQL_COUNT_NONCANONICAL_BEST_ELEVEN = f"""
SELECT COUNT(*)
FROM team_best_eleven tbe
LEFT JOIN team_seasons ts
  ON ts.team_id = tbe.team_id
 AND ts.season_id = tbe.season_id
LEFT JOIN seasons s
  ON s.season_id = ts.season_id
WHERE ts.team_id IS NULL
   OR s.league_id NOT IN ({BIG5_LEAGUE_IDS_SQL})
"""

SQL_DELETE_NONCANONICAL_BEST_ELEVEN_FORMATIONS = f"""
DELETE tbef
FROM team_best_eleven_formations tbef
LEFT JOIN team_seasons ts
  ON ts.team_id = tbef.team_id
 AND ts.season_id = tbef.season_id
LEFT JOIN seasons s
  ON s.season_id = ts.season_id
WHERE ts.team_id IS NULL
   OR s.league_id NOT IN ({BIG5_LEAGUE_IDS_SQL})
"""

SQL_COUNT_NONCANONICAL_BEST_ELEVEN_FORMATIONS = f"""
SELECT COUNT(*)
FROM team_best_eleven_formations tbef
LEFT JOIN team_seasons ts
  ON ts.team_id = tbef.team_id
 AND ts.season_id = tbef.season_id
LEFT JOIN seasons s
  ON s.season_id = ts.season_id
WHERE ts.team_id IS NULL
   OR s.league_id NOT IN ({BIG5_LEAGUE_IDS_SQL})
"""


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

MINUTES_PLAYED_TYPE_ID = 119  # Sportmonks type_id for "Minutes Played"
STARTING_LINEUP_TYPE_ID = 11


def find_canonical_season_id(team_id: int, source_season_id: int) -> Optional[int]:
    """Map a competition season to the team's Big 5 domestic campaign season.

    League, cup and European competitions use different season IDs, while the
    shared season name (for example, 2025/2026) identifies the club campaign.
    Teams outside the tracked Big 5 team_seasons scope return None.
    """
    rows = fetch_all(
        SQL_CANONICAL_SEASON_FOR_TEAM_SOURCE_SEASON,
        (source_season_id, team_id),
    )
    if not rows:
        return None
    if len(rows) > 1:
        raise ValueError(
            f"team_id={team_id} source_season_id={source_season_id} maps to "
            f"multiple Big 5 canonical seasons: {[int(row[0]) for row in rows]}"
        )
    return int(rows[0][0])


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

    if len(slots) != 11:
        raise ValueError(
            f"Formation must describe 10 outfield players plus one goalkeeper: "
            f"formation={formation!r} slots={len(slots)}"
        )

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


def _build_formation_best_eleven_rows(
    team_id: int,
    season_id: int,
    formation: str,
) -> List[Tuple]:
    """Build exactly 11 persisted player rows for one formation."""
    fix_rows = fetch_all(
        SQL_FIXTURE_IDS_WITH_FORMATION,
        (season_id, team_id, formation),
    )
    fixture_ids = [int(row[0]) for row in fix_rows]

    if not fixture_ids:
        raise RuntimeError(
            f"team_id={team_id} canonical season_id={season_id} "
            f"formation={formation} has no valid fixtures"
        )

    placeholders = ",".join(["%s"] * len(fixture_ids))
    sql = SQL_SLOT_RANKING.replace("{placeholders}", placeholders)
    ranking_rows = fetch_all(sql, (team_id, *fixture_ids))

    # ranking_rows order is starts DESC, total_minutes DESC, player_id ASC.
    from collections import defaultdict

    slot_candidates: Dict[str, List[Tuple]] = defaultdict(list)
    for row in ranking_rows:
        slot = row[0]
        if slot:
            slot_candidates[slot].append(row)

    expected_slots = _parse_formation_to_expected_slots(formation)
    best = _assign_players_to_slots(expected_slots, slot_candidates)
    missing = [slot for slot in expected_slots if slot not in best]

    if missing:
        raise RuntimeError(
            f"team_id={team_id} canonical season_id={season_id} "
            f"formation={formation} produced incomplete Best Eleven: "
            f"slots={len(best)}/{len(expected_slots)} missing={missing}"
        )

    rows: List[Tuple] = []
    for index, slot_key in enumerate(expected_slots):
        row = best[slot_key]
        rows.append(
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
                int(row[7]),   # starts in this formation
                int(row[8]),   # total minutes in this formation
            )
        )

    return rows


def compute_best_eleven(team_id: int, season_id: int) -> bool:
    """
    season_id는 team_seasons의 Big 5 정규리그 대표 시즌 ID다.

    1) 대표 시즌과 시즌명이 같은 모든 대회의 포메이션 사용 횟수 계산
    2) 포메이션마다 해당 경기만 사용해 slot별 Best Eleven 계산
    3) 포메이션 요약과 모든 포메이션의 선수 결과를 원자적으로 교체

    유효 경기가 없으면 기존 파생 결과를 삭제하고 False를 반환한다.
    """
    count_rows = fetch_all(SQL_FORMATION_COUNTS, (season_id, team_id))
    formation_counts = [
        (str(formation), int(matches_used))
        for formation, matches_used in count_rows
    ]

    if not formation_counts:
        with transaction() as conn:
            with conn.cursor() as cur:
                cur.execute(SQL_DELETE_BEST_ELEVEN, (team_id, season_id))
                cur.execute(
                    SQL_DELETE_BEST_ELEVEN_FORMATIONS,
                    (team_id, season_id),
                )
        print(
            f"  [best11] team {team_id} canonical season {season_id}: "
            "no valid formations; cleared cached result"
        )
        return False

    total_valid_matches = sum(matches_used for _, matches_used in formation_counts)
    formation_rows = []
    player_rows: List[Tuple] = []

    for index, (formation, matches_used) in enumerate(formation_counts):
        formation_rows.append(
            (
                team_id,
                season_id,
                formation,
                matches_used,
                total_valid_matches,
                1 if index == 0 else 0,
            )
        )
        player_rows.extend(
            _build_formation_best_eleven_rows(team_id, season_id, formation)
        )

    # Derived-cache replacement must be atomic: readers see either the old
    # complete formation set or the new one, never a DELETE/INSERT gap.
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(SQL_DELETE_BEST_ELEVEN, (team_id, season_id))
            cur.execute(
                SQL_DELETE_BEST_ELEVEN_FORMATIONS,
                (team_id, season_id),
            )
            cur.executemany(SQL_INSERT_BEST_ELEVEN_FORMATION, formation_rows)
            cur.executemany(SQL_INSERT_BEST_ELEVEN, player_rows)

    default_formation, default_matches = formation_counts[0]
    formation_summary = ", ".join(
        f"{formation}={matches_used}/{total_valid_matches}"
        for formation, matches_used in formation_counts
    )
    print(
        f"  [best11] team {team_id} canonical season {season_id}: "
        f"default={default_formation} ({default_matches}x), "
        f"formations=[{formation_summary}], player_rows={len(player_rows)}"
    )
    return True


# ---------------------------------------------------------------------------
# 3. Best Eleven 동기화 (라인업 없는 현재 시즌 과거 경기 → 영향 팀 재계산)
# ---------------------------------------------------------------------------

def refresh_best_eleven() -> None:
    """
    Big 5 팀의 현재 정규리그 시즌명과 같은 모든 대회에서, 라인업이 아직
    완전하지 않은(양 팀 중 한 팀이라도 유효한 포메이션 또는 서로 다른 11명의
    선발/포메이션 슬롯이 없는) 과거 경기의 라인업을 적재한다. 그 뒤 영향받은
    Big 5 팀을 대표 정규리그 season_id로 매핑해 전 대회 Best Eleven을 재계산한다.

    현재 대표 시즌명 + 라인업 미완 집합을 그대로 처리하므로 초기 구축과 증분
    갱신을 겸한다. 컵/유럽대항전 season.is_current 값에는 의존하지 않는다.
    """
    rows = fetch_all(SQL_CURRENT_PAST_FIXTURES_INCOMPLETE_LINEUP)

    if not rows:
        print("[best11] no current-season fixtures awaiting lineups")
        return

    sm = SportmonksClient()
    affected: Set[Tuple[int, int]] = set()  # (team_id, canonical season_id)
    total = len(rows)

    for index, (fixture_id, season_id, home_id, away_id) in enumerate(rows, 1):
        try:
            fetch_and_store_lineups(int(fixture_id), int(season_id), sm)
        except (requests.RequestException, ValueError) as error:
            # Sportmonks network/HTTP failures, plus malformed Sportmonks
            # payloads (SportmonksClient raises ValueError on shape mismatch)
            # and bad int() conversions — skip this fixture and continue the
            # batch. Code-logic errors (KeyError, TypeError, AttributeError,
            # mysql errors) bubble up so they surface immediately instead of
            # silently dropping fixtures.
            print(f"  [best11] ERROR fixture {fixture_id}: {error}")
            continue

        # Map the source competition season to each participant's canonical
        # Big 5 domestic season. External opponents without team_seasons
        # membership are source data only and intentionally have no result.
        # Cardinality errors from this DB-only mapping intentionally bubble up.
        for team_id in (int(home_id), int(away_id)):
            canonical_season_id = find_canonical_season_id(
                team_id,
                int(season_id),
            )
            if canonical_season_id is not None:
                affected.add((team_id, canonical_season_id))

        if index % 50 == 0:
            print(f"[best11] lineups progress: {index}/{total}")

    print(f"[best11] lineups done: fixtures={total}, affected teams={len(affected)}")

    for team_id, season_id in sorted(affected):
        try:
            compute_best_eleven(team_id, season_id)

        except ValueError as error:
            # compute_best_eleven is DB-only; ValueError here means a malformed
            # formation string in fixture_formations (int(parts[0]) in
            # _parse_formation_to_expected_slots). Everything else (KeyError,
            # mysql errors) bubbles up.
            print(f"  [best11] ERROR compute team {team_id}: {error}")

    print("[best11] refresh done")


def rebuild_best_eleven(*, current_only: bool) -> None:
    """Recompute canonical all-competition results from stored valid lineups.

    This function performs no Sportmonks requests. A full rebuild also removes
    legacy rows keyed by cup/European season IDs before rebuilding every tracked
    Big 5 team-season.
    """
    if not current_only:
        with transaction() as conn:
            with conn.cursor() as cur:
                cur.execute(SQL_DELETE_NONCANONICAL_BEST_ELEVEN)
                removed_players = cur.rowcount
                cur.execute(SQL_DELETE_NONCANONICAL_BEST_ELEVEN_FORMATIONS)
                removed_formations = cur.rowcount
        print(
            "[best11] removed noncanonical rows: "
            f"players={removed_players}, formations={removed_formations}"
        )

    rows = fetch_all(
        SQL_BIG5_CANONICAL_TEAM_SEASONS,
        (1 if current_only else 0,),
    )
    total = len(rows)
    built = 0
    empty = 0

    for index, (team_id, season_id) in enumerate(rows, 1):
        if compute_best_eleven(int(team_id), int(season_id)):
            built += 1
        else:
            empty += 1

        if index % 50 == 0:
            print(f"[best11] rebuild progress: {index}/{total}")

    scope = "current" if current_only else "all"
    print(
        f"[best11] rebuild-{scope} done: "
        f"team-seasons={total}, built={built}, empty={empty}"
    )


# ---------------------------------------------------------------------------
# 4. 검증
# ---------------------------------------------------------------------------

def validate_best_eleven() -> None:
    """
    현재 Big 5 대표 정규리그 season_id로 저장된 통합 결과를 검증한다.

    0) 컵/유럽대항전 season_id로 남은 비대표 row
    1) 현재 팀-시즌 중 결과가 전혀 없는 대상
    2) 포메이션별 11개 slot / 11명 / GK 완전성
    3) 팀-시즌별 기본 포메이션과 사용 경기 합계
    4) 포메이션 요약이 없는 선수 결과
    5) starter인데 total_minutes = 0
    """
    noncanonical_player_rows = int(
        fetch_all(SQL_COUNT_NONCANONICAL_BEST_ELEVEN)[0][0]
    )
    noncanonical_formation_rows = int(
        fetch_all(SQL_COUNT_NONCANONICAL_BEST_ELEVEN_FORMATIONS)[0][0]
    )
    print(
        "[validate] 0) Noncanonical rows: "
        f"players={noncanonical_player_rows}, "
        f"formations={noncanonical_formation_rows}"
    )

    missing_team_seasons = fetch_all(
        f"""
        SELECT ts.team_id, ts.season_id
        FROM team_seasons ts
        JOIN seasons s ON s.season_id = ts.season_id
        LEFT JOIN team_best_eleven_formations tbef
          ON tbef.team_id = ts.team_id
         AND tbef.season_id = ts.season_id
        WHERE s.league_id IN ({BIG5_LEAGUE_IDS_SQL})
          AND s.is_current = 1
        GROUP BY ts.team_id, ts.season_id
        HAVING COUNT(tbef.id) = 0
        ORDER BY ts.team_id, ts.season_id
        """
    )

    print(
        "[validate] 1) Current team-seasons without a formation result: "
        f"{len(missing_team_seasons)}"
    )
    for team_id, season_id in missing_team_seasons[:10]:
        print(f"  team={team_id} season={season_id}")
    if len(missing_team_seasons) > 10:
        print(f"  ... and {len(missing_team_seasons) - 10} more")

    formation_groups = fetch_all(
        f"""
        SELECT
          tbef.team_id,
          tbef.season_id,
          tbef.formation,
          COUNT(tbe.id) AS player_rows,
          COUNT(DISTINCT tbe.player_id) AS distinct_players,
          SUM(CASE WHEN tbe.slot_key = '1:1' THEN 1 ELSE 0 END) AS gk_rows
        FROM team_best_eleven_formations tbef
        JOIN team_seasons ts
          ON ts.team_id = tbef.team_id
         AND ts.season_id = tbef.season_id
        JOIN seasons s ON s.season_id = ts.season_id
        LEFT JOIN team_best_eleven tbe
          ON tbe.team_id = tbef.team_id
         AND tbe.season_id = tbef.season_id
         AND tbe.formation = tbef.formation
        WHERE s.league_id IN ({BIG5_LEAGUE_IDS_SQL})
          AND s.is_current = 1
        GROUP BY tbef.team_id, tbef.season_id, tbef.formation
        ORDER BY tbef.team_id, tbef.season_id, tbef.formation
        """
    )

    incomplete = []
    no_gk = []

    for (
        team_id,
        season_id,
        formation,
        player_rows,
        distinct_players,
        gk_rows,
    ) in formation_groups:
        expected_rows = len(_parse_formation_to_expected_slots(str(formation)))
        actual_rows = int(player_rows)
        actual_players = int(distinct_players)

        if actual_rows != expected_rows or actual_players != expected_rows:
            incomplete.append(
                (
                    team_id,
                    season_id,
                    formation,
                    actual_rows,
                    actual_players,
                    expected_rows,
                )
            )
        if int(gk_rows or 0) != 1:
            no_gk.append((team_id, season_id, formation, int(gk_rows or 0)))

    print(
        "\n[validate] 2) Incomplete formation results: "
        f"{len(incomplete)} / {len(formation_groups)}"
    )
    for row in incomplete[:10]:
        print(
            f"  team={row[0]} season={row[1]} formation={row[2]}: "
            f"rows={row[3]}/{row[5]} players={row[4]}/{row[5]}"
        )

    if len(incomplete) > 10:
        print(f"  ... and {len(incomplete) - 10} more")

    print(f"[validate] 2a) Formation results without exactly one GK: {len(no_gk)}")
    for team_id, season_id, formation, gk_rows in no_gk[:10]:
        print(
            f"  team={team_id} season={season_id} "
            f"formation={formation}: gk_rows={gk_rows}"
        )
    if len(no_gk) > 10:
        print(f"  ... and {len(no_gk) - 10} more")

    invalid_usage = fetch_all(
        f"""
        SELECT
          tbef.team_id,
          tbef.season_id,
          COUNT(*) AS formation_count,
          SUM(tbef.is_default) AS default_count,
          SUM(tbef.matches_used) AS summed_matches,
          MIN(tbef.total_valid_matches) AS min_total_matches,
          MAX(tbef.total_valid_matches) AS max_total_matches
        FROM team_best_eleven_formations tbef
        JOIN team_seasons ts
          ON ts.team_id = tbef.team_id
         AND ts.season_id = tbef.season_id
        JOIN seasons s ON s.season_id = ts.season_id
        WHERE s.league_id IN ({BIG5_LEAGUE_IDS_SQL})
          AND s.is_current = 1
        GROUP BY tbef.team_id, tbef.season_id
        HAVING SUM(tbef.is_default) <> 1
            OR MIN(tbef.total_valid_matches) <> MAX(tbef.total_valid_matches)
            OR SUM(tbef.matches_used) <> MAX(tbef.total_valid_matches)
        ORDER BY tbef.team_id, tbef.season_id
        """
    )

    print(
        "\n[validate] 3) Invalid default/usage summaries: "
        f"{len(invalid_usage)}"
    )
    for row in invalid_usage[:10]:
        print(
            f"  team={row[0]} season={row[1]} formations={row[2]} "
            f"defaults={row[3]} summed={row[4]} "
            f"total_range={row[5]}..{row[6]}"
        )
    if len(invalid_usage) > 10:
        print(f"  ... and {len(invalid_usage) - 10} more")

    orphan_players = fetch_all(
        f"""
        SELECT
          tbe.team_id,
          tbe.season_id,
          tbe.formation,
          COUNT(*) AS player_rows
        FROM team_best_eleven tbe
        JOIN team_seasons ts
          ON ts.team_id = tbe.team_id
         AND ts.season_id = tbe.season_id
        JOIN seasons s ON s.season_id = ts.season_id
        LEFT JOIN team_best_eleven_formations tbef
          ON tbef.team_id = tbe.team_id
         AND tbef.season_id = tbe.season_id
         AND tbef.formation = tbe.formation
        WHERE s.league_id IN ({BIG5_LEAGUE_IDS_SQL})
          AND s.is_current = 1
          AND tbef.id IS NULL
        GROUP BY tbe.team_id, tbe.season_id, tbe.formation
        ORDER BY tbe.team_id, tbe.season_id, tbe.formation
        """
    )

    print(
        "\n[validate] 4) Player formation results without a summary: "
        f"{len(orphan_players)}"
    )
    for team_id, season_id, formation, player_rows in orphan_players[:10]:
        print(
            f"  team={team_id} season={season_id} "
            f"formation={formation}: rows={player_rows}"
        )
    if len(orphan_players) > 10:
        print(f"  ... and {len(orphan_players) - 10} more")

    zero_min = fetch_all(
        f"""
        SELECT
          tbe.team_id,
          tbe.season_id,
          tbe.formation,
          tbe.slot_key,
          tbe.player_name,
          tbe.starts
        FROM team_best_eleven tbe
        JOIN team_seasons ts
          ON ts.team_id = tbe.team_id
         AND ts.season_id = tbe.season_id
        JOIN seasons s ON s.season_id = ts.season_id
        WHERE s.league_id IN ({BIG5_LEAGUE_IDS_SQL})
          AND s.is_current = 1
          AND tbe.total_minutes = 0
        ORDER BY tbe.starts DESC, tbe.team_id, tbe.formation, tbe.slot_index
        """
    )

    print(f"\n[validate] 5) Rows with total_minutes=0: {len(zero_min)}")
    for row in zero_min[:10]:
        print(
            f"  team={row[0]} season={row[1]} "
            f"formation={row[2]} slot={row[3]} "
            f"player={row[4]} starts={row[5]}"
        )
    if len(zero_min) > 10:
        print(f"  ... and {len(zero_min) - 10} more")

    current_team_seasons = {
        (int(row[0]), int(row[1])) for row in formation_groups
    }
    current_team_seasons.update(
        (int(row[0]), int(row[1])) for row in missing_team_seasons
    )
    passed = (
        noncanonical_player_rows == 0
        and noncanonical_formation_rows == 0
        and not missing_team_seasons
        and not incomplete
        and not no_gk
        and not invalid_usage
        and not orphan_players
        and not zero_min
    )
    print(
        "\n[validate] Summary: "
        f"status={'PASS' if passed else 'FAIL'}, "
        f"current team-seasons={len(current_team_seasons)}, "
        f"formation results={len(formation_groups)}"
    )
