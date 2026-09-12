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
    if len(finished_rounds) == 1:
        return {}

    previous_round_id = finished_rounds[-2]["id"]
    return {
        row["participant_id"]: row["position"]
        for row in sm.get_standings_for_round(previous_round_id)
    }


def _standing_rows(
    sm: SportmonksClient,
    season_id: int,
) -> List[Tuple]:
    previous_positions = _previous_positions(sm, season_id)
    rows: List[Tuple] = []

    for standing in sm.get_standings_for_season(season_id):
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


def _replace_season(season_id: int, rows: List[Tuple]) -> None:
    with transaction() as connection:
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM standings WHERE season_id = %s", (season_id,))
            cursor.executemany(SQL_INSERT_STANDING, rows)


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
