"""원본 경기·급여를 읽기 전용으로 조회해 현재 시즌 지표를 반환해요."""
from __future__ import annotations

from contextlib import closing
from datetime import datetime, timezone
from functools import lru_cache
import json
from pathlib import Path
from time import time

from ..db import get_conn
from .points_pace_repo import BIG5_COMPETITION_IDS_SQL as LEAGUES_SQL
from ...core.fixture_states import COMPLETED_STATE_IDS
from ...core.player_indicators import build_player_indicators


CALIBRATION_PATH = Path(__file__).parents[2] / "core" / "player_form_calibration.json"
COMPLETED_SQL = ",".join(map(str, COMPLETED_STATE_IDS))


def fetch_indicator_matches(cur, season_ids: list[int], as_of: datetime) -> list[dict]:
    cur.execute(f"""
        SELECT s.season_id, s.competition_id, fl.fixture_id, fl.player_id, fl.team_id,
               fl.minutes_played, fl.rating, f.starting_at
        FROM seasons s JOIN stages st ON st.season_id=s.season_id
        JOIN fixtures f ON f.stage_id=st.stage_id
        JOIN rounds r ON r.round_id=f.round_id
        JOIN fixture_lineups fl ON fl.fixture_id=f.fixture_id
        WHERE s.season_id IN ({','.join(['%s'] * len(season_ids))})
          AND f.state_id IN ({COMPLETED_SQL}) AND r.name REGEXP '^[0-9]+$'
          AND f.starting_at<=%s AND fl.minutes_played>0
        ORDER BY f.starting_at, f.fixture_id, fl.player_id
    """, (*season_ids, as_of))
    return cur.fetchall()


def get_current_player_indicators(player_id: int, *, as_of: datetime | None = None) -> dict | None:
    items = _build_current_snapshot(as_of) if as_of is not None else _cached_current_snapshot(int(time() // 60))
    return items.get(player_id)


@lru_cache(maxsize=1)
def _cached_current_snapshot(minute: int) -> dict[int, dict]:
    # 전체 비교 집단의 조회와 모델 계산을 선수마다 반복하지 않고 최대 1분 공유해요.
    return _build_current_snapshot(datetime.now(timezone.utc).replace(tzinfo=None))


def _build_current_snapshot(as_of: datetime) -> dict[int, dict]:
    # DB의 starting_at은 UTC DATETIME이에요. 모든 집계에 같은 기준 시각을 써요.
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                cur.execute(f"""
                    SELECT sm.player_id, sm.team_id, sm.season_id, sm.position_group_id,
                           s.competition_id, s.name AS season_name, w.estimated_weekly_gross_eur
                    FROM team_squad_members sm JOIN seasons s ON s.season_id=sm.season_id
                    LEFT JOIN player_wages w ON w.team_id=sm.team_id
                         AND w.season_id=sm.season_id AND w.player_id=sm.player_id
                    WHERE s.is_current=1 AND s.competition_id IN ({LEAGUES_SQL})
                    ORDER BY sm.player_id
                """)
                roster = cur.fetchall()
                if not roster:
                    return {}
                seasons = sorted({r["season_id"] for r in roster})
                matches = fetch_indicator_matches(cur, seasons, as_of)
                cur.execute(f"""
                    SELECT st.season_id, f.fixture_id, f.home_team_id, f.away_team_id, f.starting_at
                    FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
                    JOIN rounds r ON r.round_id=f.round_id
                    WHERE st.season_id IN ({','.join(['%s'] * len(seasons))})
                      AND f.state_id IN ({COMPLETED_SQL}) AND r.name REGEXP '^[0-9]+$'
                      AND f.starting_at<=%s
                """, (*seasons, as_of))
                fixtures = cur.fetchall()
        finally:
            conn.rollback()
    calibration = json.loads(CALIBRATION_PATH.read_text(encoding="utf-8"))
    # 직전 시즌의 학습값을 다음 시즌에만 적용해요. 새 시즌의 보정값을 임의로 만들어 쓰지 않아요.
    current_names = {r["season_name"] for r in roster}
    if current_names != {calibration["applies_to_season"]}:
        calibration = None
    items = build_player_indicators(roster, matches, fixtures, calibration, as_of=as_of)
    for result in items:
        result["form_calibration"] = calibration
        result["as_of"] = as_of.replace(tzinfo=timezone.utc)
        if result["form"]["last_match_at"] is not None:
            result["form"]["last_match_at"] = result["form"]["last_match_at"].replace(tzinfo=timezone.utc)
    return {item["player_id"]: item for item in items}
