"""확인한 경기 이벤트·통계·라인업·포메이션·감독·pressure를 저장해요."""

from __future__ import annotations

from typing import Dict, List, Optional, Tuple

from ..core.db import fetch_all, transaction
from ..core.sportmonks import SportmonksClient
from .players_loader import insert_missing_player_profiles
from .team_squad_members_loader import SPORTMONKS_DUPLICATE_PLAYER_IDS


SPORTMONKS_RATING_TYPE_ID = 118
SPORTMONKS_MINUTES_PLAYED_TYPE_ID = 119

SQL_SELECT_ALL_FIXTURES = """
SELECT f.fixture_id
FROM fixtures f
JOIN stages st ON st.stage_id = f.stage_id
JOIN seasons s ON s.season_id = st.season_id
ORDER BY s.name, s.competition_id, f.starting_at, f.fixture_id
"""

SQL_SELECT_SCOPED_FIXTURES = """
SELECT f.fixture_id
FROM fixtures f
JOIN stages st ON st.stage_id = f.stage_id
JOIN seasons s ON s.season_id = st.season_id
WHERE s.name = %s
  AND s.competition_id IN ({placeholders})
ORDER BY s.competition_id, f.starting_at, f.fixture_id
"""

SQL_UPSERT_EVENT_TYPE = """
INSERT INTO fixture_event_types (event_type_id, code, name)
VALUES (%s,%s,%s)
ON DUPLICATE KEY UPDATE code = VALUES(code), name = VALUES(name)
"""

SQL_INSERT_EVENT = """
INSERT INTO fixture_events (
  event_id, fixture_id, team_id, event_type_id, player_id,
  related_player_id, minute, extra_minute, on_bench
)
VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
"""

SQL_UPSERT_STAT_TYPE = """
INSERT INTO fixture_stat_types (stat_type_id, code, name)
VALUES (%s,%s,%s)
ON DUPLICATE KEY UPDATE code = VALUES(code), name = VALUES(name)
"""

SQL_INSERT_TEAM_STAT = """
INSERT INTO fixture_team_stats (fixture_id, team_id, stat_type_id, stat_value)
VALUES (%s,%s,%s,%s)
"""

SQL_INSERT_LINEUP = """
INSERT INTO fixture_lineups (
  fixture_id, team_id, player_id, lineup_type_id,
  formation_field, jersey_number, minutes_played, rating
)
VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
"""

SQL_INSERT_FORMATION = """
INSERT INTO fixture_formations (fixture_id, team_id, formation)
VALUES (%s,%s,%s)
"""

SQL_UPSERT_COACH = """
INSERT INTO coaches (coach_id, name)
VALUES (%s,%s)
ON DUPLICATE KEY UPDATE name = VALUES(name)
"""

SQL_INSERT_FIXTURE_COACH = """
INSERT INTO fixture_coaches (fixture_id, team_id, coach_id)
VALUES (%s,%s,%s)
"""

SQL_INSERT_PRESSURE = """
INSERT INTO fixture_pressures (fixture_id, team_id, minute, pressure)
VALUES (%s,%s,%s,%s)
"""


def _canonical_player_id(player_id: Optional[int]) -> Optional[int]:
    # 73643은 다른 프로필이 섞인 중복 ID라 검증된 선수 74062로 연결해요.
    return SPORTMONKS_DUPLICATE_PLAYER_IDS.get(player_id, player_id)


def normalize_fixture_statistics(payload: Dict, fixture_id: int) -> Dict[str, List[Tuple]]:
    stat_types = {}
    team_stats = []
    for stat in payload["statistics"]:
        type_id = stat["type_id"]
        stat_types[type_id] = (type_id, stat["type"]["code"], stat["type"]["name"])
        value = stat["data"]["value"]
        # 16924696의 Southampton 점유율은 null이에요. 값이 없는 통계는 저장하지 않아요.
        # 실제 0과 구분하고, 상대 팀 수치로 값을 추정하지 않아요.
        if value is not None:
            team_stats.append((fixture_id, stat["participant_id"], type_id, value))
    return {"stat_types": list(stat_types.values()), "team_stats": team_stats}


