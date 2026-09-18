"""저장된 경기의 점수·이벤트·통계·경기 시계를 같은 응답으로 갱신해요."""
from __future__ import annotations

from datetime import datetime, timezone

from ..core.db import fetch_all, transaction
from ..core.fixture_states import LIVE_STATE_IDS
from ..core.sportmonks import SportmonksClient
from .fixture_details_loader import _normalize_fixture_details, write_fixture_detail_rows
from . import player_rating_rankings_loader as player_rankings
from .fixtures_loader import (
    SPORTMONKS_CURRENT_SCORE_TYPE_ID, SPORTMONKS_PENALTY_SCORE_TYPE_ID,
    SQL_UPSERT_FIXTURE_STATE, _score_pair,
)


SQL_UPDATE_LIVE_FIXTURE = """
UPDATE fixtures SET state_id=%s, home_score=%s, away_score=%s,
  home_penalty_score=%s, away_penalty_score=%s WHERE fixture_id=%s
"""
SQL_UPSERT_CLOCK = """
INSERT INTO fixture_clock (
  fixture_id, period_type_id, counts_from, period_length, minutes, seconds,
  ticking, time_added, sampled_at
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  period_type_id=VALUES(period_type_id), counts_from=VALUES(counts_from),
  period_length=VALUES(period_length), minutes=VALUES(minutes), seconds=VALUES(seconds),
  ticking=VALUES(ticking), time_added=VALUES(time_added), sampled_at=VALUES(sampled_at)
"""


def normalize_clock(fixture: dict, sampled_at: datetime) -> tuple:
    periods = fixture["periods"]
    # HT·종료에는 ticking 기간이 없어요. 직전 기간을 남기고 시계는 멈춰요.
    period = max(periods, key=lambda p: (p["ticking"], p["sort_order"]), default={})
    return (
        fixture["id"], period.get("type_id"), period.get("counts_from"),
        period.get("period_length"), period.get("minutes"), period.get("seconds"),
        bool(period.get("ticking", False)), period.get("time_added"), sampled_at,
    )


def validate_fixture_participants(fixture: dict, home_team_id: int, away_team_id: int) -> None:
    # ID는 기존 fixtures가 기준이에요. 같은 이름의 다른 팀으로 추정하지 않아요.
    participants = {p["meta"]["location"]: p["id"] for p in fixture["participants"]}
    if participants != {"home": home_team_id, "away": away_team_id}:
        raise ValueError(f"Fixture participants differ: {fixture['id']}")


def store_live_fixture(fixture: dict, home_team_id: int, away_team_id: int,
                       sampled_at: datetime) -> None:
    validate_fixture_participants(fixture, home_team_id, away_team_id)
    current = _score_pair(fixture, home_team_id, away_team_id, SPORTMONKS_CURRENT_SCORE_TYPE_ID)
    penalties = _score_pair(fixture, home_team_id, away_team_id, SPORTMONKS_PENALTY_SCORE_TYPE_ID)
    rows = _normalize_fixture_details(fixture, fixture["id"])
    profiles = {
        e["verified_player_profile"]["id"]: e["verified_player_profile"]
        for e in fixture["events"] if "verified_player_profile" in e
    }
    with transaction() as connection:
        with player_rankings.refresh_player_ratings_after_fixture(
            connection, fixture["id"], state_id=fixture["state_id"],
        ):
            with connection.cursor() as cursor:
                state = fixture["state"]
                cursor.executemany(SQL_UPSERT_FIXTURE_STATE, [(state["id"], state["state"], state["name"])])
                write_fixture_detail_rows(cursor, fixture["id"], rows, fixture["lineups"], profiles)
                cursor.execute(SQL_UPDATE_LIVE_FIXTURE, (fixture["state_id"], *current, *penalties, fixture["id"]))
                cursor.execute(SQL_UPSERT_CLOCK, normalize_clock(fixture, sampled_at))


def refresh_live_fixtures(*, apply: bool = False) -> dict:
    client = SportmonksClient(timeout=20)
    fixtures = client.get_livescores()
    sampled_at = datetime.now(timezone.utc).replace(tzinfo=None)
    by_id = {f["id"]: (f, sampled_at) for f in fixtures}
    # 라이브 목록에서 사라진 경기도 DB에 진행 중으로 남았다면 종료 상태를 확인해요.
    pending = fetch_all(
        "SELECT fixture_id FROM fixtures WHERE state_id IN ("
        + ",".join(["%s"] * len(LIVE_STATE_IDS)) + ")", LIVE_STATE_IDS,
    )
    for (fixture_id,) in pending:
        if fixture_id not in by_id:
            by_id[fixture_id] = (
                client.get_live_fixture(fixture_id), datetime.now(timezone.utc).replace(tzinfo=None),
            )
    if not by_id:
        return {"apply": apply, "received": 0, "matched": 0, "updated": 0}
    ids = tuple(by_id)
    scope = fetch_all(
        "SELECT fixture_id,home_team_id,away_team_id FROM fixtures WHERE fixture_id IN ("
        + ",".join(["%s"] * len(ids)) + ")", ids,
    )
    for fixture_id, home_team_id, away_team_id in scope:
        payload, fetched_at = by_id[fixture_id]
        payload = client.correct_fixture_details(payload)
        if apply:
            store_live_fixture(payload, home_team_id, away_team_id, fetched_at)
        else:
            # 조회 모드에서도 실제 응답의 상세·시계 변환을 확인하지만 저장하지 않아요.
            _normalize_fixture_details(payload, fixture_id)
            normalize_clock(payload, fetched_at)
    return {"apply": apply, "received": len(by_id), "matched": len(scope),
            "updated": len(scope) if apply else 0}
