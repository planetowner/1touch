from __future__ import annotations

from datetime import date

from .db import fetch_all


def get_latest_transfer_window(competition_id: int, as_of: date) -> dict | None:
    # 다음 창이 열릴 때까지 직전 창을 유지해요. 각국 일정은 따로 입력하며 날짜를 추정하지 않아요.
    rows = fetch_all("""
        SELECT w.season_id, s.name, w.window_name, w.start_date, w.end_date
        FROM transfer_windows w JOIN seasons s ON s.season_id=w.season_id
        WHERE s.competition_id=%s AND w.start_date <= %s
        ORDER BY w.start_date DESC LIMIT 1
    """, (competition_id, as_of))
    return dict(zip(("season_id", "season_name", "window_name", "start_date", "end_date"), rows[0])) if rows else None