def normalize_fixture_lineups(payload: Dict, fixture_id: int) -> Dict[str, List[Tuple]]:
    lineups = []
    for lineup in payload["lineups"]:
        # 기존 라인업 수집에서도 선수를 특정할 수 없는 슬롯은 저장하지 않았어요.
        if lineup["player_id"] is None:
            continue
        details = {
            detail["type_id"]: detail["data"]["value"]
            for detail in lineup["details"]
            if detail["type_id"] in {SPORTMONKS_MINUTES_PLAYED_TYPE_ID, SPORTMONKS_RATING_TYPE_ID}
        }
        lineups.append(
            (
                fixture_id,
                lineup["team_id"],
                _canonical_player_id(lineup["player_id"]),
                lineup["type_id"],
                lineup["formation_field"],
                lineup["jersey_number"],
                # 예정 경기 19722180의 선발 22명은 출전 시간·평점이 없어요.
                details.get(SPORTMONKS_MINUTES_PLAYED_TYPE_ID),
                details.get(SPORTMONKS_RATING_TYPE_ID),
            )
        )
    formations = [
        (fixture_id, formation["participant_id"], formation["formation"])
        for formation in payload["formations"]
        if formation["participant_id"] is not None and formation["formation"]
    ]
    return {"lineups": lineups, "formations": formations}


def _normalize_fixture_details(payload: Dict, fixture_id: int) -> Dict[str, List[Tuple]]:
    event_types = {}
    events = []
    for event in payload["events"]:
        type_id = event["type_id"]
        event_types[type_id] = (type_id, event["type"]["code"], event["type"]["name"])
        events.append(
            (
                event["id"], fixture_id, event["participant_id"], type_id,
                _canonical_player_id(event["player_id"]),
                _canonical_player_id(event["related_player_id"]),
                event["minute"], event["extra_minute"], event["on_bench"],
            )
        )
    return {
        "event_types": list(event_types.values()),
        "events": events,
        **normalize_fixture_statistics(payload, fixture_id),
        **normalize_fixture_lineups(payload, fixture_id),
        "coaches": [(coach["id"], coach["display_name"]) for coach in payload["coaches"]],
        "fixture_coaches": [
            (fixture_id, coach["meta"]["participant_id"], coach["id"])
            for coach in payload["coaches"]
        ],
        "pressures": [
            (fixture_id, pressure["participant_id"], pressure["minute"], pressure["pressure"])
            for pressure in payload["pressure"]
        ],
    }


def replace_fixture_detail_rows(
    fixture_id: int,
    rows: Dict[str, List[Tuple]],
    lineups: Optional[List[Dict]] = None,
    verified_event_profiles: Optional[Dict[int, Dict]] = None,
) -> int:
    added_players = 0
    with transaction() as connection:
        with connection.cursor() as cursor:
            profiles = dict(verified_event_profiles or {})
            if lineups is not None:
                # 선수 FK와 경기 상세가 함께 성공하거나 함께 취소돼야 해요.
                profiles.update({
                    lineup["player_id"]: lineup["player"]
                    for lineup in lineups
                    if lineup["player_id"] is not None
                    and lineup["player_id"] not in SPORTMONKS_DUPLICATE_PLAYER_IDS
                })
            # 라인업 누락을 확인한 이벤트 선수도 같은 삽입 함수를 써 기존 프로필을 보존해요.
            # 프로필만 보충하며 라인업·출전 시간·스쿼드 행은 만들지 않아요.
            added_players = insert_missing_player_profiles(cursor, profiles)
            for key, statement in (
                ("event_types", SQL_UPSERT_EVENT_TYPE),
                ("stat_types", SQL_UPSERT_STAT_TYPE),
                ("coaches", SQL_UPSERT_COACH),
            ):
                if rows.get(key):
                    cursor.executemany(statement, rows[key])

            # 통계 전용·라인업 전용 명령은 요청한 묶음만 바꿔요.
            # 빈 응답도 교체해야 공급자가 삭제한 기존 행이 남지 않아요.
            for key, table, statement in (
                ("events", "fixture_events", SQL_INSERT_EVENT),
                ("team_stats", "fixture_team_stats", SQL_INSERT_TEAM_STAT),
                ("lineups", "fixture_lineups", SQL_INSERT_LINEUP),
                ("formations", "fixture_formations", SQL_INSERT_FORMATION),
                ("fixture_coaches", "fixture_coaches", SQL_INSERT_FIXTURE_COACH),
                ("pressures", "fixture_pressures", SQL_INSERT_PRESSURE),
            ):
                if key in rows:
                    cursor.execute(f"DELETE FROM {table} WHERE fixture_id = %s", (fixture_id,))
                    if rows[key]:
                        cursor.executemany(statement, rows[key])
    return added_players


