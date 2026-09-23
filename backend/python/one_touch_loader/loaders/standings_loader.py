from __future__ import annotations

from typing import Dict, List, Sequence, Tuple

from ..core.db import fetch_all, transaction
from ..core.sportmonks import SportmonksClient


BIG5_COMPETITION_IDS = (8, 82, 301, 384, 564)
MIN_SEASON_START_YEAR = 2017

SQL_SELECT_ALL_TARGETS = """
SELECT season_id, competition_id, name
FROM seasons
WHERE competition_id IN (8,82,301,384,564)
  AND CAST(LEFT(name, 4) AS UNSIGNED) >= %s
ORDER BY name, competition_id
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
    if season_name is None:
        rows = fetch_all(SQL_SELECT_ALL_TARGETS, (MIN_SEASON_START_YEAR,))
    else:
        placeholders = ",".join("%s" for _ in competition_ids)
        rows = fetch_all(
            f"""
            SELECT season_id, competition_id, name
            FROM seasons
            WHERE name = %s
              AND competition_id IN ({placeholders})
              AND competition_id IN (8,82,301,384,564)
            ORDER BY competition_id
            """,
            (season_name, *competition_ids),
        )

    return [(int(row[0]), int(row[1]), str(row[2])) for row in rows]


def _previous_positions(
    sm: SportmonksClient,
    season_id: int,
) -> Dict[int, int]:
    finished_rounds = [
        row for row in sm.get_rounds_for_season(season_id) if row["finished"]
    ]
    finished_rounds.sort(key=lambda row: int(row["name"]))

    # 현재 분데스리가처럼 완료 라운드가 하나뿐이면 비교할 직전 순위가 없어요.
    if len(finished_rounds) < 2:
        return {}

    previous_round_id = finished_rounds[-2]["id"]
    return {
        row["participant_id"]: row["position"]
        for row in sm.get_standings_for_round(previous_round_id)
    }


def _standing_rows(
    sm: SportmonksClient,
    season_id: int,
    *, standings=None, previous_positions=None,
) -> List[Tuple]:
    if previous_positions is None:
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
    expected = {r[0] for r in fetch_all('SELECT team_id FROM team_seasons WHERE season_id=%s', (season_id,))}
    if {r['participant_id'] for r in source} != expected or len(source) != len(expected):
        raise ValueError('Standings must cover every season participant exactly once')
    previous = dict(fetch_all('SELECT team_id,previous_position FROM standings WHERE season_id=%s',
                              (season_id,))) if live else None
    rows = _standing_rows(client, season_id, standings=source, previous_positions=previous)
    if apply:
        _replace_season(season_id, rows, live=live, clear_live=clear_live)
    return {'season_id': season_id, 'live': live, 'rows': len(rows)}


def collect_standings(
    season_name: str | None = None,
    competition_ids: Sequence[int] | None = None,
) -> Dict[str, int]:
    targets = _targets(season_name, competition_ids)
    if not targets:
        raise ValueError("No matching Big 5 league seasons found")

    sm = SportmonksClient()
    stored_rows = 0

    for season_id, competition_id, resolved_name in targets:
        rows = _standing_rows(sm, season_id)
        _replace_season(season_id, rows)
        stored_rows += len(rows)
        print(
            f"[standings] season={resolved_name} "
            f"competition={competition_id} rows={len(rows)}"
        )

    return {"processed_seasons": len(targets), "stored_rows": stored_rows}


def collect_all_standings() -> Dict[str, int]:
    return collect_standings()


def collect_standings_for_name(
    season_name: str,
    competition_ids: Sequence[int],
) -> Dict[str, int]:
    return collect_standings(season_name, competition_ids)
