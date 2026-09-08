"""저장된 경기 라인업으로 시즌·포메이션별 대표 선발 11명을 계산해요.

라인업 적재는 fixture-details가 담당해요. 계산 명령은 공급자를 호출하지 않고,
선택한 시즌의 Big 5 팀이 같은 시즌명의 모든 대회에서 남긴 유효 선발 기록을 사용해요.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from contextlib import closing

from ..core.best_eleven import formation_slots, order_formations, select_players
from ..core.db import get_conn, transaction
from ..core.fixture_states import COMPLETED_STATE_IDS


BIG5_COMPETITION_IDS = (8, 82, 301, 384, 564)
SQL_SCOPE = f"""
SELECT ts.team_id, ts.season_id
FROM team_seasons ts
JOIN seasons s ON s.season_id = ts.season_id
WHERE s.competition_id IN ({','.join(map(str, BIG5_COMPETITION_IDS))})
  AND (%s IS NULL OR s.name = %s)
ORDER BY s.name, ts.team_id
"""

# 컵·유럽대항전은 리그와 시즌 ID가 달라요. 같은 시즌명으로 입력을 합치되,
# 결과는 그 팀의 Big 5 정규리그 시즌 ID에 저장해요. 선발과 포메이션을 한 번에
# 읽어 사용 경기 수와 선수 횟수가 서로 다른 자료를 집계하지 않게 해요.
SQL_SOURCE_LINEUPS = f"""
SELECT f.fixture_id, ff.formation, fl.player_id, fl.formation_field
FROM seasons canonical_season
JOIN seasons source_season ON source_season.name = canonical_season.name
JOIN stages st ON st.season_id = source_season.season_id
JOIN fixtures f ON f.stage_id = st.stage_id
LEFT JOIN fixture_formations ff ON ff.fixture_id = f.fixture_id AND ff.team_id = %s
LEFT JOIN fixture_lineups fl
  ON fl.fixture_id = f.fixture_id AND fl.team_id = %s AND fl.lineup_type_id = 11
WHERE canonical_season.season_id = %s
  AND %s IN (f.home_team_id, f.away_team_id)
  AND f.state_id IN ({','.join(map(str, COMPLETED_STATE_IDS))})