def _load_scope(
    season_name: Optional[str] = None,
    competition_ids: Optional[List[int]] = None,
    fixture_id: Optional[int] = None,
) -> List[int]:
    if fixture_id is not None:
        rows = fetch_all("SELECT fixture_id FROM fixtures WHERE fixture_id = %s", (fixture_id,))
    elif season_name is None and competition_ids is None:
        rows = fetch_all(SQL_SELECT_ALL_FIXTURES)
    elif season_name is not None and competition_ids:
        placeholders = ",".join("%s" for _ in competition_ids)
        rows = fetch_all(
            SQL_SELECT_SCOPED_FIXTURES.format(placeholders=placeholders),
            (season_name, *competition_ids),
        )
    else:
        raise ValueError("season_name and at least one competition_id must be provided together")
    if not rows:
        raise ValueError("No fixtures found for fixture-details scope")
    return [row[0] for row in rows]


def _collect_fixture_details(
    season_name: Optional[str] = None,
    competition_ids: Optional[List[int]] = None,
    fixture_id: Optional[int] = None,
) -> Dict[str, int]:
    scope = _load_scope(season_name, competition_ids, fixture_id)
    client = SportmonksClient()
    totals = dict.fromkeys(
        ("fixtures", "events", "team_stats", "lineups", "formations", "fixture_coaches", "pressures", "players"),
        0,
    )
    for index, fixture_id in enumerate(scope, start=1):
        payload = client.get_fixture_details(fixture_id)
        rows = _normalize_fixture_details(payload, fixture_id)
        event_profiles = {
            event["verified_player_profile"]["id"]: event["verified_player_profile"]
            for event in payload["events"]
            if "verified_player_profile" in event
        }
        totals["players"] += replace_fixture_detail_rows(
            fixture_id, rows, payload["lineups"], event_profiles,
        )
        totals["fixtures"] += 1
        for key in totals:
            if key not in {"fixtures", "players"}:
                totals[key] += len(rows[key])
        # 터미널 로그를 읽는 모니터에 저장 완료 건수를 바로 전달해요.
        print(
            f"[fixture-details {index}/{len(scope)}] fixture_id={fixture_id} "
            f"events={len(rows['events'])} stats={len(rows['team_stats'])} "
            f"lineups={len(rows['lineups'])} pressure={len(rows['pressures'])}",
            flush=True,
        )
    return totals


def collect_all_fixture_details() -> Dict[str, int]:
    return _collect_fixture_details()


def collect_fixture_details(fixture_id: int) -> Dict[str, int]:
    return _collect_fixture_details(fixture_id=fixture_id)


def collect_fixture_details_for_competition_season(
    season_name: str,
    competition_ids: List[int],
) -> Dict[str, int]:
    return _collect_fixture_details(season_name, competition_ids)
