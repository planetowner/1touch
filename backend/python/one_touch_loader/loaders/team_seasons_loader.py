"""Sportmonks 시즌 참가 팀과 DB의 팀을 연결해요.

``all``은 DB에 저장된 모든 시즌을 처리해요. 시즌 이름을 입력하면 같은 이름을 가진
모든 대회 시즌을 처리해요. 완료된 시즌은 실제 경기 참가 팀까지 확인하고, 현재 시즌은
Sportmonks가 반환한 참가 팀을 사용해요. 그중 ``teams``에 있는 팀만 저장해요.
"""

from __future__ import annotations

from typing import Dict, List, Optional, Set, Tuple

from ..core.db import fetch_all, transaction
from ..core.sportmonks import SportmonksClient


MIN_SEASON_START_YEAR = 2017

SQL_SELECT_ALL_SEASONS = """
SELECT season_id, competition_id, name, is_current
FROM seasons
WHERE CAST(LEFT(name, 4) AS UNSIGNED) >= %s
ORDER BY name, competition_id, season_id
"""

SQL_SELECT_SEASONS_BY_NAME = """
SELECT season_id, competition_id, name, is_current
FROM seasons
WHERE name = %s
  AND CAST(LEFT(name, 4) AS UNSIGNED) >= %s
ORDER BY competition_id, season_id
"""

SQL_SELECT_TEAM_IDS = "SELECT team_id FROM teams ORDER BY team_id"

SQL_SELECT_SEASON_MEMBERSHIPS = """
SELECT team_id, season_id FROM team_seasons
WHERE season_id = %s
"""

SQL_DELETE_TEAM_SEASON = """
DELETE FROM team_seasons WHERE team_id = %s AND season_id = %s
"""

SQL_INSERT_TEAM_SEASON = """
INSERT INTO team_seasons (team_id, season_id)
VALUES (%s, %s)
"""

SeasonRow = Tuple[int, int, str, bool]


def _load_scope(season_name: Optional[str]) -> List[SeasonRow]:
    if season_name is None:
        rows = fetch_all(SQL_SELECT_ALL_SEASONS, (MIN_SEASON_START_YEAR,))
    else:
        if not isinstance(season_name, str) or not season_name.strip():
            raise ValueError("season_name must be a non-empty string")
        season_name = season_name.strip()
        rows = fetch_all(
            SQL_SELECT_SEASONS_BY_NAME,
            (season_name, MIN_SEASON_START_YEAR),
        )

    scope = [
        (int(row[0]), int(row[1]), str(row[2]), bool(row[3]))
        for row in rows
    ]
    if not scope:
        if season_name is None:
            raise ValueError("seasons table is empty")
        raise ValueError(f"No seasons found with name={season_name!r}")
    return scope


def _load_team_ids() -> Set[int]:
    team_ids = {int(row[0]) for row in fetch_all(SQL_SELECT_TEAM_IDS)}
    if not team_ids:
        raise ValueError("teams table is empty")
    return team_ids


def _collect_season_memberships(
    sm: SportmonksClient,
    season_id: int,
    stored_team_ids: Set[int],
    is_current: bool,
) -> Tuple[List[Tuple[int, int]], Dict[str, object]]:
    provider_team_ids: Set[int] = set()

    for index, team in enumerate(sm.iter_teams_by_season(season_id)):
        if not isinstance(team, dict):
            raise ValueError(
                f"Expected team object: season_id={season_id}, index={index}"
            )
        team_id = team.get("id")
        if type(team_id) is not int:
            raise ValueError(
                f"Invalid team id: season_id={season_id}, "
                f"index={index}, id={team_id!r}"
            )
        provider_team_ids.add(team_id)

    if not provider_team_ids:
        if is_current:
            # 참가 팀이 아직 공개되지 않은 현재 시즌은 다음 적재 때 다시 확인해요.
            return (
                [],
                {
                    "provider_team_count": 0,
                    "fixture_team_count": None,
                    "stored_team_count": 0,
                    "skipped_without_fixture_count": 0,
                    "skipped_missing_team_count": 0,
                    "is_pending": True,
                },
            )
        raise ValueError(
            f"Sportmonks returned no teams for season_id={season_id}"
        )

    eligible_team_ids = provider_team_ids
    fixture_team_ids: Optional[Set[int]] = None
    if not is_current:
        fixture_team_ids = set()
        for fixture_index, fixture in enumerate(
            sm.iter_fixtures_by_season(season_id, include="participants")
        ):
            if not isinstance(fixture, dict):
                raise ValueError(
                    "Expected fixture object: "
                    f"season_id={season_id}, index={fixture_index}"
                )
            participants = fixture.get("participants")
            if not isinstance(participants, list):
                raise ValueError(
                    "Expected fixture participants: "
                    f"season_id={season_id}, index={fixture_index}"
                )
            for participant_index, participant in enumerate(participants):
                if not isinstance(participant, dict):
                    raise ValueError(
                        "Expected fixture participant object: "
                        f"season_id={season_id}, fixture_index={fixture_index}, "
                        f"participant_index={participant_index}"
                    )
                team_id = participant.get("id")
                if type(team_id) is not int:
                    raise ValueError(
                        "Invalid fixture participant id: "
                        f"season_id={season_id}, fixture_index={fixture_index}, "
                        f"participant_index={participant_index}, id={team_id!r}"
                    )
                fixture_team_ids.add(team_id)

        if not fixture_team_ids:
            raise ValueError(
                f"Sportmonks returned no fixtures for historical season_id={season_id}"
            )

        # 시즌 참가 팀 응답에는 실제로 경기를 치르지 않은 팀도 섞일 수 있어요.
        eligible_team_ids = provider_team_ids.intersection(fixture_team_ids)

    matched_team_ids = sorted(eligible_team_ids.intersection(stored_team_ids))
    if not matched_team_ids:
        if is_current:
            # 현재 시즌에 저장할 팀이 없으면 참가 팀이 확정될 때까지 기다려요.
            return (
                [],
                {
                    "provider_team_count": len(provider_team_ids),
                    "fixture_team_count": None,
                    "stored_team_count": 0,
                    "skipped_without_fixture_count": 0,
                    "skipped_missing_team_count": len(provider_team_ids),
                    "is_pending": True,
                },
            )
        raise ValueError(
            "No Sportmonks teams exist in teams for "
            f"historical season_id={season_id}"
        )

    return (
        [(team_id, season_id) for team_id in matched_team_ids],
        {
            "provider_team_count": len(provider_team_ids),
            "fixture_team_count": (
                len(fixture_team_ids)
                if fixture_team_ids is not None
                else None
            ),
            "stored_team_count": len(matched_team_ids),
            "skipped_without_fixture_count": (
                len(provider_team_ids - eligible_team_ids)
            ),
            "skipped_missing_team_count": (
                len(eligible_team_ids - stored_team_ids)
            ),
            "is_pending": False,
        },
    )