ORDER BY f.fixture_id, fl.player_id
"""

SQL_DELETE_PLAYERS = "DELETE FROM team_best_eleven WHERE team_id = %s AND season_id = %s"
SQL_DELETE_FORMATIONS = "DELETE FROM team_best_eleven_formations WHERE team_id = %s AND season_id = %s"
SQL_INSERT_FORMATIONS = """
INSERT INTO team_best_eleven_formations (team_id, season_id, formation, matches_used)
VALUES (%s, %s, %s, %s)
"""
SQL_INSERT_PLAYERS = """
INSERT INTO team_best_eleven (team_id, season_id, formation, slot_key, player_id, starts)
VALUES (%s, %s, %s, %s, %s, %s)
"""
SQL_STORED_FORMATIONS = """
SELECT team_id, season_id, formation, matches_used
FROM team_best_eleven_formations WHERE team_id = %s AND season_id = %s
"""
SQL_STORED_PLAYERS = """
SELECT team_id, season_id, formation, slot_key, player_id, starts
FROM team_best_eleven WHERE team_id = %s AND season_id = %s
"""


def build_best_eleven_rows(team_id: int, season_id: int, source_rows: list[tuple]) -> dict:
    """같은 유효 경기로 포메이션 사용 횟수와 자리별 선발 횟수를 함께 계산해요."""
    fixtures = defaultdict(list)
    for fixture_id, formation, player_id, slot in source_rows:
        fixtures[fixture_id].append((formation, player_id, slot))

    counts = Counter()
    appearances = defaultdict(Counter)
    excluded = []
    for fixture_id, lineup in sorted(fixtures.items()):
        formation = lineup[0][0]
        starters = [(player_id, slot) for _, player_id, slot in lineup if player_id is not None]
        reason = None
        if not formation:
            reason = "missing_formation"
        elif len(starters) != 11:
            reason = "incomplete_starters"
        elif any(not slot for _, slot in starters):
            reason = "missing_slots"
        elif {slot for _, slot in starters} != set(formation_slots(formation)):
            # 경기 16481727처럼 원본 포메이션과 선수 자리가 다른 자료는 추측으로
            # 고치지 않아요. 해당 팀의 경기만 사용 횟수와 선수 집계 모두에서 빼요.
            reason = "formation_slots_mismatch"
        if reason:
            excluded.append((fixture_id, reason))
            continue

        counts[formation] += 1
        for player_id, slot in starters:
            appearances[formation][slot, player_id] += 1

    formations = []
    players = []
    for formation in order_formations(counts):
        formations.append((team_id, season_id, formation, counts[formation]))
        players.extend(
            (team_id, season_id, formation, slot, player_id, starts)
            for slot, player_id, starts in select_players(formation_slots(formation), appearances[formation])
        )
    return {"formations": formations, "players": players, "excluded": excluded}


def _load_scope(cursor, season_name: str | None) -> list[tuple[int, int]]:
    cursor.execute(SQL_SCOPE, (season_name, season_name))
    scope = cursor.fetchall()
    if not scope:
        raise ValueError(f"No Big 5 team-seasons found: season={season_name!r}")
    return scope


def _calculate_team(cursor, team_id: int, season_id: int) -> dict:
    cursor.execute(SQL_SOURCE_LINEUPS, (team_id, team_id, season_id, team_id))
    return build_best_eleven_rows(team_id, season_id, cursor.fetchall())


def replace_best_eleven(team_id: int, season_id: int, result: dict) -> None:
    # 두 화면이 쓰는 모든 포메이션을 팀·시즌별 한 트랜잭션으로 교체해요.
    # 유효 경기가 없어진 경우에도 기존 결과를 지워 오래된 11명이 남지 않게 해요.
    with transaction() as conn:
        with conn.cursor() as cursor:
            cursor.execute(SQL_DELETE_PLAYERS, (team_id, season_id))
            cursor.execute(SQL_DELETE_FORMATIONS, (team_id, season_id))
            if result["formations"]:
                cursor.executemany(SQL_INSERT_FORMATIONS, result["formations"])
                cursor.executemany(SQL_INSERT_PLAYERS, result["players"])


def rebuild_best_eleven(season_name: str | None = None) -> dict:
    """시즌 이름을 지정하면 그 시즌의 5개 리그 팀을, 생략하면 전체 시즌을 계산해요."""
    totals = dict.fromkeys(("team_seasons", "built", "unavailable", "formations", "players", "excluded"), 0)
    with closing(get_conn()) as source:
        source.start_transaction(readonly=True, consistent_snapshot=True)
        with source.cursor() as cursor:
            scope = _load_scope(cursor, season_name)
            for index, (team_id, season_id) in enumerate(scope, start=1):
                result = _calculate_team(cursor, team_id, season_id)
                replace_best_eleven(team_id, season_id, result)
                for fixture_id, reason in result["excluded"]:
                    print(f"[best-eleven excluded] team_id={team_id} season_id={season_id} "
                          f"fixture_id={fixture_id} reason={reason}", flush=True)
                totals["team_seasons"] += 1
                totals["built" if result["formations"] else "unavailable"] += 1
                for key in ("formations", "players", "excluded"):
                    totals[key] += len(result[key])
                print(f"[best-eleven {index}/{len(scope)}] team_id={team_id} season_id={season_id} "
                      f"formations={len(result['formations'])} players={len(result['players'])} "
                      f"excluded={len(result['excluded'])}", flush=True)
    return totals


def validate_best_eleven(season_name: str | None = None) -> dict:
    """같은 DB 시점의 원본으로 다시 계산해 지정 시즌의 저장 결과 전체를 대조해요."""
    totals = dict.fromkeys(("team_seasons", "built", "unavailable", "failed"), 0)
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        with conn.cursor() as cursor:
            scope = _load_scope(cursor, season_name)
            for team_id, season_id in scope:
                expected = _calculate_team(cursor, team_id, season_id)
                cursor.execute(SQL_STORED_FORMATIONS, (team_id, season_id))
                formations = cursor.fetchall()
                cursor.execute(SQL_STORED_PLAYERS, (team_id, season_id))
                players = cursor.fetchall()
                passed = (
                    sorted(formations) == sorted(expected["formations"])
                    and sorted(players) == sorted(expected["players"])
                )
                totals["team_seasons"] += 1
                totals["built" if expected["formations"] else "unavailable"] += 1
                if not passed:
                    totals["failed"] += 1
                    print(f"[best-eleven validate] team_id={team_id} season_id={season_id} "
                          f"status=FAIL formations={len(formations)}/{len(expected['formations'])} "
                          f"players={len(players)}/{len(expected['players'])}", flush=True)
    # 유효 입력과 결과가 함께 없는 팀은 정상적인 미산출이에요. 계산 가능한 결과가
    # 빠졌거나 선수·자리·횟수가 다를 때만 실패하고 CLI가 실패 종료 코드를 반환해요.
    result = {**totals, "status": "FAIL" if totals["failed"] else "PASS"}
    print(f"[best-eleven validate] season={season_name or 'all'} {result}", flush=True)
    return result
