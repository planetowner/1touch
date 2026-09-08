from __future__ import annotations

import math
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd

from ..core.db import fetch_all, transaction
from ..core.fixture_states import COMPLETED_STATE_IDS


BIG5_COMPETITION_IDS: Tuple[int, ...] = (8, 82, 301, 384, 564)

CALIBRATION_LOOKBACK_SEASONS = 5
CALIBRATION_METHOD = "historical_draw_rate"

MIN_SEASON_START_YEAR = 2017

XG_DECIMAL_PLACES = "0.001"
XPTS_DECIMAL_PLACES = "0.00"
DRAW_RATE_DECIMAL_PLACES = "0.000001"


SQL_UPSERT_XG_STANDINGS = """
INSERT INTO xg_standings (
  competition_id,
  season_id,
  team_id,
  position,
  matches_played,
  won,
  draw,
  lost,
  xg,
  xga,
  xpts
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  position = VALUES(position),
  matches_played = VALUES(matches_played),
  won = VALUES(won),
  draw = VALUES(draw),
  lost = VALUES(lost),
  xg = VALUES(xg),
  xga = VALUES(xga),
  xpts = VALUES(xpts)
"""


SQL_UPSERT_XG_STANDINGS_CALIBRATION = """
INSERT INTO xg_standings_calibration (
  competition_id,
  season_id,
  method,
  lookback_seasons,
  calibration_match_count,
  target_draw_rate,
  draw_band
) VALUES (%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  lookback_seasons = VALUES(lookback_seasons),
  calibration_match_count = VALUES(calibration_match_count),
  target_draw_rate = VALUES(target_draw_rate),
  draw_band = VALUES(draw_band)
"""


SQL_GET_UNDERSTAT_MAPPING_FOR_SEASON = """
SELECT
  ulm.understat_league_key,
  usm.understat_season_key
FROM understat_season_map usm
JOIN seasons s
  ON s.season_id = usm.sportmonks_season_id
JOIN understat_league_map ulm
-- Sportmonks는 공급자 식별자를 league_id라고 불러요. 내부 시즌 행에서는
-- competitions.competition_id를 써요.
  ON ulm.sportmonks_league_id = s.competition_id
WHERE s.competition_id = %s
  AND usm.sportmonks_season_id = %s
LIMIT 1
"""


SQL_GET_TEAM_MAP = """
SELECT understat_team_id, sportmonks_team_id
FROM understat_team_map
"""


SQL_GET_CALIBRATION_SEASONS = """
SELECT
  s.season_id,
  usm.understat_season_key
FROM seasons s
JOIN understat_season_map usm
  ON usm.sportmonks_season_id = s.season_id
WHERE s.competition_id = %s
  AND s.name < (
    SELECT target.name
    FROM seasons target
    WHERE target.season_id = %s
    LIMIT 1
  )
ORDER BY s.name DESC
LIMIT {limit}
"""


SQL_GET_ACTUAL_DRAW_RATE = f"""
SELECT
  COUNT(*) AS match_count,
  CAST(SUM(CASE WHEN home_score = away_score THEN 1 ELSE 0 END) AS SIGNED) AS draw_count
FROM fixtures f
JOIN stages st ON st.stage_id = f.stage_id
JOIN seasons s ON s.season_id = st.season_id
JOIN competitions c ON c.competition_id = s.competition_id
WHERE s.competition_id = %s
  AND s.season_id IN ({{placeholders}})
  AND c.competition_type = 'league'
  AND f.state_id IN ({','.join(str(value) for value in COMPLETED_STATE_IDS)})
  AND f.home_score IS NOT NULL
  AND f.away_score IS NOT NULL
"""


SQL_GET_ELIGIBLE_BUILD_SEASONS = """
SELECT
  s.competition_id,
  s.season_id
FROM seasons s
JOIN understat_season_map usm
  ON usm.sportmonks_season_id = s.season_id
WHERE s.competition_id IN (8, 82, 301, 384, 564)
  AND CAST(LEFT(s.name, 4) AS UNSIGNED) >= %s
  AND (
    SELECT COUNT(*)
    FROM seasons previous_s
    JOIN understat_season_map previous_usm
      ON previous_usm.sportmonks_season_id = previous_s.season_id
    WHERE previous_s.competition_id = s.competition_id
      AND previous_s.name < s.name
  ) >= %s
ORDER BY s.competition_id, s.name
"""