def _collect_and_replace(season_name: Optional[str]) -> Dict[str, object]:
    scope = _load_scope(season_name)
    stored_team_ids = _load_team_ids()
    sm = SportmonksClient()
    rows_by_season: Dict[int, List[Tuple[int, int]]] = {}
    results: List[Dict[str, object]] = []

    for index, (season_id, competition_id, resolved_name, is_current) in enumerate(
        scope,
        start=1,
    ):
        rows, counts = _collect_season_memberships(
            sm,
            season_id,
            stored_team_ids,
            is_current,
        )
        rows_by_season[season_id] = rows
        result: Dict[str, object] = {
            "season_id": season_id,
            "competition_id": competition_id,
            "season_name": resolved_name,
            "is_current": is_current,
            **counts,
        }
        results.append(result)
        print(
            f"[team-seasons {index}/{len(scope)}] "
            f"competition_id={competition_id} season={resolved_name} "
            f"season_id={season_id} provider={counts['provider_team_count']} "
            f"fixtures={counts['fixture_team_count']} "
            f"stored={counts['stored_team_count']} "
            f"status={'pending' if counts['is_pending'] else 'stored'}"
        )

    membership_rows = [
        row
        for season_id, _, _, _ in scope
        for row in rows_by_season[season_id]
    ]
    with transaction() as connection:
        with connection.cursor() as cursor:
            existing_rows = set()
            for season_id, _, _, _ in scope:
                cursor.execute(SQL_SELECT_SEASON_MEMBERSHIPS, (season_id,))
                existing_rows.update(cursor.fetchall())
            # 유지할 관계까지 지우면 Best Eleven FK가 막고, 주급·순위는 함께 삭제돼요.
            # 실제로 바뀐 관계만 반영해 재실행 때 기존 하위 데이터를 보존해요.
            incoming_rows = set(membership_rows)
            removed_rows = sorted(existing_rows - incoming_rows)
            added_rows = sorted(incoming_rows - existing_rows)
            if removed_rows:
                cursor.executemany(SQL_DELETE_TEAM_SEASON, removed_rows)
            if added_rows:
                cursor.executemany(SQL_INSERT_TEAM_SEASON, added_rows)

    summary: Dict[str, object] = {
        "mode": "all" if season_name is None else "season_name",
        "requested_season_name": season_name,
        "processed_seasons": len(scope),
        "stored_memberships": len(membership_rows),
        "pending_seasons": sum(
            1 for result in results if result["is_pending"]
        ),
        "results": results,
    }
    print(
        f"[team-seasons] completed seasons={len(scope)} "
        f"memberships={len(membership_rows)} "
        f"pending={summary['pending_seasons']}"
    )
    return summary


def collect_all_team_seasons() -> Dict[str, object]:
    """DB에 있는 모든 시즌의 팀 관계를 다시 저장해요."""
    return _collect_and_replace(None)


def collect_team_seasons_for_name(season_name: str) -> Dict[str, object]:
    """이름이 정확히 같은 모든 대회 시즌의 팀 관계를 다시 저장해요."""
    return _collect_and_replace(season_name)
