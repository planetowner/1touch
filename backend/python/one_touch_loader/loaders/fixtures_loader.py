"""Sportmonks 경기 응답을 정규화해 fixtures와 관계 마스터에 저장해요.

CLI 사용법::

    python -m one_touch_loader.cli fixtures all
    python -m one_touch_loader.cli fixtures "2025/2026" 8

일반 대회는 선택한 Sportmonks 시즌의 실제 fixture를 모두 수집해요. FA컵(24)과
카라바오컵(27)은 같은 시즌 프리미어리그(8) 팀이 참가한 경기만, 코파 이탈리아(390)는
세리에 A(384), 코파 델 레이(570)는 라리가(564) 팀이 참가한 경기만 저장해요.
Sportmonks의 league_id는 1Touch DB의 competition_id와 같은 값으로 연결해요.

fixture.leg는 1/1, 1/2, 2/2 같은 원문을 그대로 저장해 경기 방식과 차전을
대회별 규칙 없이 판단해요. aggregate는 Sportmonks가 제공한 경우에만 저장하고,
누락된 대진을 팀·날짜·점수로 추정해 만들지 않아요. aggregate의
winner_participant_id는 1Touch DB의 winner_team_id로 연결해요. aggregate의
name, fixture_ids, result, detail은 fixtures 관계와 점수로 조회할 수 있어
중복 저장하지 않아요. 과거 aggregate의 우승 팀 ID가 현재 fixture 참가자 ID와
다르면 추측해 매핑하지 않고 winner_team_id를 NULL로 저장해요.
"""

from __future__ import annotations

import re
from datetime import datetime
from typing import Dict, List, Optional, Set, Tuple

from ..core.db import fetch_all, transaction
from ..core.sportmonks import SportmonksClient
from .teams_loader import (
    CUP_BASE_COMPETITION_IDS,
    MIN_SEASON_START_YEAR,
    SUPPORTED_COMPETITION_IDS,
)


SPORTMONKS_CURRENT_SCORE_TYPE_ID = 1525
SPORTMONKS_PENALTY_SCORE_TYPE_ID = 5
FIXTURE_INCLUDE = "participants;state;scores;round;stage;group;venue;aggregate"

SQL_SELECT_ALL_SCOPE = """
SELECT season_id, competition_id, name, is_current
FROM seasons
WHERE competition_id IN (2,5,8,24,27,82,301,384,390,564,570,2286)
  AND CAST(LEFT(name, 4) AS UNSIGNED) >= %s
"""

SQL_SELECT_SCOPE = """
SELECT season_id, competition_id, name, is_current
FROM seasons
WHERE name = %s
  AND competition_id = %s
  AND CAST(LEFT(name, 4) AS UNSIGNED) >= %s
ORDER BY season_id
"""

SQL_SELECT_TEAM_IDS = "SELECT team_id FROM teams ORDER BY team_id"

SQL_SELECT_BASE_TEAM_IDS = """
SELECT ts.team_id
FROM team_seasons ts
JOIN seasons s ON s.season_id = ts.season_id
WHERE s.name = %s
  AND s.competition_id = %s
ORDER BY ts.team_id
"""

SQL_UPSERT_STAGE = """
INSERT INTO stages (stage_id, season_id, stage_type_id, name)
VALUES (%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  season_id = VALUES(season_id),
  stage_type_id = VALUES(stage_type_id),
  name = VALUES(name)
"""

SQL_UPSERT_GROUP = """
INSERT INTO stage_groups (group_id, stage_id, competition_id, season_id, name)
VALUES (%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  stage_id = VALUES(stage_id),
  competition_id = VALUES(competition_id),
  season_id = VALUES(season_id),
  name = VALUES(name)
"""

SQL_UPSERT_ROUND = """
INSERT INTO rounds (round_id, stage_id, name)
VALUES (%s,%s,%s)
ON DUPLICATE KEY UPDATE
  stage_id = VALUES(stage_id),
  name = VALUES(name)
"""

SQL_UPSERT_VENUE = """
INSERT INTO venues (venue_id, name)
VALUES (%s,%s)
ON DUPLICATE KEY UPDATE
  name = VALUES(name)
"""

