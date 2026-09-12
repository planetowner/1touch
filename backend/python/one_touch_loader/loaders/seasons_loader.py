"""지원 대회의 2017/2018 이후 시즌을 저장해요."""

from __future__ import annotations

from typing import Dict, List, Tuple

from ..core.db import fetch_all, upsert_many
from ..core.sportmonks import SportmonksClient
from .teams_loader import MIN_SEASON_START_YEAR, SUPPORTED_COMPETITION_IDS


SQL_SELECT_COMPETITION_IDS = """
SELECT competition_id
FROM competitions
WHERE competition_id IN (2, 5, 8, 24, 27, 82, 301, 384, 390, 564, 570, 2286)
ORDER BY competition_id
"""

SQL_UPSERT_SEASON = """
INSERT INTO seasons (season_id, competition_id, name, is_current)
VALUES (%s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  competition_id = VALUES(competition_id),
  name = VALUES(name),
  is_current = VALUES(is_current)
"""

SeasonRow = Tuple[int, int, str, bool]


def _season_start_year(season_name: str) -> int:
    parts = season_name.split("/", 1)
    if len(parts) != 2:
        raise ValueError(f"Unsupported season name: {season_name!r}")
    try:
        start_year = int(parts[0])
        end_year = int(parts[1])
    except ValueError as exc:
        raise ValueError(f"Unsupported season name: {season_name!r}") from exc
    if end_year != start_year + 1:
        raise ValueError(f"Unsupported season name: {season_name!r}")
    return start_year


def _season_rows(competition_id: int, seasons: object) -> List[SeasonRow]:
    if not isinstance(seasons, list):
        raise ValueError(
            f"Expected seasons list for competition_id={competition_id}"
        )

    rows: List[SeasonRow] = []
    for index, season in enumerate(seasons):
        if not isinstance(season, dict):
            raise ValueError(
                f"Expected season object: competition_id={competition_id}, "
                f"index={index}"
            )
        season_id = season.get("id")
        name = season.get("name")
        is_current = season.get("is_current")
        if type(season_id) is not int:
            raise ValueError(
                f"Invalid season id: competition_id={competition_id}, "
                f"index={index}, id={season_id!r}"
            )
        if not isinstance(name, str) or not name.strip():
            raise ValueError(
                f"Invalid season name: competition_id={competition_id}, "
                f"season_id={season_id}"
            )
        name = name.strip()
        if type(is_current) is not bool:
            raise ValueError(
                f"Invalid is_current: competition_id={competition_id}, "
                f"season_id={season_id}, value={is_current!r}"
            )
        if _season_start_year(name) >= MIN_SEASON_START_YEAR:
            rows.append((season_id, competition_id, name, is_current))
    return rows


def collect_all_seasons() -> Dict[str, object]:
    """DB가 지원하는 모든 대회의 2017/2018 이후 시즌을 저장해요."""
    competition_ids = [
        int(row[0]) for row in fetch_all(SQL_SELECT_COMPETITION_IDS)
    ]
    expected_ids = set(SUPPORTED_COMPETITION_IDS)
    if set(competition_ids) != expected_ids:
        raise ValueError(
            "competitions does not contain the supported competition set: "
            f"expected={sorted(expected_ids)}, actual={competition_ids}"
        )

    sm = SportmonksClient()
    all_rows: List[SeasonRow] = []
    results: List[Dict[str, int]] = []
    for index, competition_id in enumerate(competition_ids, start=1):
        competition = sm.get_league_with_seasons(competition_id)
        rows = _season_rows(competition_id, competition.get("seasons"))
        all_rows.extend(rows)
        results.append({"competition_id": competition_id, "season_count": len(rows)})
        print(
            f"[seasons {index}/{len(competition_ids)}] "
            f"competition_id={competition_id} seasons={len(rows)}"
        )

    if not all_rows:
        raise ValueError("Sportmonks returned no supported seasons")
    upsert_many(SQL_UPSERT_SEASON, all_rows)
    print(f"[seasons] completed rows={len(all_rows)}")
    return {
        "minimum_season_start_year": MIN_SEASON_START_YEAR,
        "competition_count": len(competition_ids),
        "season_count": len(all_rows),
        "results": results,
    }
