"""저장된 지표의 완전성과 실제 조회 지연을 쓰기 없이 확인해요."""

from __future__ import annotations

import argparse
from contextlib import closing
from datetime import timezone
import json
from math import ceil
from statistics import median
from time import perf_counter

from one_touch_loader.api.repos.player_indicators_repo import (
    get_current_player_indicators,
)
from one_touch_loader.api.schemas.player_indicators import PlayerIndicatorsResponse
from one_touch_loader.core.db import get_conn
from one_touch_loader.core.db_json import decoded
from one_touch_loader.core.player_indicator_grades import with_current_grade_labels
from one_touch_loader.core.player_rating_percentile import RATING_COMPETITION_IDS


def check(*, player_id: int | None = None, samples: int = 50) -> dict:
    if samples < 1:
        raise ValueError("At least one timing sample is required")
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                cur.execute("SELECT * FROM player_indicator_refresh WHERE id=1")
                metadata = cur.fetchone()
                cur.execute(
                    "SELECT player_id,team_id,season_id,payload FROM player_indicator_snapshots"
                )
                rows = cur.fetchall()
                cur.execute(f"""SELECT sm.player_id FROM team_squad_members sm
                    JOIN seasons s ON s.season_id=sm.season_id
                    LEFT JOIN player_indicator_snapshots i ON i.player_id=sm.player_id
                         AND i.team_id=sm.team_id AND i.season_id=sm.season_id
                    WHERE s.is_current=1 AND s.competition_id IN ({",".join(map(str, RATING_COMPETITION_IDS))})
                      AND i.player_id IS NULL""")
                missing = cur.fetchall()
        finally:
            conn.rollback()
    if not rows or metadata is None or metadata["player_count"] != len(rows) or missing:
        raise ValueError(
            f"Incomplete player indicators: saved={len(rows)}, missing={len(missing)}"
        )
    leagues = set()
    for row in rows:
        result = PlayerIndicatorsResponse.model_validate(
            with_current_grade_labels(decoded(row["payload"]))
        )
        if (result.player_id, result.team_id, result.season_id) != (
            row["player_id"],
            row["team_id"],
            row["season_id"],
        ):
            raise ValueError(f"Player indicator identity mismatch: {row['player_id']}")
        if result.as_of != metadata["as_of"].replace(tzinfo=timezone.utc):
            raise ValueError("Player indicators contain mixed calculation snapshots")
        leagues.add(result.competition_id)
    if leagues != set(RATING_COMPETITION_IDS):
        raise ValueError("Player indicators must cover all five current leagues")
    player_id = player_id if player_id is not None else rows[0]["player_id"]
    timings = []
    for _ in range(samples):
        started = perf_counter()
        result = PlayerIndicatorsResponse.model_validate(
            get_current_player_indicators(player_id)
        )
        result.model_dump_json()
        timings.append((perf_counter() - started) * 1000)
    ordered = sorted(timings)
    return dict(
        check=True,
        snapshot=metadata,
        api_player_id=player_id,
        samples=samples,
        first_ms=timings[0],
        p50_ms=median(timings),
        p95_ms=ordered[ceil(samples * 0.95) - 1],
        max_ms=max(timings),
        timing_scope="repository_and_response_serialization",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--player-id", type=int)
    parser.add_argument("--samples", type=int, default=50)
    args = parser.parse_args()
    print(
        json.dumps(check(player_id=args.player_id, samples=args.samples), default=str),
        flush=True,
    )


if __name__ == "__main__":
    main()
