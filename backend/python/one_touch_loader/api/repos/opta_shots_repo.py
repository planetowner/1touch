from __future__ import annotations

from datetime import timezone

from ...core.opta_chalkboard import COORDINATE_SYSTEM
from ..db import fetch_all_dict


def get_shotmap(fixture_id: int) -> dict:
    # 한 쿼리로 읽어 재수집 중에도 이전 요약과 새 슈팅이 섞이지 않게 해요.
    rows = fetch_all_dict("""
        SELECT m.source_url,m.collected_at,m.home_count,m.away_count,
               s.external_event_id,s.team_id,s.player_id,p.display_name AS player_name,
               s.minute,s.extra_minute,s.result,s.start_x,s.start_y,s.end_x,s.end_y
        FROM fixture_opta_shotmaps m LEFT JOIN fixture_opta_shots s ON s.fixture_id=m.fixture_id
        LEFT JOIN players p ON p.player_id=s.player_id
        WHERE m.fixture_id=%s ORDER BY s.minute,s.extra_minute,s.external_event_id
    """, (fixture_id,))
    meta = rows[0] if rows else None
    result = {"fixture_id": fixture_id, "provider": "opta", "available": meta is not None,
              "coordinate_source": "chalkboard_svg", "coordinate_system": COORDINATE_SYSTEM,
              "end_position_kind": "widget_endpoint", "includes_goals": True,
              "source_url": None, "collected_at": None, "counts": None, "shots": []}
    # 미수집은 available=false예요. 수집을 마친 0개 경기는 available=true와 0을 반환해요.
    if meta is None:
        return result
    result.update(source_url=meta["source_url"],
                  collected_at=meta["collected_at"].replace(tzinfo=timezone.utc).isoformat(),
                  counts={"home": meta["home_count"], "away": meta["away_count"]})
    shots = []
    for row in rows:
        if row["external_event_id"] is None:
            continue
        for key in ("source_url", "collected_at", "home_count", "away_count"):
            row.pop(key)
        row["start"] = {axis: float(row.pop(f"start_{axis}")) for axis in ("x", "y")}
        row["end"] = {axis: float(row.pop(f"end_{axis}")) for axis in ("x", "y")}
        shots.append(row)
    result["shots"] = shots
    return result
