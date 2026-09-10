from __future__ import annotations

import json
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from ..core.db import fetch_all, transaction
from ..core.identity import reciprocal_identity_matches
from .capology_common import (
    _CapologyBrowserSession,
    _capology_league_salary_url,
    _capology_salary_url,
    _load_target_observations,
    _observation_name_keys,
    _parse_capology_salary_page,
    _season_to_capology,
)
from .team_squad_members_loader import (
    BIG5_COMPETITION_IDS,
    MIN_SEASON_START_YEAR,
)


MIN_TEAM_PLAYER_OVERLAP = 3
CAPOLOGY_TEAM_SLUGS_DIAGNOSTICS_DIRECTORY = (
    Path(__file__).resolve().parents[3] / "logs" / "diagnostics"
)

SQL_SELECT_TARGET_TEAM_SEASONS = """
SELECT
  seasons.competition_id,
  seasons.season_id,
  seasons.name,
  seasons.is_current,
  teams.team_id,
  teams.name
FROM team_seasons
JOIN seasons
  ON seasons.season_id = team_seasons.season_id
JOIN teams
  ON teams.team_id = team_seasons.team_id
WHERE seasons.competition_id IN (8,82,301,384,564)
  AND CAST(LEFT(seasons.name, 4) AS UNSIGNED) >= %s
ORDER BY
  seasons.name,
  seasons.competition_id,
  teams.team_id
"""

SQL_SELECT_CAPOLOGY_TEAM_SLUGS = """
SELECT team_id, external_team_id
FROM team_external_ids
WHERE provider = 'capology'
ORDER BY team_id
"""

SQL_INSERT_CAPOLOGY_TEAM_SLUG = """
INSERT INTO team_external_ids (
  team_id,
  provider,
  external_team_id
)
VALUES (%s,'capology',%s)
"""


def _write_report(payload: Dict[str, object]) -> Path:
    CAPOLOGY_TEAM_SLUGS_DIAGNOSTICS_DIRECTORY.mkdir(
        parents=True,
        exist_ok=True,
    )
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = (
        CAPOLOGY_TEAM_SLUGS_DIAGNOSTICS_DIRECTORY
        / f"capology_team_slugs_{stamp}.json"
    )
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, default=str),
        encoding="utf-8",
    )
    return path


def _extract_capology_team_slugs(html: str) -> List[str]:
    slugs = {
        match.group("slug")
        for match in re.finditer(
            r"href=['\"](?:https://www\.capology\.com)?/club/"
            r"(?P<slug>[a-z0-9-]+)/salaries/"
            r"(?:\d{4}-\d{4}/?)?['\"]",
            html,
            flags=re.IGNORECASE,
        )
    }
    if not slugs:
        raise ValueError("Capology page has no same-league salary links")
    return sorted(slugs)


def _reciprocal_team_matches(
    observations: List[Dict[str, object]],
    source_teams: Dict[str, List[Dict[str, object]]],
) -> Tuple[Dict[int, str], List[Dict[str, object]]]:
    observations_by_team: Dict[int, List[Dict[str, object]]] = defaultdict(list)
    for observation in observations:
        observations_by_team[int(observation["team_id"])].append(observation)

    db_name_sets = {
        team_id: set().union(
            *(_observation_name_keys(item) for item in team_observations)
        )
        for team_id, team_observations in observations_by_team.items()
    }
    source_name_sets = {
        team_slug: {
            str(source_player["normalized_name"])
            for source_player in source_players
        }
        for team_slug, source_players in source_teams.items()
    }
    # 두 공급자 모두 선수 명단의 정확한 이름 겹침으로 팀을 연결해요.
    reciprocal = reciprocal_identity_matches(db_name_sets, source_name_sets, MIN_TEAM_PLAYER_OVERLAP)
    matches: Dict[int, str] = {}
    evidence: List[Dict[str, object]] = []
    for team_id, (team_slug, overlap) in reciprocal.items():
        matches[team_id] = team_slug
        team_name = str(observations_by_team[team_id][0]["team_name"])
        evidence.append(
            {
                "team_id": team_id,
                "team_name": team_name,
                "capology_team_slug": team_slug,
                "exact_player_name_overlap": overlap,
            }
        )
    return matches, evidence


