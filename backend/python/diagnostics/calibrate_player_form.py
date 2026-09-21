"""직전 시즌만 읽어 현재 시즌 폼의 감쇠 계수를 검증해요. DB에는 쓰지 않아요."""
from __future__ import annotations

import argparse
from contextlib import closing
from datetime import datetime, timezone
import json
from pathlib import Path

from one_touch_loader.api.repos.player_indicators_repo import fetch_indicator_matches, LEAGUES_SQL
from one_touch_loader.core.db import get_conn
from one_touch_loader.core.player_indicators import calibrate_form_decay


def calibrate() -> dict:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                cur.execute(f"SELECT DISTINCT name FROM seasons WHERE is_current=1 AND competition_id IN ({LEAGUES_SQL})")
                names = [r["name"] for r in cur.fetchall()]
                if len(names) != 1:
                    raise ValueError("Current five-league seasons must share one season name")
                current = names[0]
                start, end = map(int, current.split("/"))
                previous = f"{start - 1}/{end - 1}"
                cur.execute(f"SELECT season_id FROM seasons WHERE name=%s AND competition_id IN ({LEAGUES_SQL})", (previous,))
                season_ids = [r["season_id"] for r in cur.fetchall()]
                if len(season_ids) != 5:
                    raise ValueError("The previous season must include all five leagues")
                cur.execute(f"SELECT MIN(f.starting_at) AS first_match FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id JOIN seasons s ON s.season_id=st.season_id WHERE s.name=%s AND s.competition_id IN ({LEAGUES_SQL})", (current,))
                cutoff = cur.fetchone()["first_match"]
                if cutoff is None:
                    raise ValueError("Current season fixture dates are unavailable")
                rows = fetch_indicator_matches(cur, season_ids, min(now, cutoff))
        finally:
            conn.rollback()
    return {"trained_on_season": previous, "applies_to_season": current,
            "method": "walk_forward_next_match_minutes_weighted_mse",
            "training_cutoff_utc": cutoff.isoformat(), **calibrate_form_decay(rows)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="검증한 계수를 저장할 로컬 JSON 경로예요.")
    args = parser.parse_args()
    report = json.dumps(calibrate(), indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.write_text(report, encoding="utf-8")
    print(report)