SQL_GET_CURRENT_BIG5_SEASONS = """
SELECT s.competition_id, s.season_id
FROM seasons s
JOIN understat_season_map usm
  ON usm.sportmonks_season_id = s.season_id
WHERE s.is_current = 1
  AND s.competition_id IN (8, 82, 301, 384, 564)
ORDER BY s.competition_id, s.name
"""


SQL_DELETE_XG_STANDINGS = """
DELETE FROM xg_standings
WHERE competition_id = %s
  AND season_id = %s
"""


# =========================================================
# 값을 엄격하게 확인하는 도우미
# =========================================================

def _require_int(value, field_name: str) -> int:
    if type(value) is not int:
        raise ValueError(f"Missing or invalid integer field: {field_name}={value!r}")

    return value


def _require_non_empty_str(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string field: {field_name}={value!r}")

    return value.strip()


def _to_decimal(value: Any, places: str) -> Decimal:
    return Decimal(str(value)).quantize(Decimal(places), rounding=ROUND_HALF_UP)


# =========================================================
# 데이터 클래스
# =========================================================

@dataclass(frozen=True)
class DrawBandCalibration:
    competition_id: int
    season_id: int
    method: str
    lookback_seasons: int
    calibration_match_count: int
    target_draw_rate: Decimal
    draw_band: Decimal
    calibration_season_ids: List[int]


# =========================================================
# Understat 원본 로더
# =========================================================

def _load_understat_schedule(
    understat_league_key: str,
    understat_season_key: str,
    *,
    no_cache: bool,
    no_store: bool,
) -> pd.DataFrame:
    """
    soccerdata.Understat.read_schedule에서 확인한 규칙이에요.
      - MultiIndex DataFrame을 반환해요.
      - reset_index 뒤에는 다음 열을 포함해요.
          home_team_id, away_team_id, home_xg, away_xg

    include_matches_without_data=False로 두어, xG와 team_id가 NaN인 미래·미경기 항목을
    원본 단계에서 제외해요. 시즌 중 갱신에 꼭 필요해요. 이전처럼 True로 두면
    NaN 행이 순위 집계에 들어가요.
    """
    import soccerdata as sd

    source = sd.Understat(
        leagues=understat_league_key,
        seasons=understat_season_key,
        no_cache=no_cache,
        no_store=no_store,
    )

    df = source.read_schedule(include_matches_without_data=False).reset_index()
    df.columns = [str(c) for c in df.columns]

    return df


# =========================================================
# 매핑 조회
# =========================================================

def _get_understat_mapping_for_season(
    competition_id: int,
    season_id: int,
) -> Tuple[str, str]:
    rows = fetch_all(SQL_GET_UNDERSTAT_MAPPING_FOR_SEASON, (competition_id, season_id))

    if not rows:
        raise RuntimeError(
            f"No Understat league/season mapping found for "
            f"competition_id={competition_id}, season_id={season_id}"
        )

    return (
        _require_non_empty_str(rows[0][0], "understat_league_key"),
        _require_non_empty_str(rows[0][1], "understat_season_key"),
    )


def _get_team_map() -> Dict[int, int]:
    """{understat_team_id: sportmonks_team_id} 매핑을 반환해요."""
    rows = fetch_all(SQL_GET_TEAM_MAP)
    mapping: Dict[int, int] = {}

    for row in rows:
        understat_id = _require_int(row[0], "understat_team_map.understat_team_id")
        sportmonks_id = _require_int(row[1], "understat_team_map.sportmonks_team_id")
        mapping[understat_id] = sportmonks_id

    return mapping


# =========================================================
# 보정: Sportmonks의 무승부 비율과 Understat의 무승부 범위를 함께 써요.
# =========================================================

def _get_calibration_seasons(
    competition_id: int,
    season_id: int,
    lookback_seasons: int,
) -> List[Dict[str, Any]]:
    if lookback_seasons <= 0:
        raise ValueError(f"lookback_seasons must be > 0, got {lookback_seasons!r}")

    sql = SQL_GET_CALIBRATION_SEASONS.replace("{limit}", str(int(lookback_seasons)))
    rows = fetch_all(sql, (competition_id, season_id))

    return [
        {
            "season_id": _require_int(row[0], "seasons.season_id"),
            "understat_season_key": _require_non_empty_str(
                row[1],
                "understat_season_map.understat_season_key",
            ),
        }
        for row in rows
    ]


def _get_actual_draw_rate_from_fixtures(
    competition_id: int,
    season_ids: List[int],
) -> Tuple[Decimal, int]:
    if not season_ids:
        raise RuntimeError("No calibration season IDs provided.")

    placeholders = ",".join(["%s"] * len(season_ids))
    sql = SQL_GET_ACTUAL_DRAW_RATE.replace("{placeholders}", placeholders)
    rows = fetch_all(sql, (competition_id, *season_ids))

    match_count = _require_int(rows[0][0], "draw-rate calibration match_count")
    draw_count = _require_int(rows[0][1], "draw-rate calibration draw_count")

    if match_count == 0:
        raise RuntimeError(
            f"No completed fixture data found for draw-rate calibration. "
            f"competition_id={competition_id}, season_ids={season_ids}"
        )

    rate = Decimal(draw_count) / Decimal(match_count)

    return (
        rate.quantize(Decimal(DRAW_RATE_DECIMAL_PLACES), rounding=ROUND_HALF_UP),
        match_count,
    )


def _empirical_percentile_threshold(
    values: List[Decimal],
    percentile: Decimal,
) -> Decimal:
    """
    이산 경험적 백분위수를 계산해요.

    전체 값 가운데 최소 `percentile` 비율이 threshold 이하가 되는
    가장 작은 관측 threshold를 반환해요.
    """
    if not values:
        raise RuntimeError("Cannot calculate percentile threshold from empty values.")

    if percentile < Decimal("0") or percentile > Decimal("1"):
        raise ValueError(f"percentile must be between 0 and 1. Got {percentile}")

    sorted_values = sorted(values)

    if percentile == Decimal("0"):
        return Decimal("0").quantize(Decimal(XG_DECIMAL_PLACES))

    index = math.ceil(len(sorted_values) * float(percentile)) - 1
    index = max(0, min(index, len(sorted_values) - 1))

    return sorted_values[index].quantize(
        Decimal(XG_DECIMAL_PLACES),
        rounding=ROUND_HALF_UP,
    )


def _calculate_draw_band_from_understat(
    understat_league_key: str,
    calibration_seasons: List[Dict[str, Any]],
    target_draw_rate: Decimal,
    *,
    no_cache: bool,
    no_store: bool,
) -> Decimal:
    abs_diffs: List[Decimal] = []

    for season in calibration_seasons:
        df = _load_understat_schedule(
            understat_league_key,
            season["understat_season_key"],
            no_cache=no_cache,
            no_store=no_store,
        )

        for _, match in df.iterrows():
            home_xg = _to_decimal(match["home_xg"], XG_DECIMAL_PLACES)
            away_xg = _to_decimal(match["away_xg"], XG_DECIMAL_PLACES)
            abs_diffs.append(abs(home_xg - away_xg))

    if not abs_diffs:
        raise RuntimeError(
            "No xG diff data found for draw-band calibration. "
            f"understat_league_key={understat_league_key}, "
            f"calibration_seasons={calibration_seasons}"
        )

    return _empirical_percentile_threshold(abs_diffs, target_draw_rate)


def calibrate_draw_band_for_season(
    competition_id: int,
    season_id: int,
    understat_league_key: str,
    *,
    lookback_seasons: int = CALIBRATION_LOOKBACK_SEASONS,
    no_cache: bool,
    no_store: bool,
) -> Optional[DrawBandCalibration]:
    """
    한 대회 시즌의 xG 무승부 기준값을 만들어요.

    계산 방법은 다음과 같아요.
      1. 같은 리그에서 매핑된 직전 N개 시즌만 써요.
      2. 이전 시즌이 N개보다 적으면 None을 반환하고 건너뛰어요.
      3. 완료된 리그 경기에서 실제 무승부 비율을 계산해요.
      4. Understat에서 abs(home_xg - away_xg) 분포를 계산해요.
      5. draw_band = empirical percentile(abs_xg_diff, actual_draw_rate)
    """
    calibration_seasons = _get_calibration_seasons(
        competition_id,
        season_id,
        lookback_seasons=lookback_seasons,
    )

    if len(calibration_seasons) < lookback_seasons:
        return None

    calibration_season_ids = [s["season_id"] for s in calibration_seasons]

    target_draw_rate, match_count = _get_actual_draw_rate_from_fixtures(
        competition_id,
        calibration_season_ids,
    )

    draw_band = _calculate_draw_band_from_understat(
        understat_league_key,
        calibration_seasons,
        target_draw_rate,
        no_cache=no_cache,
        no_store=no_store,
    )

    return DrawBandCalibration(
        competition_id=competition_id,
        season_id=season_id,
        method=CALIBRATION_METHOD,
        lookback_seasons=lookback_seasons,
        calibration_match_count=match_count,
        target_draw_rate=target_draw_rate,
        draw_band=draw_band,
        calibration_season_ids=calibration_season_ids,
    )


def _persist_xg_standings_atomically(
    *,
    calibration: DrawBandCalibration,
    standings_batch: List[Tuple],
) -> None:
    """보정값 upsert와 기존 순위 DELETE, 새 순위 INSERT를 한 트랜잭션에서 실행해요.

    보정 메타데이터만 순위 행보다 먼저 저장되거나, 새 순위를 넣지 못한 채 기존 순위만
    지워지는 일을 막아요.
    """
    calibration_row = (
        calibration.competition_id,
        calibration.season_id,
        calibration.method,
        calibration.lookback_seasons,
        calibration.calibration_match_count,
        calibration.target_draw_rate,
        calibration.draw_band,
    )

    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(SQL_UPSERT_XG_STANDINGS_CALIBRATION, calibration_row)
            cur.execute(
                SQL_DELETE_XG_STANDINGS,
                (calibration.competition_id, calibration.season_id),
            )

            if standings_batch:
                cur.executemany(SQL_UPSERT_XG_STANDINGS, standings_batch)


# =========================================================
# 순위 집계
# =========================================================

def _empty_team_agg(team_id: int) -> Dict[str, Any]:
    return {
        "team_id": team_id,
        "matches_played": 0,
        "won": 0,
        "draw": 0,
        "lost": 0,
        "xg": Decimal("0").quantize(Decimal(XG_DECIMAL_PLACES)),
        "xga": Decimal("0").quantize(Decimal(XG_DECIMAL_PLACES)),
        "xpts": Decimal("0").quantize(Decimal(XPTS_DECIMAL_PLACES)),
    }


def _add_match_result(
    row: Dict[str, Any],
    team_xg: Decimal,
    opponent_xg: Decimal,
    draw_band: Decimal,
) -> None:
    row["matches_played"] += 1
    row["xg"] += team_xg
    row["xga"] += opponent_xg

    xg_diff = team_xg - opponent_xg

    if xg_diff > draw_band:
        row["won"] += 1
        row["xpts"] += Decimal("3.00")
    elif xg_diff < -draw_band:
        row["lost"] += 1
    else:
        row["draw"] += 1
        row["xpts"] += Decimal("1.00")


def _rank_xg_rows(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    정렬 순서예요.
      xPts DESC, xG diff DESC, xG DESC, team_id ASC
    """
    rows.sort(
        key=lambda r: (
            -r["xpts"],
            -(r["xg"] - r["xga"]),
            -r["xg"],
            r["team_id"],
        )
    )

    for position, row in enumerate(rows, start=1):
        row["position"] = position

    return rows


# =========================================================
# 외부에서 쓰는 함수
# =========================================================

def build_xg_standings_for_season(
    competition_id: int,
    season_id: int,
    *,
    no_cache: bool = True,
    no_store: bool = False,
) -> int:
    """
    Big 5 대회 시즌 하나의 xG 순위를 만들어요.

    꼭 알아둘 규칙이에요.
      - xPts는 Understat의 기대 승점이 아니에요. 1Touch가 정한 xG 결과 규칙이에요.
      - 무승부는 보정한 draw_band로 결정해요.
          team_xg - opponent_xg > draw_band       -> W, +3
          abs(team_xg - opponent_xg) <= draw_band -> D, +1
          team_xg - opponent_xg < -draw_band      -> L, +0
      - draw_band는 이전 N개 시즌으로 보정해요.
      - 매핑된 이전 시즌이 N개보다 적으면 해당 시즌을 건너뛰어요.
    """
    if competition_id not in BIG5_COMPETITION_IDS:
        raise ValueError(
            f"xg_standings only supports Big 5 league IDs: {BIG5_COMPETITION_IDS}. "
            f"Received competition_id={competition_id}"
        )

    understat_league_key, understat_season_key = _get_understat_mapping_for_season(
        competition_id,
        season_id,
    )

    calibration = calibrate_draw_band_for_season(
        competition_id,
        season_id,
        understat_league_key,
        lookback_seasons=CALIBRATION_LOOKBACK_SEASONS,
        no_cache=no_cache,
        no_store=no_store,
    )

    if calibration is None:
        print(
            f"[xg_standings] skipped competition_id={competition_id} season_id={season_id} "
            f"reason=not_enough_previous_mapped_seasons "
            f"required_previous_seasons={CALIBRATION_LOOKBACK_SEASONS}"
        )
        return 0

    team_map = _get_team_map()

    df = _load_understat_schedule(
        understat_league_key,
        understat_season_key,
        no_cache=no_cache,
        no_store=no_store,
    )

    agg: Dict[int, Dict[str, Any]] = {}
    unmapped: List[Tuple[str, int, str]] = []

    for _, match in df.iterrows():
        home_understat_id = int(match["home_team_id"])
        away_understat_id = int(match["away_team_id"])

        if home_understat_id not in team_map:
            unmapped.append(("home", home_understat_id, str(match["home_team"])))
            continue

        if away_understat_id not in team_map:
            unmapped.append(("away", away_understat_id, str(match["away_team"])))
            continue

        home_team_id = team_map[home_understat_id]
        away_team_id = team_map[away_understat_id]

        home_xg = _to_decimal(match["home_xg"], XG_DECIMAL_PLACES)
        away_xg = _to_decimal(match["away_xg"], XG_DECIMAL_PLACES)

        if home_team_id not in agg:
            agg[home_team_id] = _empty_team_agg(home_team_id)
        if away_team_id not in agg:
            agg[away_team_id] = _empty_team_agg(away_team_id)

        _add_match_result(agg[home_team_id], home_xg, away_xg, calibration.draw_band)
        _add_match_result(agg[away_team_id], away_xg, home_xg, calibration.draw_band)

    if unmapped:
        raise RuntimeError(
            f"Some Understat teams are not mapped to Sportmonks teams. "
            f"competition_id={competition_id}, season_id={season_id}, sample={unmapped[:10]}"
        )

    ranked = _rank_xg_rows(list(agg.values()))

    batch = [
        (
            competition_id,
            season_id,
            row["team_id"],
            row["position"],
            row["matches_played"],
            row["won"],
            row["draw"],
            row["lost"],
            row["xg"].quantize(Decimal(XG_DECIMAL_PLACES)),
            row["xga"].quantize(Decimal(XG_DECIMAL_PLACES)),
            row["xpts"].quantize(Decimal(XPTS_DECIMAL_PLACES)),
        )
        for row in ranked
    ]

    _persist_xg_standings_atomically(
        calibration=calibration,
        standings_batch=batch,
    )

    print(
        f"[xg_standings] competition_id={competition_id} season_id={season_id} "
        f"understat=({understat_league_key}, {understat_season_key}) "
        f"teams={len(batch)} "
        f"method={calibration.method} "
        f"lookback_seasons={calibration.lookback_seasons} "
        f"calibration_season_ids={calibration.calibration_season_ids} "
        f"calibration_matches={calibration.calibration_match_count} "
        f"target_draw_rate={calibration.target_draw_rate} "
        f"draw_band={calibration.draw_band}"
    )

    return len(batch)


def build_all_xg_standings(
    *,
    start_year: int = MIN_SEASON_START_YEAR,
    no_cache: bool = True,
    no_store: bool = False,
) -> int:
    # 시작 연도만 제한하고 끝 연도는 막지 않아요. understat_season_map 조인이 이미
    # xG 데이터가 있는 시즌만 남겨요. 미래 시즌은 데이터가 생기기 전까지 자연스럽게 빠져요.
    # 끝 연도를 고정하면 해마다 직접 올려야 하고, 최신 시즌을 조용히 누락할 수 있어요.
    rows = fetch_all(
        SQL_GET_ELIGIBLE_BUILD_SEASONS,
        (start_year, CALIBRATION_LOOKBACK_SEASONS),
    )

    total = 0

    for competition_id, season_id in rows:
        total += build_xg_standings_for_season(
            _require_int(competition_id, "seasons.competition_id"),
            _require_int(season_id, "seasons.season_id"),
            no_cache=no_cache,
            no_store=no_store,
        )

    print(f"[xg_standings] build_all done. rows={total}")
    return total


def refresh_current_xg_standings(
    *,
    no_cache: bool = True,
    no_store: bool = False,
) -> int:
    rows = fetch_all(SQL_GET_CURRENT_BIG5_SEASONS)

    total = 0

    for competition_id, season_id in rows:
        total += build_xg_standings_for_season(
            _require_int(competition_id, "seasons.competition_id"),
            _require_int(season_id, "seasons.season_id"),
            no_cache=no_cache,
            no_store=no_store,
        )

    print(f"[xg_standings] refresh_current done. rows={total}")
    return total


if __name__ == "__main__":
    build_all_xg_standings()