def _collect_source_groups(
    observations: List[Dict[str, object]],
) -> Tuple[
    Dict[Tuple[int, str], Dict[str, List[Dict[str, object]]]],
    List[Dict[str, object]],
    int,
]:
    group_keys = sorted(
        {
            (
                int(item["competition_id"]),
                str(item["season_name"]),
                bool(item["is_current"]),
            )
            for item in observations
        }
    )
    session = _CapologyBrowserSession()
    source_groups: Dict[
        Tuple[int, str], Dict[str, List[Dict[str, object]]]
    ] = {}
    failures: List[Dict[str, object]] = []
    fetched_pages = 0

    for group_index, (competition_id, season_name, is_current) in enumerate(
        group_keys,
        start=1,
    ):
        league_url = _capology_league_salary_url(
            competition_id,
            season_name,
            is_current,
        )
        try:
            # 특정 구단이 강등돼도 시즌 참가팀 발견이 깨지지 않게 리그 페이지를 출발점으로 써요.
            league_html, _ = session.fetch(
                league_url,
                require_player_data=False,
            )
            team_slugs = set(_extract_capology_team_slugs(league_html))
        except ValueError as exc:
            failures.append(
                {
                    "competition_id": competition_id,
                    "season_name": season_name,
                    "team_slug": None,
                    "source_url": league_url,
                    "error_type": type(exc).__name__,
                    "error": str(exc),
                }
            )
            print(
                f"[capology-team-slugs groups {group_index}/{len(group_keys)}] "
                f"season={season_name} competition={competition_id}: "
                f"ERROR {type(exc).__name__}: {exc}"
            )
            continue

        source_teams: Dict[str, List[Dict[str, object]]] = {}
        for team_index, team_slug in enumerate(sorted(team_slugs), start=1):
            source_url = _capology_salary_url(
                team_slug,
                season_name,
                is_current,
            )
            try:
                html, response_url = session.fetch(source_url)
                source_players = _parse_capology_salary_page(
                    html,
                    season_name,
                )
                for source_player in source_players:
                    source_player["team_slug"] = team_slug
                    source_player["source_url"] = response_url
                source_teams[team_slug] = source_players
                fetched_pages += 1
                print(
                    f"[capology-team-slugs sources {group_index}/{len(group_keys)} "
                    f"team {team_index}/{len(team_slugs)}] "
                    f"season={season_name} competition={competition_id} "
                    f"team={team_slug} players={len(source_players)}"
                )
            except ValueError as exc:
                # Windows CP949 콘솔 때문에 외부 선수명 출력이 적재를 중단하지 않게 해요.
                console_error = str(exc).encode(
                    "ascii",
                    errors="backslashreplace",
                ).decode("ascii")
                failures.append(
                    {
                        "competition_id": competition_id,
                        "season_name": season_name,
                        "team_slug": team_slug,
                        "source_url": source_url,
                        "error_type": type(exc).__name__,
                        "error": str(exc),
                    }
                )
                print(
                    f"[capology-team-slugs sources {group_index}/{len(group_keys)} "
                    f"team {team_index}/{len(team_slugs)}] "
                    f"season={season_name} competition={competition_id} "
                    f"team={team_slug}: ERROR {type(exc).__name__}: {console_error}"
                )
        if source_teams:
            source_groups[(competition_id, season_name)] = source_teams

    session.close()
    return source_groups, failures, fetched_pages


def _load_target_team_seasons(
    season_name: Optional[str] = None,
    competition_id: Optional[int] = None,
) -> List[Dict[str, object]]:
    if (season_name is None) != (competition_id is None):
        raise ValueError("season_name and competition_id must be provided together")
    if season_name is not None:
        start_year = int(_season_to_capology(season_name)[:4])
        if start_year < MIN_SEASON_START_YEAR:
            raise ValueError(
                f"Season {season_name!r} is before the supported minimum 2017/2018"
            )
        if competition_id not in BIG5_COMPETITION_IDS:
            raise ValueError(
                f"Unsupported Big 5 competition_id={competition_id}. "
                f"Allowed ids: {list(BIG5_COMPETITION_IDS)}"
            )

    rows = fetch_all(SQL_SELECT_TARGET_TEAM_SEASONS, (MIN_SEASON_START_YEAR,))
    targets = [
        {
            "competition_id": int(row[0]),
            "season_id": int(row[1]),
            "season_name": str(row[2]),
            "is_current": bool(row[3]),
            "team_id": int(row[4]),
            "team_name": str(row[5]),
        }
        for row in rows
        if season_name is None
        or (str(row[2]) == season_name and int(row[0]) == competition_id)
    ]
    if not targets:
        if season_name is None:
            raise ValueError(
                "team_seasons contains no Big 5 teams from 2017/2018 onward"
            )
        raise ValueError(
            "team_seasons contains no teams for "
            f"season_name={season_name!r}, competition_id={competition_id}"
        )
    return targets


def _insert_team_slugs(rows: List[Tuple[int, str]]) -> int:
    if not rows:
        return 0
    with transaction() as conn:
        with conn.cursor() as cursor:
            cursor.executemany(SQL_INSERT_CAPOLOGY_TEAM_SLUG, rows)
            return int(cursor.rowcount)


