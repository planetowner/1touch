"""현재 시즌 지표를 별도 작업에서 계산하고 완성된 결과만 함께 공개해요."""

from __future__ import annotations

import argparse
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
from time import perf_counter

from ..core.db import get_conn
from ..core.fixture_states import COMPLETED_STATE_IDS
from ..core.player_rating_percentile import RATING_COMPETITION_IDS


CALIBRATION_PATH = Path(__file__).parents[1] / "core" / "player_form_calibration.json"
LEAGUES_SQL = ",".join(map(str, RATING_COMPETITION_IDS))
COMPLETED_SQL = ",".join(map(str, COMPLETED_STATE_IDS))
# 계산 규칙을 바꾸면 올려요. 입력이 같아도 새 규칙으로 다시 계산해야 해요.
MODEL_VERSION = 1


def fetch_indicator_matches(cur, season_ids: list[int], as_of: datetime) -> list[dict]:
    cur.execute(
        f"""
        SELECT s.season_id, s.competition_id, fl.fixture_id, fl.player_id, fl.team_id,
               fl.minutes_played, fl.rating, f.starting_at
        FROM seasons s JOIN stages st ON st.season_id=s.season_id
        JOIN fixtures f ON f.stage_id=st.stage_id
        JOIN rounds r ON r.round_id=f.round_id
        JOIN fixture_lineups fl ON fl.fixture_id=f.fixture_id
        WHERE s.season_id IN ({",".join(["%s"] * len(season_ids))})
          AND f.state_id IN ({COMPLETED_SQL}) AND r.name REGEXP '^[0-9]+$'
          AND f.starting_at<=%s AND fl.minutes_played>0
        ORDER BY f.starting_at, f.fixture_id, fl.player_id, fl.team_id
    """,
        (*season_ids, as_of),
    )
    return cur.fetchall()


