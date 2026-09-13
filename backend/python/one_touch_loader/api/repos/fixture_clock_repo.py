from __future__ import annotations

from ..db import fetch_one_dict


# 마지막 관측 뒤 45초가 지나면 갱신이 늦어진 것으로 보고 시계 진행을 멈춰요.
MAX_CLOCK_AGE_SECONDS = 45


def get_fixture_clock(fixture_id: int) -> dict | None:
    # 날짜 형식의 %s도 MySQL 드라이버가 조회 인자로 읽어서 형식 자체를 따로 전달해요.
    row = fetch_one_dict("""
        SELECT period_type_id, counts_from, period_length, minutes, seconds, ticking,
               time_added,
               DATE_FORMAT(sampled_at, %s) AS sampled_at,
               TIMESTAMPDIFF(MICROSECOND, sampled_at, UTC_TIMESTAMP(6)) / 1000000 AS sample_age_seconds
        FROM fixture_clock WHERE fixture_id=%s
    """, ('%Y-%m-%dT%H:%i:%s.%fZ', fixture_id))
    if row is None:
        return None
    age = max(0.0, float(row["sample_age_seconds"]))
    row["sample_age_seconds"] = age
    row["is_stale"] = age > MAX_CLOCK_AGE_SECONDS
    row["ticking"] = bool(row["ticking"])
    if row["ticking"] and row["minutes"] is not None and row["seconds"] is not None:
        # 킥오프부터 계산하지 않고 공급자의 관측 분·초에 흐른 시간만 더해요.
        elapsed = row["minutes"] * 60 + row["seconds"] + int(min(age, MAX_CLOCK_AGE_SECONDS))
        row["minutes"], row["seconds"] = divmod(elapsed, 60)
    if row["is_stale"] or row["minutes"] is None or row["seconds"] is None:
        row["ticking"] = False
    return row
