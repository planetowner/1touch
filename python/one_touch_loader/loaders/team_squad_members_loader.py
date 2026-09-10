from __future__ import annotations

import re
from collections import defaultdict
from datetime import date, datetime, timedelta
from typing import DefaultDict, Dict, Iterable, List, Optional, Set, Tuple

from ..core.db import fetch_all, transaction
from ..core.fixture_states import COMPLETED_STATE_IDS
from ..core.sportmonks import SportmonksClient


BIG5_COMPETITION_IDS = (8, 82, 301, 384, 564)
COMPLETED_STATE_IDS_SQL = ",".join(str(value) for value in COMPLETED_STATE_IDS)
MIN_SEASON_START_YEAR = 2017
SPORTMONKS_STARTER_TYPE_ID = 11
SPORTMONKS_BENCH_TYPE_ID = 12
SPORTMONKS_MATCHDAY_LINEUP_TYPE_IDS = {
    SPORTMONKS_STARTER_TYPE_ID,
    SPORTMONKS_BENCH_TYPE_ID,
}
SPORTMONKS_POSITION_GROUP_IDS = {24, 25, 26, 27}
# Sportmonks 73643은 2018/2019 Bordeaux 스쿼드에서 Toma Bašić(74062)와
# 중복되고 Josip Bašić의 생년월일이 섞여 있어요. Capology도 74062와 일치하므로
# 잘못된 프로필을 ID만 바꿔 저장하지 않고 73643 행을 제외해요.
SPORTMONKS_DUPLICATE_PLAYER_IDS = {73643: 74062}
SQL_SELECT_TEAM = """
SELECT team_id
FROM teams
WHERE team_id = %s
"""

SQL_SELECT_CURRENT_DOMESTIC_SEASON = """
SELECT team_seasons.season_id, seasons.name
FROM team_seasons
JOIN seasons
  ON seasons.season_id = team_seasons.season_id
JOIN competitions
  ON competitions.competition_id = seasons.competition_id
WHERE team_seasons.team_id = %s
  AND seasons.is_current = 1
  AND competitions.competition_type = 'league'
  AND competitions.competition_id IN (8,82,301,384,564)
ORDER BY team_seasons.season_id
"""

SQL_SELECT_SQUAD_SCOPE = """
SELECT
  seasons.competition_id,
  team_seasons.season_id,
  seasons.name,
  seasons.is_current,
  team_seasons.team_id,
  teams.name
FROM team_seasons
JOIN seasons
  ON seasons.season_id = team_seasons.season_id
JOIN teams
  ON teams.team_id = team_seasons.team_id
WHERE seasons.competition_id IN (8,82,301,384,564)
  AND CAST(LEFT(seasons.name, 4) AS UNSIGNED) >= %s
ORDER BY
  seasons.is_current,
  seasons.competition_id,
  team_seasons.season_id,
  team_seasons.team_id
"""

SQL_SELECT_LAST_TEAM_DOMESTIC_FIXTURE_DATE = f"""
SELECT DATE(MAX(f.starting_at))
FROM fixtures f
JOIN stages st ON st.stage_id = f.stage_id
JOIN seasons s ON s.season_id = st.season_id
WHERE s.competition_id = %s
  AND s.season_id = %s
  AND (f.home_team_id = %s OR f.away_team_id = %s)
  AND f.state_id IN ({COMPLETED_STATE_IDS_SQL})
  AND f.home_score IS NOT NULL
  AND f.away_score IS NOT NULL
"""

SQL_SELECT_TRACKED_TEAM_FIXTURE_IDS = f"""
SELECT f.fixture_id
FROM fixtures f
WHERE (f.home_team_id = %s OR f.away_team_id = %s)
  AND DATE(f.starting_at) BETWEEN %s AND %s
  AND f.state_id IN ({COMPLETED_STATE_IDS_SQL})
  AND f.home_score IS NOT NULL
  AND f.away_score IS NOT NULL
ORDER BY f.starting_at, f.fixture_id
"""

