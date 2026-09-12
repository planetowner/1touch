from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from selenium.common.exceptions import TimeoutException

from ..core.db import fetch_all, transaction
from .capology_common import (
    CAPOLOGY_DIAGNOSTICS_DIRECTORY,
    _CapologyBrowserSession,
    _canonical_capology_player_id,
    _capology_salary_url,
    _parse_capology_salary_page,
)
from .capology_team_slugs_loader import _load_target_team_seasons


SQL_SELECT_CAPOLOGY_TEAM_SLUGS = """
SELECT team_id, external_team_id
FROM team_external_ids
WHERE provider = 'capology'
ORDER BY team_id
"""

SQL_SELECT_CAPOLOGY_PLAYER_IDS = """
SELECT external_player_id, player_id
FROM player_external_ids
WHERE provider = 'capology'
ORDER BY external_player_id
"""

SQL_DELETE_TEAM_SEASON_WAGES = """
DELETE FROM player_wages
WHERE team_id = %s
  AND season_id = %s
"""

SQL_INSERT_WAGE = """
INSERT INTO player_wages (
  team_id,
  season_id,
  player_id,
  estimated_weekly_gross_eur
) VALUES (%s,%s,%s,%s)
"""


def _write_wage_report(payload: Dict[str, object]) -> Path:
    CAPOLOGY_DIAGNOSTICS_DIRECTORY.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = CAPOLOGY_DIAGNOSTICS_DIRECTORY / f"capology_wages_{stamp}.json"
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return path


def _build_wage_rows(
    target: Dict[str, object],
    source_players: List[Dict[str, object]],
    player_ids_by_capology_slug: Dict[str, int],
) -> Tuple[List[Tuple[int, int, int, int]], List[Dict], List[Dict]]:
    wage_rows: List[Tuple[int, int, int, int]] = []
    ignored_without_loaded_db_match: List[Dict] = []
    unavailable_wages: List[Dict] = []
    for source_player in source_players:
        source_slug = str(source_player["external_player_id"])
        canonical_slug = _canonical_capology_player_id(source_slug)
        player_id = player_ids_by_capology_slug.get(canonical_slug)
        source_summary = {
            "team_id": int(target["team_id"]),
            "season_id": int(target["season_id"]),
            "capology_player_id": source_slug,
            "capology_player_name": str(source_player["name"]),
        }
        if player_id is None:
            ignored_without_loaded_db_match.append(source_summary)
            continue

        estimated_weekly_gross_eur = source_player[
            "estimated_weekly_gross_eur"
        ]
        if estimated_weekly_gross_eur is None:
            unavailable_wages.append(
                {
                    **source_summary,
                    "player_id": player_id,
                }
            )
            continue

        wage_rows.append(
            (
                int(target["team_id"]),
                int(target["season_id"]),
                player_id,
                int(estimated_weekly_gross_eur),
            )
        )
    return wage_rows, ignored_without_loaded_db_match, unavailable_wages