def read_current_inputs(as_of: datetime) -> tuple:
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
                    ORDER BY sm.player_id, sm.team_id, sm.season_id
                """)
                roster = cur.fetchall()
                if not roster:
                    return ([], [], [], None)
                seasons = sorted({r["season_id"] for r in roster})
                matches = fetch_indicator_matches(cur, seasons, as_of)
                cur.execute(
                    f"""
                    SELECT st.season_id, f.fixture_id, f.home_team_id, f.away_team_id, f.starting_at
                    FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
                    JOIN rounds r ON r.round_id=f.round_id
                    WHERE st.season_id IN ({",".join(["%s"] * len(seasons))})
                      AND f.state_id IN ({COMPLETED_SQL}) AND r.name REGEXP '^[0-9]+$'
                      AND f.starting_at<=%s
                    ORDER BY f.fixture_id
                """,
                    (*seasons, as_of),
                )
                fixtures = cur.fetchall()
        finally:
            conn.rollback()
    calibration = json.loads(CALIBRATION_PATH.read_text(encoding="utf-8"))
    # 직전 시즌의 학습값을 다음 시즌에만 적용해요. 새 시즌의 보정값을 임의로 만들어 쓰지 않아요.
    current_names = {r["season_name"] for r in roster}
    if current_names != {calibration["applies_to_season"]}:
        calibration = None
    return roster, matches, fixtures, calibration


def build_snapshot(as_of: datetime, inputs: tuple) -> dict[int, dict]:
    roster, matches, fixtures, calibration = inputs
    if not roster:
        return {}
    # 입력이 그대로인 확인 작업에는 학습 모듈이 필요 없어 실제 계산할 때만 가져와요.
    from ..core.player_indicators import build_player_indicators

    items = build_player_indicators(roster, matches, fixtures, calibration, as_of=as_of)
    for result in items:
        result["form_calibration"] = calibration
        result["as_of"] = as_of.replace(tzinfo=timezone.utc)
        if result["form"]["last_match_at"] is not None:
            result["form"]["last_match_at"] = result["form"]["last_match_at"].replace(
                tzinfo=timezone.utc
            )
    return {item["player_id"]: item for item in items}


def input_fingerprint(inputs: tuple) -> str:
    encoded = json.dumps(
        (MODEL_VERSION, inputs),
        sort_keys=True,
        default=str,
        separators=(",", ":"),
        allow_nan=False,
    )
    return hashlib.sha256(encoded.encode()).hexdigest()


def _refresh(cur, *, apply: bool) -> dict:
    # 예약 실행과 수동 실행도 이 행을 먼저 잠가요. API의 일반 SELECT는 기다리지 않아요.
    cur.execute(
        "SELECT * FROM player_indicator_refresh WHERE id=1"
        + (" FOR UPDATE" if apply else "")
    )
    previous = cur.fetchone()
    if previous is None:
        raise RuntimeError(
            "Run create_player_indicator_snapshots.sql before refreshing indicators"
        )
    as_of = datetime.now(timezone.utc).replace(tzinfo=None)
    started = perf_counter()
    inputs = read_current_inputs(as_of)
    fingerprint = input_fingerprint(inputs)
    read_seconds = perf_counter() - started
    report = dict(
        applied=apply,
        checked_at=as_of,
        read_seconds=read_seconds,
        input_sha256=fingerprint,
    )
    if previous["input_sha256"] == fingerprint:
        if apply:
            cur.execute(
                "UPDATE player_indicator_refresh SET checked_at=%s, read_seconds=%s WHERE id=1",
                (as_of, read_seconds),
            )
        return {
            **report,
            "status": "unchanged",
            "player_count": previous["player_count"],
            "as_of": previous["as_of"],
            "calculated_at": previous["calculated_at"],
            "calculation_seconds": 0.0,
            "write_seconds": 0.0,
        }
    started = perf_counter()
    snapshot = build_snapshot(as_of, inputs)
    calculation_seconds = perf_counter() - started
    calculated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    report.update(
        status="updated" if apply else "preview",
        player_count=len(snapshot),
        as_of=as_of,
        calculated_at=calculated_at,
        calculation_seconds=calculation_seconds,
    )
    started = perf_counter()
    if apply:
        # 계산 실패나 저장 실패 때 이전 결과를 보존하도록 교체를 한 트랜잭션에서 마쳐요.
        rows = [
            (
                item["player_id"],
                item["team_id"],
                item["season_id"],
                json.dumps(item, default=str, allow_nan=False, separators=(",", ":")),
            )
            for item in snapshot.values()
        ]
        # 외래 키 확인도 선수 행을 잠그므로 스쿼드·순위 저장과 같은 잠금을 먼저 잡아요.
        # 계산 중에는 공통 잠금을 잡지 않아 다른 배치의 저장을 막지 않아요.
        from .player_rating_rankings_loader import _lock_rating_pool

        _lock_rating_pool(cur)
        cur.execute("DELETE FROM player_indicator_snapshots")
        if rows:
            cur.executemany(
                """INSERT INTO player_indicator_snapshots
                (player_id,team_id,season_id,payload) VALUES (%s,%s,%s,%s)""",
                rows,
            )
        cur.execute(
            """UPDATE player_indicator_refresh SET input_sha256=%s, as_of=%s,
            calculated_at=%s, checked_at=%s, player_count=%s, read_seconds=%s,
            calculation_seconds=%s WHERE id=1""",
            (
                fingerprint,
                as_of,
                calculated_at,
                as_of,
                len(snapshot),
                read_seconds,
                calculation_seconds,
            ),
        )
    return {**report, "write_seconds": perf_counter() - started}


def refresh(*, apply: bool = False) -> dict:
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=not apply)
        try:
            with conn.cursor(dictionary=True) as cur:
                report = _refresh(cur, apply=apply)
            if apply:
                conn.commit()
            else:
                conn.rollback()
            return report
        except Exception:
            conn.rollback()
            raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply", action="store_true", help="완성된 지표를 DB에 저장해요."
    )
    args = parser.parse_args(argv)
    print(
        json.dumps(refresh(apply=args.apply), ensure_ascii=False, default=str),
        flush=True,
    )


if __name__ == "__main__":
    main()