def _collect_capology_team_slugs(
    season_name: Optional[str] = None,
    competition_id: Optional[int] = None,
) -> Dict[str, object]:
    targets = _load_target_team_seasons(season_name, competition_id)
    existing_rows = fetch_all(SQL_SELECT_CAPOLOGY_TEAM_SLUGS)
    existing_by_team = {
        int(team_id): str(external_team_id)
        for team_id, external_team_id in existing_rows
    }
    target_team_ids = {int(item["team_id"]) for item in targets}
    missing_team_ids = target_team_ids - set(existing_by_team)
    needed_group_keys = {
        (int(item["competition_id"]), str(item["season_name"]))
        for item in targets
        if int(item["team_id"]) in missing_team_ids
    }
    source_groups: Dict[
        Tuple[int, str], Dict[str, List[Dict[str, object]]]
    ] = {}
    source_failures: List[Dict[str, object]] = []
    fetched_pages = 0
    observations: List[Dict[str, object]] = []
    if needed_group_keys:
        observations = _load_target_observations(season_name, competition_id)
        discovery_observations = [
            item
            for item in observations
            if (
                int(item["competition_id"]),
                str(item["season_name"]),
            )
            in needed_group_keys
        ]
        if discovery_observations:
            (
                source_groups,
                source_failures,
                fetched_pages,
            ) = _collect_source_groups(
                discovery_observations,
            )

    observations_by_group: Dict[
        Tuple[int, str], List[Dict[str, object]]
    ] = defaultdict(list)
    for observation in observations:
        observations_by_group[
            (
                int(observation["competition_id"]),
                str(observation["season_name"]),
            )
        ].append(observation)

    discovered_by_team: Dict[int, str] = {}
    mapping_evidence: List[Dict[str, object]] = []
    for group_key in sorted(needed_group_keys):
        source_teams = source_groups.get(group_key)
        if source_teams is None:
            continue
        team_matches, evidence = _reciprocal_team_matches(
            observations_by_group.get(group_key, []),
            source_teams,
        )
        target_ids_in_group = {
            int(item["team_id"])
            for item in targets
            if (
                int(item["competition_id"]),
                str(item["season_name"]),
            )
            == group_key
        }
        for item in evidence:
            team_id = int(item["team_id"])
            if team_id not in target_ids_in_group or team_id not in missing_team_ids:
                continue
            team_slug = str(item["capology_team_slug"])
            discovered_by_team[team_id] = team_slug
            mapping_evidence.append(
                {
                    "competition_id": group_key[0],
                    "season_name": group_key[1],
                    **item,
                }
            )

    rows_to_insert = sorted(discovered_by_team.items())
    inserted_mappings = _insert_team_slugs(rows_to_insert)
    mapped_team_ids = set(existing_by_team) | set(discovered_by_team)
    unmatched = [
        item
        for item in targets
        if int(item["team_id"]) not in mapped_team_ids
    ]
    summary: Dict[str, object] = {
        "target_team_seasons": len(targets),
        "target_teams": len(target_team_ids),
        "existing_mappings": len(target_team_ids & set(existing_by_team)),
        "discovered_mappings": len(discovered_by_team),
        "inserted_mappings": inserted_mappings,
        "mapped_team_seasons": len(targets) - len(unmatched),
        "unmatched_team_seasons": len(unmatched),
        "fetched_capology_pages": fetched_pages,
        "source_failures": len(source_failures),
    }
    report_path = _write_report(
        {
            "scope": {
                "season_name": season_name or "all",
                "competition_id": competition_id,
            },
            "summary": summary,
            "mapping_evidence": mapping_evidence,
            "unmatched": unmatched,
            "source_failures": source_failures,
        }
    )
    summary["report_path"] = str(report_path)
    print(
        "[capology-team-slugs] completed "
        f"target_team_seasons={summary['target_team_seasons']} "
        f"target_teams={summary['target_teams']} "
        f"existing={summary['existing_mappings']} "
        f"inserted={summary['inserted_mappings']} "
        f"unmatched_team_seasons={summary['unmatched_team_seasons']} "
        f"source_failures={summary['source_failures']} "
        f"report={report_path}"
    )
    return summary


def collect_all_capology_team_slugs() -> Dict[str, object]:
    return _collect_capology_team_slugs()


def collect_capology_team_slugs_for_competition_season(
    season_name: str,
    competition_id: int,
) -> Dict[str, object]:
    return _collect_capology_team_slugs(
        season_name=season_name,
        competition_id=competition_id,
    )