def _collect_wages(
    season_name: Optional[str] = None,
    competition_id: Optional[int] = None,
) -> Dict[str, object]:
    targets = _load_target_team_seasons(season_name, competition_id)
    team_slugs_by_id = {
        int(team_id): str(external_team_id)
        for team_id, external_team_id in fetch_all(
            SQL_SELECT_CAPOLOGY_TEAM_SLUGS
        )
    }
    player_ids_by_capology_slug = {
        str(external_player_id): int(player_id)
        for external_player_id, player_id in fetch_all(
            SQL_SELECT_CAPOLOGY_PLAYER_IDS
        )
    }

    wage_rows: List[Tuple[int, int, int, int]] = []
    ignored_without_loaded_db_match: List[Dict] = []
    unavailable_wages: List[Dict] = []
    source_failures: List[Dict] = []
    source_player_count = 0

    session = _CapologyBrowserSession()
    try:
        for team_index, target in enumerate(targets, start=1):
            team_id = int(target["team_id"])
            target_season_name = str(target["season_name"])
            target_competition_id = int(target["competition_id"])
            team_slug = team_slugs_by_id.get(team_id)
            if team_slug is None:
                source_failures.append(
                    {
                        "team_id": team_id,
                        "team_name": str(target["team_name"]),
                        "source_url": None,
                        "error_type": "MissingCapologyTeamSlug",
                        "error": "team_external_ids has no Capology slug",
                    }
                )
                print(
                    f"[wages team {team_index}/{len(targets)}] "
                    f"season={target_season_name} "
                    f"competition={target_competition_id} "
                    f"team_id={team_id}: ERROR MissingCapologyTeamSlug"
                )
                continue

            source_url = _capology_salary_url(
                team_slug,
                target_season_name,
                bool(target["is_current"]),
            )
            try:
                html, response_url = session.fetch(source_url)
                source_players = _parse_capology_salary_page(
                    html,
                    target_season_name,
                )
                source_player_count += len(source_players)
                rows, ignored, unavailable = _build_wage_rows(
                    target,
                    source_players,
                    player_ids_by_capology_slug,
                )
                wage_rows.extend(rows)
                ignored_without_loaded_db_match.extend(
                    {**item, "source_url": response_url} for item in ignored
                )
                unavailable_wages.extend(
                    {**item, "source_url": response_url}
                    for item in unavailable
                )
                print(
                    f"[wages team {team_index}/{len(targets)}] "
                    f"season={target_season_name} "
                    f"competition={target_competition_id} "
                    f"team={team_slug} wages={len(rows)} "
                    f"ignored={len(ignored)} unavailable={len(unavailable)}"
                )
            except (ValueError, TimeoutException) as exc:
                source_failures.append(
                    {
                        "team_id": team_id,
                        "team_name": str(target["team_name"]),
                        "team_slug": team_slug,
                        "source_url": source_url,
                        "error_type": type(exc).__name__,
                        "error": str(exc),
                    }
                )
                console_error = str(exc).encode(
                    "ascii",
                    errors="backslashreplace",
                ).decode("ascii")
                print(
                    f"[wages team {team_index}/{len(targets)}] "
                    f"season={target_season_name} "
                    f"competition={target_competition_id} "
                    f"team={team_slug}: ERROR {type(exc).__name__}: "
                    f"{console_error}"
                )
    finally:
        session.close()

    summary: Dict[str, object] = {
        "season_name": season_name or "all",
        "competition_id": competition_id,
        "target_team_seasons": len(targets),
        "source_players": source_player_count,
        "mapped_wages": len(wage_rows),
        "ignored_source_players_without_loaded_db_match": len(
            ignored_without_loaded_db_match
        ),
        "unavailable_wages": len(unavailable_wages),
        "source_failures": len(source_failures),
        "deleted_wages": 0,
        "inserted_wages": 0,
    }
    report_payload = {
        "summary": summary,
        "ignored_source_players_without_loaded_db_match": (
            ignored_without_loaded_db_match
        ),
        "unavailable_wages": unavailable_wages,
        "source_failures": source_failures,
    }
    if source_failures:
        report_path = _write_wage_report(report_payload)
        summary["report_path"] = str(report_path)
        raise RuntimeError(
            "Capology wage source coverage is incomplete; no wages were written. "
            f"source_failures={len(source_failures)} report={report_path}"
        )

    delete_scopes = [
        (int(target["team_id"]), int(target["season_id"]))
        for target in targets
    ]
    with transaction() as connection:
        with connection.cursor() as cursor:
            cursor.executemany(SQL_DELETE_TEAM_SEASON_WAGES, delete_scopes)
            deleted_wages = int(cursor.rowcount)
            inserted_wages = 0
            if wage_rows:
                cursor.executemany(SQL_INSERT_WAGE, wage_rows)
                inserted_wages = int(cursor.rowcount)

    summary["deleted_wages"] = deleted_wages
    summary["inserted_wages"] = inserted_wages
    report_path = _write_wage_report(report_payload)
    summary["report_path"] = str(report_path)
    print(
        "[wages] completed "
        f"season={season_name or 'all'} competition={competition_id} "
        f"mapped={len(wage_rows)} ignored="
        f"{len(ignored_without_loaded_db_match)} "
        f"unavailable={len(unavailable_wages)} "
        f"deleted={deleted_wages} inserted={inserted_wages} "
        f"report={report_path}"
    )
    return summary


def collect_all_wages() -> Dict[str, object]:
    return _collect_wages()


def collect_wages_for_competition_season(
    season_name: str,
    competition_id: int,
) -> Dict[str, object]:
    return _collect_wages(
        season_name=season_name,
        competition_id=competition_id,
    )
