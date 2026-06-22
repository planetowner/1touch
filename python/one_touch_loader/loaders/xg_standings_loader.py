from __future__ import annotations

import math
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd
import soccerdata as sd

from ..core.db import fetch_all, transaction


BIG5_LEAGUE_IDS: Tuple[int, ...] = (8, 82, 301, 384, 564)

CALIBRATION_LOOKBACK_SEASONS = 5
CALIBRATION_METHOD = "historical_draw_rate"

MIN_SEASON_START_YEAR = 2017
MAX_SEASON_START_YEAR = 2025

XG_DECIMAL_PLACES = "0.001"
XPTS_DECIMAL_PLACES = "0.00"
DRAW_RATE_DECIMAL_PLACES = "0.000001"


SQL_UPSERT_XG_STANDINGS = """
INSERT INTO xg_standings (
  league_id,
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
  league_id,
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
  ON ulm.sportmonks_league_id = s.league_id
WHERE s.league_id = %s
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
WHERE s.league_id = %s
  AND s.starting_at < (
    SELECT target.starting_at
    FROM seasons target
    WHERE target.season_id = %s
    LIMIT 1
  )
ORDER BY s.starting_at DESC
LIMIT {limit}
"""


SQL_GET_ACTUAL_DRAW_RATE = """
SELECT
  COUNT(*) AS match_count,
  CAST(SUM(CASE WHEN home_score = away_score THEN 1 ELSE 0 END) AS SIGNED) AS draw_count
FROM fixtures
WHERE league_id = %s
  AND season_id IN ({placeholders})
  AND competition_type = 'league'
  AND status = 'past'
  AND home_score IS NOT NULL
  AND away_score IS NOT NULL
"""


SQL_GET_ELIGIBLE_BUILD_SEASONS = """
SELECT
  s.league_id,
  s.season_id
FROM seasons s
JOIN understat_season_map usm
  ON usm.sportmonks_season_id = s.season_id
WHERE s.league_id IN (8, 82, 301, 384, 564)
  AND YEAR(s.starting_at) BETWEEN %s AND %s
  AND (
    SELECT COUNT(*)
    FROM seasons previous_s
    JOIN understat_season_map previous_usm
      ON previous_usm.sportmonks_season_id = previous_s.season_id
    WHERE previous_s.league_id = s.league_id
      AND previous_s.starting_at < s.starting_at
  ) >= %s
ORDER BY s.league_id, s.starting_at
"""


SQL_GET_CURRENT_BIG5_SEASONS = """
SELECT s.league_id, s.season_id
FROM seasons s
JOIN understat_season_map usm
  ON usm.sportmonks_season_id = s.season_id
WHERE s.is_current = 1
  AND s.league_id IN (8, 82, 301, 384, 564)
ORDER BY s.league_id, s.starting_at
"""


SQL_DELETE_XG_STANDINGS = """
DELETE FROM xg_standings
WHERE league_id = %s
  AND season_id = %s
"""


# =========================================================
# Strict helpers
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
# Dataclass
# =========================================================

@dataclass(frozen=True)
class DrawBandCalibration:
    league_id: int
    season_id: int
    method: str
    lookback_seasons: int
    calibration_match_count: int
    target_draw_rate: Decimal
    draw_band: Decimal
    calibration_season_ids: List[int]


# =========================================================
# Understat source loader
# =========================================================

def _load_understat_schedule(
    understat_league_key: str,
    understat_season_key: str,
    *,
    no_cache: bool,
    no_store: bool,
) -> pd.DataFrame:
    """
    Verified against soccerdata.Understat.read_schedule:
      - Returns a MultiIndex DataFrame.
      - After reset_index, exposes columns including:
          home_team_id, away_team_id, home_xg, away_xg

    include_matches_without_data=False so future / not-yet-played matches
    (which would arrive with NaN xG and NaN team_id) are excluded by the
    source itself. This matters for in-season refreshes — the previous
    True setting would inject NaN rows into the standings aggregation.
    """
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
# Mapping readers
# =========================================================

def _get_understat_mapping_for_season(
    league_id: int,
    season_id: int,
) -> Tuple[str, str]:
    rows = fetch_all(SQL_GET_UNDERSTAT_MAPPING_FOR_SEASON, (league_id, season_id))

    if not rows:
        raise RuntimeError(
            f"No Understat league/season mapping found for "
            f"league_id={league_id}, season_id={season_id}"
        )

    return (
        _require_non_empty_str(rows[0][0], "understat_league_key"),
        _require_non_empty_str(rows[0][1], "understat_season_key"),
    )


def _get_team_map() -> Dict[int, int]:
    """Returns {understat_team_id: sportmonks_team_id}."""
    rows = fetch_all(SQL_GET_TEAM_MAP)
    mapping: Dict[int, int] = {}

    for row in rows:
        understat_id = _require_int(row[0], "understat_team_map.understat_team_id")
        sportmonks_id = _require_int(row[1], "understat_team_map.sportmonks_team_id")
        mapping[understat_id] = sportmonks_id

    return mapping


# =========================================================
# Calibration: draw rate from Sportmonks + draw band from Understat
# =========================================================