SQL_UPSERT_FIXTURE_STATE = """
INSERT INTO fixture_states (state_id, state_code, name)
VALUES (%s,%s,%s)
ON DUPLICATE KEY UPDATE
  state_code = VALUES(state_code),
  name = VALUES(name)
"""

SQL_UPSERT_AGGREGATE = """
INSERT INTO aggregates (aggregate_id, stage_id, winner_team_id)
VALUES (%s,%s,%s)
ON DUPLICATE KEY UPDATE
  stage_id = VALUES(stage_id),
  winner_team_id = VALUES(winner_team_id)
"""

SQL_UPSERT_FIXTURE = """
INSERT INTO fixtures (
  fixture_id,
  stage_id,
  round_id,
  group_id,
  aggregate_id,
  leg,
  home_team_id,
  away_team_id,
  starting_at,
  venue_id,
  state_id,
  home_score,
  away_score,
  home_penalty_score,
  away_penalty_score
)
VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  stage_id = VALUES(stage_id),
  round_id = VALUES(round_id),
  group_id = VALUES(group_id),
  aggregate_id = VALUES(aggregate_id),
  leg = VALUES(leg),
  home_team_id = VALUES(home_team_id),
  away_team_id = VALUES(away_team_id),
  starting_at = VALUES(starting_at),
  venue_id = VALUES(venue_id),
  state_id = VALUES(state_id),
  home_score = VALUES(home_score),
  away_score = VALUES(away_score),
  home_penalty_score = VALUES(home_penalty_score),
  away_penalty_score = VALUES(away_penalty_score)
"""

SeasonRow = Tuple[int, int, str, bool]
FixtureRow = Tuple[
    int,
    int,
    Optional[int],
    Optional[int],
    Optional[int],
    str,
    int,
    int,
    Optional[datetime],
    Optional[int],
    int,
    Optional[int],
    Optional[int],
    Optional[int],
    Optional[int],
]


def _optional_datetime(value) -> Optional[datetime]:
    if value is None:
        return None
    return datetime.strptime(value, "%Y-%m-%d %H:%M:%S")


def _season_start_year(season_name: str) -> int:
    match = re.fullmatch(r"(\d{4})/(\d{4})", season_name)
    if match is None:
        raise ValueError(f"Unsupported season name: {season_name!r}")
    start_year = int(match.group(1))
    end_year = int(match.group(2))
    if end_year != start_year + 1:
        raise ValueError(f"Unsupported season name: {season_name!r}")
    return start_year


def _load_scope(
    season_name: Optional[str],
    competition_id: Optional[int],
) -> List[SeasonRow]:
    if season_name is None and competition_id is None:
        rows = fetch_all(SQL_SELECT_ALL_SCOPE, (MIN_SEASON_START_YEAR,))
    elif season_name is not None and competition_id is not None:
        season_name = season_name.strip()
        if competition_id not in SUPPORTED_COMPETITION_IDS:
            raise ValueError(
                f"Unsupported competition_id={competition_id}. "
                f"Allowed ids: {list(SUPPORTED_COMPETITION_IDS)}"
            )
        if _season_start_year(season_name) < MIN_SEASON_START_YEAR:
            raise ValueError(
                f"Season {season_name!r} is before the supported minimum 2017/2018."
            )
        rows = fetch_all(
            SQL_SELECT_SCOPE,
            (season_name, competition_id, MIN_SEASON_START_YEAR),
        )
    else:
        raise ValueError("season_name and competition_id must be provided together")

    scope = [
        (int(row[0]), int(row[1]), str(row[2]), bool(row[3]))
        for row in rows
    ]
    if not scope:
        if season_name is None:
            raise ValueError("No supported seasons exist in seasons")
        raise ValueError(
            f"No DB season found for season={season_name!r}, "
            f"competition_id={competition_id}"
        )
    competition_order = {
        value: index for index, value in enumerate(SUPPORTED_COMPETITION_IDS)
    }
    scope.sort(
        key=lambda row: (
            _season_start_year(row[2]),
            competition_order[row[1]],
            row[0],
        )
    )
    return scope