SQL_UPSERT_SQUAD_MEMBER = """
INSERT INTO team_squad_members (
  team_id,
  season_id,
  player_id,
  position_group_id,
  jersey_number
)
VALUES (%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  position_group_id = VALUES(position_group_id),
  jersey_number      = VALUES(jersey_number)
"""


def _require_dict(value, field_name: str) -> Dict:
    if not isinstance(value, dict):
        raise ValueError(f"Missing or invalid object: {field_name}={value!r}")
    return value


def _require_int(value, field_name: str) -> int:
    if type(value) is not int:
        raise ValueError(f"Missing or invalid integer: {field_name}={value!r}")
    return value


def _require_string(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string: {field_name}={value!r}")
    return value.strip()


def _optional_string(value, field_name: str) -> Optional[str]:
    if value is None:
        return None
    return _require_string(value, field_name)


def _optional_int(value, field_name: str) -> Optional[int]:
    if value is None:
        return None
    return _require_int(value, field_name)


def _require_date(value, field_name: str) -> date:
    if isinstance(value, datetime):
        return value.date()
    if type(value) is date:
        return value
    if isinstance(value, str):
        try:
            return date.fromisoformat(value[:10])
        except ValueError as exc:
            raise ValueError(f"Invalid date: {field_name}={value!r}") from exc
    raise ValueError(f"Missing or invalid date: {field_name}={value!r}")


def _season_start_date(season_name: str) -> date:
    match = re.fullmatch(r"(\d{4})/(\d{4})", season_name)
    if match is None:
        raise ValueError(f"Unsupported season name: {season_name!r}")

    start_year = int(match.group(1))
    end_year = int(match.group(2))
    if end_year != start_year + 1:
        raise ValueError(f"Unsupported season year range: {season_name!r}")

    return date(start_year, 7, 1)


def _normalize_squad_item(
    item,
    team_id: int,
    season_id: int,
    index: int,
) -> Tuple[Tuple, Tuple]:
    squad_item = _require_dict(item, f"squad[{index}]")
    player_id = _require_int(
        squad_item.get("player_id"),
        f"squad[{index}].player_id",
    )
    player = _require_dict(
        squad_item.get("player"),
        f"squad[{index}].player",
    )

    # Sportmonks는 현재 스쿼드와 시즌 스쿼드에서 상세 포지션 위치가 달라요.
    # 두 응답에 모두 값이 없더라도 선수를 스쿼드에서 빼지 않고 NULL로 둬요.
    sportmonks_detailed_position_id = squad_item.get("detailed_position_id")
    if sportmonks_detailed_position_id is None:
        sportmonks_detailed_position_id = player.get("detailed_position_id")
    position_id = _optional_int(
        sportmonks_detailed_position_id,
        f"squad[{index}].Sportmonks detailed_position_id",
    )

    # Sportmonks 시즌 스쿼드가 기본 포지션 자리에 스태프 ID를 섞어 준 사례가 있어요.
    # 이때만 내장 선수 프로필을 확인하고, 둘 다 유효하지 않으면 추정하지 않아요.
    position_group_id = _optional_int(
        squad_item.get("position_id"),
        f"squad[{index}].position_id",
    )
    if (
        position_group_id is not None
        and position_group_id not in SPORTMONKS_POSITION_GROUP_IDS
    ):
        embedded_position_group_id = _optional_int(
            player.get("position_id"),
            f"squad[{index}].player.position_id",
        )
        position_group_id = (
            embedded_position_group_id
            if embedded_position_group_id in SPORTMONKS_POSITION_GROUP_IDS
            else None
        )
    jersey_number = _optional_int(
        squad_item.get("jersey_number"),
        f"squad[{index}].jersey_number",
    )

    player_row = (
        player_id,
        _require_string(player.get("display_name"), "player.display_name"),
        _require_string(player.get("name"), "player.name"),
        position_id,
        _optional_int(player.get("nationality_id"), "player.nationality_id"),
        _optional_string(player.get("date_of_birth"), "player.date_of_birth"),
        _optional_int(player.get("height"), "player.height"),
        _optional_int(player.get("weight"), "player.weight"),
        _optional_string(player.get("image_path"), "player.image_path"),
    )
    member_row = (
        team_id,
        season_id,
        player_id,
        position_group_id,
        jersey_number,
    )
    return player_row, member_row


def _squad_player_ids(squad: List[Dict]) -> Set[int]:
    player_ids: Set[int] = set()
    for index, item in enumerate(squad):
        squad_item = _require_dict(item, f"squad[{index}]")
        player_id = _require_int(
            squad_item.get("player_id"),
            f"squad[{index}].player_id",
        )
        player_ids.add(player_id)
    return player_ids


def _exclude_sportmonks_duplicate_players(
    squad: List[Dict],
) -> Tuple[List[Dict], Dict[int, int]]:
    filtered: List[Dict] = []
    excluded: Dict[int, int] = {}

    for index, item in enumerate(squad):
        squad_item = _require_dict(item, f"squad[{index}]")
        player_id = _require_int(
            squad_item.get("player_id"),
            f"squad[{index}].player_id",
        )
        canonical_player_id = SPORTMONKS_DUPLICATE_PLAYER_IDS.get(player_id)
        if canonical_player_id is not None:
            excluded[player_id] = canonical_player_id
            continue
        filtered.append(item)

    return filtered, excluded


def _completed_team_movements(
    transfers: Iterable[Dict],
    team_id: int,
    base_player_ids: Set[int],
) -> DefaultDict[int, List[Tuple[date, int, str]]]:
    movements: DefaultDict[int, List[Tuple[date, int, str]]] = defaultdict(list)

    for index, transfer in enumerate(transfers):
        transfer = _require_dict(transfer, f"transfers[{index}]")
        if transfer.get("completed") is not True:
            continue

        player_id = transfer.get("player_id")
        if player_id not in base_player_ids:
            # 공급자 스쿼드에 없는 선수는 이적 기록만으로 추가하지 않아요.
            continue

        from_team_id = transfer.get("from_team_id")
        to_team_id = transfer.get("to_team_id")
        if from_team_id == team_id and to_team_id != team_id:
            direction = "out"
        elif to_team_id == team_id and from_team_id != team_id:
            direction = "in"
        else:
            continue

        if transfer.get("date") is None:
            # 날짜가 없으면 시즌 범위와 이동 순서를 판단할 수 없어 이적 행만 제외해요.
            continue

        transfer_id = _require_int(transfer.get("id"), f"transfers[{index}].id")
        transfer_date = _require_date(
            transfer.get("date"),
            f"transfers[{index}].date",
        )
        movements[player_id].append((transfer_date, transfer_id, direction))

    for player_movements in movements.values():
        player_movements.sort(key=lambda value: (value[0], value[1]))

    return movements


def _filter_current_squad_items(
    squad: List[Dict],
    transfers: Iterable[Dict],
    team_id: int,
    season_start: date,
    today: date,
) -> Tuple[List[Dict], Set[int]]:
    """현재 시즌의 Sportmonks 스쿼드와 이적 기록을 맞춰요.

    공급자의 현재 스쿼드를 기준으로 삼아요. season_start부터 오늘까지 이미 효력이 생긴
    완료 이적만 반영해요. 기준 명단 선수의 마지막 이동이 OUT이면 빼요. IN 기록만으로
    공급자 스쿼드에 없는 선수를 추가하지 않아요. 미래 날짜의 이적은 무시해요.
    """
    base_player_ids = _squad_player_ids(squad)
    movements = _completed_team_movements(transfers, team_id, base_player_ids)
    removed_player_ids: Set[int] = set()

    for player_id, player_movements in movements.items():
        effective = [
            movement
            for movement in player_movements
            if season_start <= movement[0] <= today
        ]
        if effective and effective[-1][2] == "out":
            removed_player_ids.add(player_id)

    return (
        [item for item in squad if item["player_id"] not in removed_player_ids],
        removed_player_ids,
    )


def _filter_historical_squad_items(
    squad: List[Dict],
    transfers: Iterable[Dict],
    team_id: int,
    season_start: date,
    cutoff: date,
    lineup_dates_by_player: Dict[int, Set[date]],
) -> Tuple[List[Dict], Dict[int, str]]:
    """완료된 시즌의 스쿼드를 재구성해요.

    이 프로젝트에서 확인한 규칙이에요.
    1. Sportmonks 팀 시즌 스쿼드에서만 시작해요. 이적 기록만으로 공급자 명단에 없는
       선수를 추가하지 않아요.
    2. 팀이 마지막으로 치른 자국 리그 경기를 기준일로 써요.
    3. 첫 IN 기록이 기준일 뒤인 공급자 스쿼드 행은 다음 시즌 데이터가 섞인 것으로 봐요.
       단, 해당 시즌 성인 1군 경기에서 선발이나 벤치 기록이 있으면 남겨요.
    4. 기준일 이전에 OUT이 있는 기준 명단 선수는 마지막 OUT을 찾아요. 그 OUT 뒤부터
       기준일까지 성인 1군 경기의 선발이나 벤치 기록이 있을 때만 남겨요.
       Sportmonks의 복귀일은 이 용도에서 신뢰할 수 없음을 확인했으므로,
       복귀 이적 행 하나만으로는 선수를 남기지 않아요.
    """
    base_player_ids = _squad_player_ids(squad)
    movements = _completed_team_movements(transfers, team_id, base_player_ids)
    removed: Dict[int, str] = {}

    for player_id in base_player_ids:
        player_movements = movements.get(player_id, [])
        lineup_dates = {
            lineup_date
            for lineup_date in lineup_dates_by_player.get(player_id, set())
            if season_start <= lineup_date <= cutoff
        }

        inbound_dates = [
            movement_date
            for movement_date, _, direction in player_movements
            if direction == "in"
        ]
        if inbound_dates and min(inbound_dates) > cutoff and not lineup_dates:
            removed[player_id] = "first_recorded_in_after_cutoff"
            continue

        outbound_dates = [
            movement_date
            for movement_date, _, direction in player_movements
            if direction == "out" and movement_date <= cutoff
        ]
        if not outbound_dates:
            continue

        last_outbound = max(outbound_dates)
        if not any(lineup_date > last_outbound for lineup_date in lineup_dates):
            removed[player_id] = "no_first_team_lineup_after_last_out"

    return (
        [item for item in squad if item["player_id"] not in removed],
        removed,
    )


def _historical_players_requiring_lineup_evidence(
    squad: List[Dict],
    transfers: Iterable[Dict],
    team_id: int,
    cutoff: date,
) -> Dict[int, date]:
    base_player_ids = _squad_player_ids(squad)
    movements = _completed_team_movements(transfers, team_id, base_player_ids)
    required_from: Dict[int, date] = {}

    for player_id, player_movements in movements.items():
        inbound_dates = [
            movement_date
            for movement_date, _, direction in player_movements
            if direction == "in"
        ]
        if inbound_dates and min(inbound_dates) > cutoff:
            required_from[player_id] = date.min

        outbound_dates = [
            movement_date
            for movement_date, _, direction in player_movements
            if direction == "out" and movement_date <= cutoff
        ]
        if outbound_dates:
            last_outbound = max(outbound_dates)
            required_from[player_id] = min(
                required_from.get(player_id, last_outbound),
                last_outbound,
            )

    return required_from


def _load_lineup_dates_by_player(
    sm: SportmonksClient,
    team_id: int,
    start_date: date,
    end_date: date,
) -> Dict[int, Set[date]]:
    tracked_rows = fetch_all(
        SQL_SELECT_TRACKED_TEAM_FIXTURE_IDS,
        (team_id, team_id, start_date, end_date),
    )
    tracked_fixture_ids = {int(row[0]) for row in tracked_rows}
    if not tracked_fixture_ids:
        return {}

    returned_tracked_ids: Set[int] = set()
    missing_lineup_fixture_ids: Set[int] = set()
    lineup_dates_by_player: DefaultDict[int, Set[date]] = defaultdict(set)

    for fixture in sm.iter_team_fixtures_between_dates(
        team_id=team_id,
        start_date=start_date,
        end_date=end_date,
        include="lineups",
    ):
        fixture_id = _require_int(fixture.get("id"), "fixture.id")
        if fixture_id not in tracked_fixture_ids:
            # 이미 적재한 성인 대회 경기만 1군 출전 근거로 봐요.
            continue

        returned_tracked_ids.add(fixture_id)
        fixture_date = _require_date(fixture.get("starting_at"), "fixture.starting_at")
        lineups = fixture.get("lineups")
        if not isinstance(lineups, list):
            raise ValueError(
                f"fixture_id={fixture_id} missing included lineups list: {lineups!r}"
            )
        if not lineups:
            missing_lineup_fixture_ids.add(fixture_id)
            continue

        for lineup_index, lineup in enumerate(lineups):
            lineup = _require_dict(
                lineup,
                f"fixture[{fixture_id}].lineups[{lineup_index}]",
            )
            if lineup.get("team_id") != team_id:
                continue
            if lineup.get("type_id") not in SPORTMONKS_MATCHDAY_LINEUP_TYPE_IDS:
                continue
            player_id = lineup.get("player_id")
            if type(player_id) is int:
                lineup_dates_by_player[player_id].add(fixture_date)

    missing_fixture_ids = tracked_fixture_ids - returned_tracked_ids
    if missing_fixture_ids:
        raise ValueError(
            "Sportmonks fixture range omitted tracked fixtures: "
            f"team_id={team_id}, fixture_ids={sorted(missing_fixture_ids)}"
        )
    if missing_lineup_fixture_ids:
        raise ValueError(
            "Played tracked fixtures have no Sportmonks lineup coverage: "
            f"team_id={team_id}, fixture_ids={sorted(missing_lineup_fixture_ids)}"
        )

    return dict(lineup_dates_by_player)


def _resolve_historical_cutoff(
    competition_id: int,
    season_id: int,
    team_id: int,
) -> date:
    rows = fetch_all(
        SQL_SELECT_LAST_TEAM_DOMESTIC_FIXTURE_DATE,
        (competition_id, season_id, team_id, team_id),
    )
    value = rows[0][0] if rows else None
    if value is None:
        raise ValueError(
            "No played domestic-league cutoff fixture: "
            f"competition_id={competition_id}, season_id={season_id}, "
            f"team_id={team_id}"
        )
    return _require_date(value, "last domestic fixture date")


def _resolve_current_domestic_season(team_id: int) -> Tuple[int, str]:
    rows = fetch_all(SQL_SELECT_CURRENT_DOMESTIC_SEASON, (team_id,))
    if len(rows) != 1:
        raise ValueError(
            "Expected exactly one current domestic-league season for "
            f"team_id={team_id}, found {len(rows)}: {rows!r}"
        )
    return int(rows[0][0]), str(rows[0][1])


def _replace_squad_snapshot(
    team_id: int,
    season_id: int,
    squad: List[Dict],
) -> Dict[str, int]:
    member_rows: List[Tuple] = []

    for index, item in enumerate(squad):
        _, member_row = _normalize_squad_item(
            item,
            team_id,
            season_id,
            index,
        )
        member_rows.append(member_row)

    player_ids = {int(row[2]) for row in member_rows}
    if player_ids:
        placeholders = ",".join(["%s"] * len(player_ids))
        existing_player_ids = {
            int(row[0])
            for row in fetch_all(
                f"SELECT player_id FROM players WHERE player_id IN ({placeholders})",
                tuple(sorted(player_ids)),
            )
        }
        missing_player_ids = sorted(player_ids - existing_player_ids)
        if missing_player_ids:
            raise ValueError(
                "Load players before squad members: "
                f"team_id={team_id}, season_id={season_id}, "
                f"missing_player_ids={missing_player_ids}"
            )

    with transaction() as connection:
        with connection.cursor() as cursor:
            if member_rows:
                cursor.executemany(SQL_UPSERT_SQUAD_MEMBER, member_rows)

            if member_rows:
                placeholders = ",".join(["%s"] * len(member_rows))
                cursor.execute(
                    f"""
                    DELETE FROM team_squad_members
                    WHERE team_id = %s
                      AND season_id = %s
                      AND player_id NOT IN ({placeholders})
                    """,
                    (team_id, season_id, *(row[2] for row in member_rows)),
                )
            else:
                cursor.execute(
                    """
                    DELETE FROM team_squad_members
                    WHERE team_id = %s
                      AND season_id = %s
                    """,
                    (team_id, season_id),
                )
            deleted_stale = cursor.rowcount

    return {
        "squad_members": len(member_rows),
        "deleted_stale": deleted_stale,
    }


def _reconstruct_current_team_season_squad(
    sm: SportmonksClient,
    team_id: int,
    season_id: int,
    season_name: str,
    transfers: List[Dict],
    today: date,
) -> Tuple[List[Dict], Dict[str, object]]:
    raw_squad = sm.get_team_squad(team_id)
    if not raw_squad:
        raise ValueError(f"Sportmonks returned an empty current squad: team_id={team_id}")

    filtered_squad, removed_player_ids = _filter_current_squad_items(
        raw_squad,
        transfers,
        team_id,
        _season_start_date(season_name),
        today,
    )
    filtered_squad, excluded_duplicate_player_ids = (
        _exclude_sportmonks_duplicate_players(filtered_squad)
    )
    return filtered_squad, {
        "team_id": team_id,
        "season_id": season_id,
        "season_name": season_name,
        "mode": "current",
        "raw_squad_members": len(raw_squad),
        "reconstructed_squad_members": len(filtered_squad),
        "removed_by_latest_out": len(removed_player_ids),
        "removed_player_ids": sorted(removed_player_ids),
        "excluded_duplicate_player_ids": excluded_duplicate_player_ids,
    }


def _reconstruct_historical_team_season_squad(
    sm: SportmonksClient,
    competition_id: int,
    team_id: int,
    season_id: int,
    season_name: str,
    transfers: List[Dict],
) -> Tuple[List[Dict], Dict[str, object]]:
    raw_squad = sm.get_team_season_squad(team_id, season_id)
    if not raw_squad:
        raise ValueError(
            "Sportmonks returned an empty historical squad: "
            f"team_id={team_id}, season_id={season_id}"
        )

    season_start = _season_start_date(season_name)
    cutoff = _resolve_historical_cutoff(competition_id, season_id, team_id)
    required_from = _historical_players_requiring_lineup_evidence(
        raw_squad,
        transfers,
        team_id,
        cutoff,
    )

    if required_from:
        evidence_start = min(
            season_start
            if required_date == date.min
            else max(season_start, required_date + timedelta(days=1))
            for required_date in required_from.values()
        )
        if evidence_start <= cutoff:
            lineup_dates_by_player = _load_lineup_dates_by_player(
                sm,
                team_id,
                evidence_start,
                cutoff,
            )
        else:
            lineup_dates_by_player = {}
    else:
        lineup_dates_by_player = {}

    filtered_squad, removed = _filter_historical_squad_items(
        raw_squad,
        transfers,
        team_id,
        season_start,
        cutoff,
        lineup_dates_by_player,
    )
    filtered_squad, excluded_duplicate_player_ids = (
        _exclude_sportmonks_duplicate_players(filtered_squad)
    )
    removed_reasons: DefaultDict[str, int] = defaultdict(int)
    for reason in removed.values():
        removed_reasons[reason] += 1

    return filtered_squad, {
        "team_id": team_id,
        "season_id": season_id,
        "season_name": season_name,
        "mode": "historical",
        "cutoff": cutoff.isoformat(),
        "raw_squad_members": len(raw_squad),
        "reconstructed_squad_members": len(filtered_squad),
        "removed_player_ids": sorted(removed),
        "removed_reasons": dict(sorted(removed_reasons.items())),
        "excluded_duplicate_player_ids": excluded_duplicate_player_ids,
    }


def reconstruct_team_season_squad(
    sm: SportmonksClient,
    item: Dict[str, object],
    transfers: List[Dict],
    today: date,
) -> Tuple[List[Dict], Dict[str, object]]:
    if bool(item["is_current"]):
        return _reconstruct_current_team_season_squad(
            sm,
            int(item["team_id"]),
            int(item["season_id"]),
            str(item["season_name"]),
            transfers,
            today,
        )
    return _reconstruct_historical_team_season_squad(
        sm,
        int(item["competition_id"]),
        int(item["team_id"]),
        int(item["season_id"]),
        str(item["season_name"]),
        transfers,
    )


def refresh_team_squad(team_id: int) -> Dict[str, object]:
    if type(team_id) is not int:
        raise ValueError(f"team_id must be an integer: {team_id!r}")
    if not fetch_all(SQL_SELECT_TEAM, (team_id,)):
        raise ValueError(f"teams table does not contain team_id={team_id}")

    season_id, season_name = _resolve_current_domestic_season(team_id)
    sm = SportmonksClient()
    transfers = list(sm.iter_transfers_by_team(team_id))
    reconstructed_squad, result = _reconstruct_current_team_season_squad(
        sm,
        team_id,
        season_id,
        season_name,
        transfers,
        date.today(),
    )
    result.update(
        _replace_squad_snapshot(team_id, season_id, reconstructed_squad)
    )
    print(
        f"[squads] team {team_id} season {season_id}: "
        f"raw={result['raw_squad_members']} "
        f"members={result['squad_members']} "
        f"removed_out={result['removed_by_latest_out']} "
        f"deleted_stale={result['deleted_stale']}"
    )
    return result


def load_squad_scope(
    season_name: Optional[str] = None,
    competition_id: Optional[int] = None,
    current_only: bool = False,
    team_ids: Optional[List[int]] = None,
) -> List[Dict[str, object]]:
    if (season_name is None) != (competition_id is None):
        raise ValueError(
            "season_name and competition_id must be provided together"
        )
    if season_name is not None:
        season_name = _require_string(season_name, "season_name")
        season_start = _season_start_date(season_name)
        if season_start.year < MIN_SEASON_START_YEAR:
            raise ValueError(
                f"Season {season_name!r} is before the supported minimum 2017/2018"
            )
        if competition_id not in BIG5_COMPETITION_IDS:
            raise ValueError(
                f"Unsupported Big 5 competition_id={competition_id}. "
                f"Allowed ids: {list(BIG5_COMPETITION_IDS)}"
            )

    rows = fetch_all(SQL_SELECT_SQUAD_SCOPE, (MIN_SEASON_START_YEAR,))
    scope = [
        {
            "competition_id": int(row[0]),
            "season_id": int(row[1]),
            "season_name": str(row[2]),
            "is_current": bool(row[3]),
            "team_id": int(row[4]),
            "team_name": str(row[5]),
        }
        for row in rows
        if (not current_only or bool(row[3]))
        and (
            season_name is None
            or (str(row[2]) == season_name and int(row[0]) == competition_id)
        )
    ]
    if team_ids is not None:
        # 이적·계약 갱신의 팀 선택도 기존 Big 5 스쿼드 범위를 공유해요.
        requested = set(team_ids)
        unknown = requested - {row["team_id"] for row in scope}
        if unknown:
            raise ValueError(f"Teams outside the selected squad scope: {sorted(unknown)}")
        scope = [row for row in scope if row["team_id"] in requested]
    if not scope:
        if season_name is not None:
            raise ValueError(
                "No Big 5 team seasons found for "
                f"season_name={season_name!r}, competition_id={competition_id}"
            )
        label = "current " if current_only else ""
        raise ValueError(
            f"No {label}Big 5 team seasons found from 2017/2018 onward"
        )
    return scope


def _refresh_scope(
    current_only: bool,
    season_name: Optional[str] = None,
    competition_id: Optional[int] = None,
) -> Dict[str, object]:
    scope = load_squad_scope(
        season_name=season_name,
        competition_id=competition_id,
        current_only=current_only,
    )
    sm = SportmonksClient()
    today = date.today()
    transfers_by_team: Dict[int, List[Dict]] = {}
    completed: List[Dict[str, object]] = []
    failures: List[Dict[str, object]] = []

    for index, item in enumerate(scope, start=1):
        team_id = int(item["team_id"])
        try:
            if team_id not in transfers_by_team:
                transfers_by_team[team_id] = list(sm.iter_transfers_by_team(team_id))
            transfers = transfers_by_team[team_id]

            reconstructed_squad, result = reconstruct_team_season_squad(
                sm,
                item,
                transfers,
                today,
            )
            result.update(
                _replace_squad_snapshot(
                    team_id,
                    int(item["season_id"]),
                    reconstructed_squad,
                )
            )

            completed.append(result)
            # PowerShell CP949 로그가 유니코드 팀명 때문에 중단되지 않도록 ID만 표시해요.
            print(
                f"[squads {index}/{len(scope)}] "
                f"{item['season_name']} team_id={team_id}: "
                f"mode={result['mode']} raw={result['raw_squad_members']} "
                f"stored={result['squad_members']}"
            )
        except ValueError as exc:
            failure = {
                **item,
                "error_type": type(exc).__name__,
                "error": str(exc),
            }
            failures.append(failure)
            print(
                f"[squads {index}/{len(scope)}] "
                f"{item['season_name']} team_id={team_id}: "
                f"ERROR {type(exc).__name__}: {exc}"
            )

    summary: Dict[str, object] = {
        "requested_team_seasons": len(scope),
        "loaded_team_seasons": len(completed),
        "failed_team_seasons": len(failures),
        "stored_squad_members": sum(
            int(result["squad_members"]) for result in completed
        ),
        "failures": failures,
    }
    print(
        "[squads] completed "
        f"loaded={summary['loaded_team_seasons']}/"
        f"{summary['requested_team_seasons']} "
        f"failed={summary['failed_team_seasons']} "
        f"members={summary['stored_squad_members']}"
    )

    if failures:
        samples = "; ".join(
            f"{failure['season_name']} team={failure['team_id']}: "
            f"{failure['error_type']}"
            for failure in failures[:10]
        )
        raise RuntimeError(
            "Squad load completed with failures; failed targets were not modified. "
            f"failed={len(failures)} samples={samples}"
        )

    return summary


def collect_all_squads() -> Dict[str, object]:
    """2017/2018 이후 5대 리그의 복원된 스쿼드 관계를 모두 저장해요."""
    return _refresh_scope(current_only=False)


def collect_squads_for_competition_season(
    season_name: str,
    competition_id: int,
) -> Dict[str, object]:
    """선택한 5대 리그·시즌의 복원된 스쿼드 관계를 저장해요."""
    return _refresh_scope(
        current_only=False,
        season_name=season_name,
        competition_id=competition_id,
    )


def refresh_current_squads() -> Dict[str, object]:
    """현재 이적 내역을 맞춰 모든 Big 5 현재 스쿼드를 갱신해요."""
    return _refresh_scope(current_only=True)