def _get_calibration_seasons(
    league_id: int,
    season_id: int,
    lookback_seasons: int,
) -> List[Dict[str, Any]]:
    if lookback_seasons <= 0:
        raise ValueError(f"lookback_seasons must be > 0, got {lookback_seasons!r}")

    sql = SQL_GET_CALIBRATION_SEASONS.replace("{limit}", str(int(lookback_seasons)))
    rows = fetch_all(sql, (league_id, season_id))

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
    league_id: int,
    season_ids: List[int],
) -> Tuple[Decimal, int]:
    if not season_ids:
        raise RuntimeError("No calibration season IDs provided.")

    placeholders = ",".join(["%s"] * len(season_ids))
    sql = SQL_GET_ACTUAL_DRAW_RATE.replace("{placeholders}", placeholders)
    rows = fetch_all(sql, (league_id, *season_ids))

    match_count = _require_int(rows[0][0], "draw-rate calibration match_count")
    draw_count = _require_int(rows[0][1], "draw-rate calibration draw_count")

    if match_count == 0:
        raise RuntimeError(
            f"No completed fixture data found for draw-rate calibration. "
            f"league_id={league_id}, season_ids={season_ids}"
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
    Discrete empirical percentile. Returns the smallest observed threshold
    such that at least `percentile` of values are <= threshold.
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
    league_id: int,
    season_id: int,
    understat_league_key: str,
    *,
    lookback_seasons: int = CALIBRATION_LOOKBACK_SEASONS,
    no_cache: bool,
    no_store: bool,
) -> Optional[DrawBandCalibration]:
    """
    Builds the xG draw threshold for one league-season.

    Method:
      1. Use exactly previous N mapped seasons in the same league.
      2. If fewer than N previous seasons exist, return None (skip).
      3. Calculate actual draw rate from completed league fixtures.
      4. Calculate abs(home_xg - away_xg) distribution from Understat.
      5. draw_band = empirical percentile(abs_xg_diff, actual_draw_rate)
    """
    calibration_seasons = _get_calibration_seasons(
        league_id,
        season_id,
        lookback_seasons=lookback_seasons,
    )

    if len(calibration_seasons) < lookback_seasons:
        return None

    calibration_season_ids = [s["season_id"] for s in calibration_seasons]

    target_draw_rate, match_count = _get_actual_draw_rate_from_fixtures(
        league_id,
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
        league_id=league_id,
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
    """Calibration upsert + DELETE existing standings + INSERT new ones in one transaction.

    Ensures we never leave calibration metadata ahead of the standings rows
    they describe, and never wipe existing standings without a successful
    replacement.
    """
    calibration_row = (
        calibration.league_id,
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
                (calibration.league_id, calibration.season_id),
            )

            if standings_batch:
                cur.executemany(SQL_UPSERT_XG_STANDINGS, standings_batch)


# =========================================================
# Standings aggregation
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
    Sorting:
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
# Public API
# =========================================================

def build_xg_standings_for_season(
    league_id: int,
    season_id: int,
    *,
    no_cache: bool = True,
    no_store: bool = False,
    delete_existing: bool = True,
) -> int:
    """
    Build xG standings for one Big 5 league-season.

    Important:
      - xPts is NOT Understat expected points. It is 1touch's own xG-result rule.
      - Draws are decided by calibrated draw_band:
          team_xg - opponent_xg > draw_band       -> W, +3
          abs(team_xg - opponent_xg) <= draw_band -> D, +1
          team_xg - opponent_xg < -draw_band      -> L, +0
      - draw_band is calibrated from previous N seasons.
      - If fewer than N previous mapped seasons exist, this season is skipped.
    """
    if league_id not in BIG5_LEAGUE_IDS:
        raise ValueError(
            f"xg_standings only supports Big 5 league IDs: {BIG5_LEAGUE_IDS}. "
            f"Received league_id={league_id}"
        )

    understat_league_key, understat_season_key = _get_understat_mapping_for_season(
        league_id,
        season_id,
    )

    calibration = calibrate_draw_band_for_season(
        league_id,
        season_id,
        understat_league_key,
        lookback_seasons=CALIBRATION_LOOKBACK_SEASONS,
        no_cache=no_cache,
        no_store=no_store,
    )

    if calibration is None:
        print(
            f"[xg_standings] skipped league_id={league_id} season_id={season_id} "
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
            f"league_id={league_id}, season_id={season_id}, sample={unmapped[:10]}"
        )

    ranked = _rank_xg_rows(list(agg.values()))

    batch = [
        (
            league_id,
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
        f"[xg_standings] league_id={league_id} season_id={season_id} "
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
    end_year: int = MAX_SEASON_START_YEAR,
    no_cache: bool = True,
    no_store: bool = False,
) -> int:
    rows = fetch_all(
        SQL_GET_ELIGIBLE_BUILD_SEASONS,
        (start_year, end_year, CALIBRATION_LOOKBACK_SEASONS),
    )

    total = 0

    for league_id, season_id in rows:
        total += build_xg_standings_for_season(
            _require_int(league_id, "seasons.league_id"),
            _require_int(season_id, "seasons.season_id"),
            no_cache=no_cache,
            no_store=no_store,
            delete_existing=True,
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

    for league_id, season_id in rows:
        total += build_xg_standings_for_season(
            _require_int(league_id, "seasons.league_id"),
            _require_int(season_id, "seasons.season_id"),
            no_cache=no_cache,
            no_store=no_store,
            delete_existing=True,
        )

    print(f"[xg_standings] refresh_current done. rows={total}")
    return total


if __name__ == "__main__":
    build_all_xg_standings()