def _load_team_ids() -> Set[int]:
    team_ids = {int(row[0]) for row in fetch_all(SQL_SELECT_TEAM_IDS)}
    if not team_ids:
        raise ValueError("teams is empty; run the teams collection first")
    return team_ids


def _load_base_team_ids(season_name: str, competition_id: int) -> Set[int]:
    team_ids = {
        int(row[0])
        for row in fetch_all(
            SQL_SELECT_BASE_TEAM_IDS,
            (season_name, competition_id),
        )
    }
    if not team_ids:
        raise ValueError(
            "No base-league team_seasons found for "
            f"season={season_name!r}, competition_id={competition_id}. "
            "Run team-seasons collection first."
        )
    return team_ids


def _fixture_participants(
    fixture: Dict,
) -> Optional[Tuple[int, int]]:
    if fixture["placeholder"]:
        return None

    by_location: Dict[str, int] = {}
    for participant in fixture["participants"]:
        if participant["placeholder"]:
            return None
        by_location[participant["meta"]["location"]] = participant["id"]
    return by_location["home"], by_location["away"]


def _score_pair(
    fixture: Dict,
    home_team_id: int,
    away_team_id: int,
    type_id: int,
) -> Tuple[Optional[int], Optional[int]]:
    values = {
        score["participant_id"]: score["score"]["goals"]
        for score in fixture["scores"]
        if score["type_id"] == type_id
    }

    if not values:
        return None, None
    return values[home_team_id], values[away_team_id]


def _normalize_fixture(
    fixture: Dict,
    expected_season_id: int,
    expected_competition_id: int,
) -> Optional[Dict[str, Tuple]]:
    participants = _fixture_participants(fixture)
    if participants is None:
        return None
    home_team_id, away_team_id = participants
    fixture_id = fixture["id"]

    stage_id = fixture["stage_id"]
    stage = fixture["stage"]
    stage_row = (
        stage_id,
        expected_season_id,
        stage["type_id"],
        stage["name"],
    )

    round_id = fixture["round_id"]
    round_row = None
    if round_id is not None:
        round_payload = fixture["round"]
        round_row = (
            round_id,
            stage_id,
            round_payload["name"],
        )

    group_id = fixture["group_id"]
    group_row = None
    if group_id is not None:
        group_payload = fixture["group"]
        group_row = (
            group_id,
            stage_id,
            expected_competition_id,
            expected_season_id,
            group_payload["name"],
        )

    aggregate_id = fixture["aggregate_id"]
    aggregate_row = None
    ignored_aggregate_winner_id = None
    if aggregate_id is not None:
        # 실제 UCL·UECL·코파 델 레이 응답에는 2차전인데 aggregate_id가 없는
        # 사례도 있었어요. 팀과 날짜로 추정해 연결하면 원본과 자체 추론을
        # 구분할 수 없으므로 Sportmonks가 준 대진만 저장해요.
        winner_team_id = fixture["aggregate"]["winner_participant_id"]
        aggregate_row = (
            aggregate_id,
            stage_id,
            winner_team_id,
        )
        if winner_team_id is not None and winner_team_id not in {
            home_team_id,
            away_team_id,
        }:
            # 과거 응답은 aggregate의 예전 팀 ID와 fixture의 현재 팀 ID가 다를 수 있어요.
            # 검증할 수 없는 팀 ID를 추측해 연결하지 않고 우승 팀만 비워 둬요.
            ignored_aggregate_winner_id = winner_team_id
            aggregate_row = (aggregate_row[0], aggregate_row[1], None)

    venue_id = fixture["venue_id"]
    venue_row = None
    if venue_id is not None:
        venue_row = (venue_id, fixture["venue"]["name"])

    state_id = fixture["state_id"]
    state_payload = fixture["state"]
    state_row = (
        state_id,
        state_payload["state"],
        state_payload["name"],
    )

    home_score, away_score = _score_pair(
        fixture,
        home_team_id,
        away_team_id,
        SPORTMONKS_CURRENT_SCORE_TYPE_ID,
    )
    home_penalty_score, away_penalty_score = _score_pair(
        fixture,
        home_team_id,
        away_team_id,
        SPORTMONKS_PENALTY_SCORE_TYPE_ID,
    )

    # Sportmonks의 1/1, 1/2, 2/2를 가공하지 않아요. 실제 UECL 응답에서
    # 2차전 대진 일부가 1/1로 내려온 사례도 원본 그대로 보존해요.
    fixture_row: FixtureRow = (
        fixture_id,
        stage_id,
        round_id,
        group_id,
        aggregate_id,
        fixture["leg"],
        home_team_id,
        away_team_id,
        _optional_datetime(fixture["starting_at"]),
        venue_id,
        state_id,
        home_score,
        away_score,
        home_penalty_score,
        away_penalty_score,
    )
    return {
        "stage": stage_row,
        "round": round_row,
        "group": group_row,
        "aggregate": aggregate_row,
        "ignored_aggregate_winner_id": ignored_aggregate_winner_id,
        "venue": venue_row,
        "state": state_row,
        "fixture": fixture_row,
    }


