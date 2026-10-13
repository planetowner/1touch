from __future__ import annotations

from typing import Dict, List, Sequence, Tuple

from ..core.db import fetch_all, transaction
from ..core.cup_betting import EUROPE_COMPETITION_IDS
from ..core.fixture_states import COMPLETED_STATE_IDS, LIVE_STATE_IDS
from ..core.sportmonks import SportmonksClient


BIG5_COMPETITION_IDS = (8, 82, 301, 384, 564)
SUPPORTED_COMPETITION_IDS = (*BIG5_COMPETITION_IDS, *EUROPE_COMPETITION_IDS)
MIN_SEASON_START_YEAR = 2017

SQL_SELECT_ALL_TARGETS = f"""
SELECT season_id, competition_id, name
FROM seasons
WHERE ((competition_id IN ({','.join(map(str, BIG5_COMPETITION_IDS))})
        AND CAST(LEFT(name, 4) AS UNSIGNED) >= %s)
    OR (competition_id IN ({','.join(map(str, EUROPE_COMPETITION_IDS))})
        AND CAST(LEFT(name, 4) AS UNSIGNED) >= 2024))
"""

SQL_INSERT_STANDING = """
INSERT INTO standings (
  season_id,
  team_id,
  position,
  previous_position,
  won,
  draw,
  lost,
  goals_for,
  goals_against,
  points
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
"""


def _targets(
    season_name: str | None = None,
    competition_ids: Sequence[int] | None = None,
) -> List[Tuple[int, int, str]]:
    # 유럽대항전은 2024/25부터 단일 리그 페이즈 순위를 제공해요.
    sql = SQL_SELECT_ALL_TARGETS
    params = (MIN_SEASON_START_YEAR,)
    if season_name is not None:
        placeholders = ",".join("%s" for _ in competition_ids)
        sql += f" AND name = %s AND competition_id IN ({placeholders})"
        params += (season_name, *competition_ids)
    rows = fetch_all(sql + " ORDER BY name, competition_id", params)

    return [(int(row[0]), int(row[1]), str(row[2])) for row in rows]


def _previous_positions(
    sm: SportmonksClient,
    season_id: int,
) -> Dict[int, int]:
    states = (*COMPLETED_STATE_IDS, *LIVE_STATE_IDS)
    placeholders = ",".join("%s" for _ in states)
    # 공급자의 라운드 완료 표시는 늦을 수 있어요. 실제 진행·종료된 최신 라운드의 직전 순위를 써요.
    previous_rounds = fetch_all(
        f"""
        SELECT previous_round.round_id
        FROM rounds previous_round
        JOIN (
            SELECT r.stage_id, CAST(r.name AS UNSIGNED) AS round_number
            FROM fixtures f
            JOIN rounds r ON r.round_id = f.round_id
            JOIN stages st ON st.stage_id = f.stage_id
            WHERE st.season_id = %s AND st.stage_type_id = 223
              AND f.state_id IN ({placeholders})
              AND r.name REGEXP '^[0-9]+$'
            ORDER BY round_number DESC
            LIMIT 1
        ) current_round ON current_round.stage_id = previous_round.stage_id
        WHERE CAST(previous_round.name AS UNSIGNED) = current_round.round_number - 1
        """,
        (season_id, *states),
    )
    if not previous_rounds:
        return {}

    previous_round_id = previous_rounds[0][0]
    return {
        row["participant_id"]: row["position"]
        for row in sm.get_standings_for_round(previous_round_id)
    }


def _standing_rows(
    sm: SportmonksClient,
    season_id: int,
    *, standings=None,
) -> List[Tuple]:
    previous_positions = _previous_positions(sm, season_id)
    rows: List[Tuple] = []

    for standing in sm.get_standings_for_season(season_id) if standings is None else standings:
        details = {
            detail["type"]["code"]: detail["value"]
            for detail in standing["details"]
        }
        team_id = standing["participant_id"]
        rows.append(
            (
                season_id,
                team_id,
                standing["position"],
                previous_positions[team_id] if previous_positions else None,
                details["overall-won"],
                details["overall-draw"],
                details["overall-lost"],
                details["overall-goals-for"],
                details["overall-goals-against"],
                standing["points"],
            )
        )

    return rows


def _replace_season(season_id: int, rows: List[Tuple], *, live: bool = False, clear_live: bool = False) -> None:
    # 경기 중 임시 승점을 공식 순위와 분리해 팀 특성 학습·집계에 섞이지 않게 해요.
    table = 'live_standings' if live else 'standings'
    with transaction() as connection:
        with connection.cursor() as cursor:
            if clear_live:
                # 종료 후 임시 표를 지워 다음 경기 시작 때 이전 경기의 라이브 순위를 보여주지 않아요.
                cursor.execute('DELETE FROM live_standings WHERE season_id=%s', (season_id,))
            cursor.execute(f"DELETE FROM {table} WHERE season_id = %s", (season_id,))
            if rows:
                cursor.executemany(SQL_INSERT_STANDING.replace('INSERT INTO standings', f'INSERT INTO {table}'), rows)


def refresh_current_table(season_id: int, competition_id: int, *, live: bool, apply: bool,
                          clear_live: bool = False) -> dict:
    client = SportmonksClient()
    source = client.get_live_standings(competition_id) if live else client.get_standings_for_season(season_id)
    if not source:
        raise ValueError(f'Standings are not available: {competition_id} {season_id}')
    if any(row['season_id'] != season_id for row in source):
        raise ValueError('Standings source season differs from the requested season')
    # 유럽대항전의 시즌 참가팀에는 예선 탈락팀도 있어 리그 페이즈 경기로 범위를 정해요.
    membership_sql = ("""SELECT f.home_team_id,f.away_team_id FROM fixtures f
        JOIN stages st ON st.stage_id=f.stage_id
        WHERE st.season_id=%s AND st.stage_type_id=223"""
        if competition_id in EUROPE_COMPETITION_IDS else
        'SELECT team_id FROM team_seasons WHERE season_id=%s')
    expected = {team for row in fetch_all(membership_sql, (season_id,)) for team in row}
    if {r['participant_id'] for r in source} != expected or len(source) != len(expected):
        raise ValueError('Standings must cover every season participant exactly once')
    # 새 라운드의 첫 경기부터 공식·라이브 표에 같은 비교 기준을 적용해요.
    rows = _standing_rows(client, season_id, standings=source)
    if apply:
        _replace_season(season_id, rows, live=live, clear_live=clear_live)
    return {'season_id': season_id, 'live': live, 'rows': len(rows)}


def collect_standings(
    season_name: str | None = None,
    competition_ids: Sequence[int] | None = None,
) -> Dict[str, int]:
    targets = _targets(season_name, competition_ids)
    if not targets:
        raise ValueError("No matching standings seasons found")

    stored_rows = 0

    for season_id, competition_id, resolved_name in targets:
        result = refresh_current_table(season_id, competition_id, live=False, apply=True)
        stored_rows += result['rows']
        print(
            f"[standings] season={resolved_name} "
            f"competition={competition_id} rows={result['rows']}"
        )

    return {"processed_seasons": len(targets), "stored_rows": stored_rows}


def collect_all_standings() -> Dict[str, int]:
    return collect_standings()


def collect_standings_for_name(
    season_name: str,
    competition_ids: Sequence[int],
) -> Dict[str, int]:
    return collect_standings(season_name, competition_ids)