def _fixture_state_rows(sm: SportmonksClient) -> List[Tuple[int, str, str]]:
    rows = {
        state["id"]: (state["id"], state["state"], state["name"])
        for state in sm.iter_states()
    }
    return [rows[state_id] for state_id in sorted(rows)]


def _upsert_fixture_states(rows: List[Tuple[int, str, str]]) -> None:
    with transaction() as connection:
        with connection.cursor() as cursor:
            cursor.executemany(SQL_UPSERT_FIXTURE_STATE, rows)


def _collect_and_upsert(
    sm: SportmonksClient,
    season: SeasonRow,
    stored_team_ids: Set[int],
    progress: Optional[Tuple[int, int]] = None,
) -> Dict[str, object]:
    season_id, competition_id, season_name, is_current = season
    base_competition_id = CUP_BASE_COMPETITION_IDS.get(competition_id)
    base_team_ids = (
        _load_base_team_ids(season_name, base_competition_id)
        if base_competition_id is not None
        else None
    )

    stages: Dict[int, Tuple] = {}
    rounds: Dict[int, Tuple] = {}
    groups: Dict[int, Tuple] = {}
    venues: Dict[int, Tuple] = {}
    states: Dict[int, Tuple] = {}
    aggregates: Dict[int, Tuple] = {}
    fixtures: Dict[int, FixtureRow] = {}
    provider_fixture_count = 0
    skipped_placeholder_count = 0
    skipped_unrelated_cup_count = 0
    ignored_aggregate_winner_ids: Set[int] = set()

    for raw_fixture in sm.iter_fixtures_by_season(
        season_id,
        per_page=50,
        include=FIXTURE_INCLUDE,
    ):
        provider_fixture_count += 1
        normalized = _normalize_fixture(
            raw_fixture,
            season_id,
            competition_id,
        )
        if normalized is None:
            skipped_placeholder_count += 1
            continue

        fixture_row = normalized["fixture"]
        if base_team_ids is not None and not {
            int(fixture_row[6]),
            int(fixture_row[7]),
        }.intersection(base_team_ids):
            skipped_unrelated_cup_count += 1
            continue

        missing_team_ids = {
            int(fixture_row[6]),
            int(fixture_row[7]),
        } - stored_team_ids
        if missing_team_ids:
            raise ValueError(
                "Fixture teams are missing from teams for "
                f"fixture_id={fixture_row[0]}: "
                f"team_ids={sorted(missing_team_ids)}. Run teams collection first."
            )

        stages[int(normalized["stage"][0])] = normalized["stage"]
        if normalized["round"] is not None:
            rounds[int(normalized["round"][0])] = normalized["round"]
        if normalized["group"] is not None:
            groups[int(normalized["group"][0])] = normalized["group"]
        if normalized["aggregate"] is not None:
            aggregates[int(normalized["aggregate"][0])] = normalized["aggregate"]
        if normalized["ignored_aggregate_winner_id"] is not None:
            ignored_aggregate_winner_ids.add(
                int(normalized["ignored_aggregate_winner_id"])
            )
        if normalized["venue"] is not None:
            venues[int(normalized["venue"][0])] = normalized["venue"]
        states[int(normalized["state"][0])] = normalized["state"]
        fixtures[int(fixture_row[0])] = fixture_row

    if not fixtures and not is_current:
        raise ValueError(
            f"No fixtures selected for season={season_name!r}, "
            f"competition_id={competition_id}, season_id={season_id}"
        )

    if fixtures:
        with transaction() as connection:
            with connection.cursor() as cursor:
                cursor.executemany(
                    SQL_UPSERT_STAGE,
                    [stages[key] for key in sorted(stages)],
                )
                if groups:
                    cursor.executemany(
                        SQL_UPSERT_GROUP,
                        [groups[key] for key in sorted(groups)],
                    )
                if rounds:
                    cursor.executemany(
                        SQL_UPSERT_ROUND,
                        [rounds[key] for key in sorted(rounds)],
                    )
                if venues:
                    cursor.executemany(
                        SQL_UPSERT_VENUE,
                        [venues[key] for key in sorted(venues)],
                    )
                cursor.executemany(
                    SQL_UPSERT_FIXTURE_STATE,
                    [states[key] for key in sorted(states)],
                )
                if aggregates:
                    cursor.executemany(
                        SQL_UPSERT_AGGREGATE,
                        [aggregates[key] for key in sorted(aggregates)],
                    )
                cursor.executemany(
                    SQL_UPSERT_FIXTURE,
                    [fixtures[key] for key in sorted(fixtures)],
                )

    result: Dict[str, object] = {
        "season_id": season_id,
        "season_name": season_name,
        "competition_id": competition_id,
        "is_current": is_current,
        "is_pending": not fixtures,
        "base_competition_id": base_competition_id,
        "provider_fixture_count": provider_fixture_count,
        "stored_fixture_count": len(fixtures),
        "skipped_placeholder_count": skipped_placeholder_count,
        "skipped_unrelated_cup_count": skipped_unrelated_cup_count,
        "stage_count": len(stages),
        "round_count": len(rounds),
        "group_count": len(groups),
        "aggregate_count": len(aggregates),
        "venue_count": len(venues),
        "ignored_aggregate_winner_count": len(ignored_aggregate_winner_ids),
    }
    prefix = (
        f"[fixtures {progress[0]}/{progress[1]}]"
        if progress is not None
        else "[fixtures]"
    )
    print(
        f"{prefix} competition_id={competition_id} season={season_name} "
        f"season_id={season_id} provider={provider_fixture_count} "
        f"stored={len(fixtures)} placeholders={skipped_placeholder_count} "
        f"unrelated_cup={skipped_unrelated_cup_count} "
        f"ignored_aggregate_winners={len(ignored_aggregate_winner_ids)} "
        f"status={'pending' if not fixtures else 'stored'}"
    )
    return result


def collect_fixtures_for_competition_season(
    season_name: str,
    competition_id: int,
) -> Dict[str, object]:
    season = _load_scope(season_name, competition_id)[0]
    stored_team_ids = _load_team_ids()
    sm = SportmonksClient()
    _upsert_fixture_states(_fixture_state_rows(sm))
    return _collect_and_upsert(
        sm,
        season,
        stored_team_ids,
    )


def collect_all_fixtures() -> Dict[str, object]:
    scope = _load_scope(None, None)
    stored_team_ids = _load_team_ids()
    sm = SportmonksClient()
    _upsert_fixture_states(_fixture_state_rows(sm))
    results = [
        _collect_and_upsert(
            sm,
            season,
            stored_team_ids,
            (index, len(scope)),
        )
        for index, season in enumerate(scope, start=1)
    ]
    return {
        "mode": "all",
        "minimum_season_start_year": MIN_SEASON_START_YEAR,
        "competition_ids": list(SUPPORTED_COMPETITION_IDS),
        "collection_runs": len(results),
        "stored_fixtures": sum(
            int(result["stored_fixture_count"]) for result in results
        ),
        "results": results,
    }
