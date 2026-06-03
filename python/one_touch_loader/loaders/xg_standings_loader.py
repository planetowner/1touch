from __future__ import annotations

import math
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, Iterable, Optional

import pandas as pd
import soccerdata as sd

from ..core.db import execute, fetch_all, upsert_many


BIG5_LEAGUE_IDS = [8, 82, 301, 384, 564]

CALIBRATION_LOOKBACK_SEASONS = 5
CALIBRATION_METHOD = "historical_draw_rate"


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


@dataclass(frozen=True)
class DrawBandCalibration:
    league_id: int
    season_id: int
    method: str
    lookback_seasons: int
    calibration_match_count: int
    target_draw_rate: Decimal
    draw_band: Decimal
    calibration_season_ids: list[int]


def _decimal(value: Any, places: str = "0.001") -> Decimal:
    if value is None:
        return Decimal("0").quantize(Decimal(places))

    try:
        if pd.isna(value):
            return Decimal("0").quantize(Decimal(places))
    except TypeError:
        pass

    return Decimal(str(value)).quantize(Decimal(places), rounding=ROUND_HALF_UP)


def _safe_int(value: Any) -> Optional[int]:
    if value is None:
        return None

    try:
        if pd.isna(value):
            return None
    except TypeError:
        pass

    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """
    soccerdata can return a MultiIndex DataFrame depending on the method/source.
    Resetting the index makes league/season/game fields available as columns.
    """
    if isinstance(df.index, pd.MultiIndex) or df.index.name is not None:
        df = df.reset_index()

    df.columns = [str(c) for c in df.columns]
    return df


def _first_existing_column(df: pd.DataFrame, candidates: Iterable[str]) -> Optional[str]:
    for col in candidates:
        if col in df.columns:
            return col
    return None


def _load_understat_source(
    understat_league_key: str,
    understat_season_key: str,
    *,
    no_cache: bool,
    no_store: bool,
) -> pd.DataFrame:
    """
    Uses read_schedule because it exposes both teams and match-level xG.

    Required normalized columns:
      home_team_id
      away_team_id
      home_xg
      away_xg
    """
    source = sd.Understat(
        leagues=understat_league_key,
        seasons=understat_season_key,
        no_cache=no_cache,
        no_store=no_store,
    )

    df = source.read_schedule(include_matches_without_data=True)
    df = _normalize_columns(df)

    required = ["home_team_id", "away_team_id", "home_xg", "away_xg"]
    missing = [col for col in required if col not in df.columns]

    if missing:
        raise RuntimeError(
            "Understat schedule is missing required columns "
            f"{missing}. Available columns: {list(df.columns)}"
        )

    return df


def _get_understat_mapping_for_season(
    league_id: int,
    season_id: int,
) -> tuple[str, str]:
    """
    Returns:
      understat_league_key, understat_season_key
    """
    rows = fetch_all(
        """
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
        """,
        (league_id, season_id),
    )

    if not rows:
        raise RuntimeError(
            f"No Understat league/season mapping found for "
            f"league_id={league_id}, season_id={season_id}"
        )

    understat_league_key, understat_season_key = rows[0]
    return str(understat_league_key), str(understat_season_key)


def _get_team_map() -> dict[int, int]:
    """
    Returns:
      {understat_team_id: sportmonks_team_id}
    """
    rows = fetch_all(
        """
        SELECT
          understat_team_id,
          sportmonks_team_id
        FROM understat_team_map
        """
    )

    mapping: dict[int, int] = {}

    for understat_team_id, sportmonks_team_id in rows:
        mapping[int(understat_team_id)] = int(sportmonks_team_id)

    return mapping


def _get_calibration_seasons(
    league_id: int,
    season_id: int,
    lookback_seasons: int = CALIBRATION_LOOKBACK_SEASONS,
) -> list[dict[str, Any]]:
    """
    Returns exactly the previous N mapped seasons for the same league.

    If fewer than N previous mapped seasons exist, the caller must skip
    the target season.
    """
    if lookback_seasons <= 0:
        raise ValueError("lookback_seasons must be greater than 0.")

    rows = fetch_all(
        f"""
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
        LIMIT {int(lookback_seasons)}
        """,
        (league_id, season_id),
    )

    return [
        {
            "season_id": int(row[0]),
            "understat_season_key": str(row[1]),
        }
        for row in rows
    ]


def _get_actual_draw_rate_from_fixtures(
    league_id: int,
    season_ids: list[int],
) -> tuple[Decimal, int]:
    """
    Calculates actual draw rate from Sportmonks fixtures.

    Fixed condition:
      league_id = target league
      season_id IN previous 5 seasons
      competition_type = 'league'
      status = 'past'
      home_score IS NOT NULL
      away_score IS NOT NULL
    """
    if not season_ids:
        raise RuntimeError("No calibration season IDs provided.")

    placeholders = ",".join(["%s"] * len(season_ids))

    rows = fetch_all(
        f"""
        SELECT
          COUNT(*) AS match_count,
          COALESCE(
            SUM(CASE WHEN home_score = away_score THEN 1 ELSE 0 END),
            0
          ) AS draw_count
        FROM fixtures
        WHERE league_id = %s
          AND season_id IN ({placeholders})
          AND competition_type = 'league'
          AND status = 'past'
          AND home_score IS NOT NULL
          AND away_score IS NOT NULL
        """,
        tuple([league_id] + season_ids),
    )

    match_count_raw, draw_count_raw = rows[0]

    match_count = int(match_count_raw or 0)
    draw_count = int(draw_count_raw or 0)

    if match_count == 0:
        raise RuntimeError(
            f"No completed fixture data found for draw-rate calibration. "
            f"league_id={league_id}, season_ids={season_ids}"
        )

    rate = Decimal(draw_count) / Decimal(match_count)

    return (
        rate.quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP),
        match_count,
    )


def _empirical_percentile_threshold(
    values: list[Decimal],
    percentile: Decimal,
) -> Decimal:
    """
    Discrete empirical percentile.

    Returns the smallest observed threshold such that at least `percentile`
    of historical matches have abs(xG diff) <= threshold.

    Example:
      percentile = 0.25
      n = 100
      returns the 25th sorted value.
    """
    if not values:
        raise RuntimeError("Cannot calculate percentile threshold from empty values.")

    if percentile < Decimal("0") or percentile > Decimal("1"):
        raise ValueError(f"percentile must be between 0 and 1. Got {percentile}")

    sorted_values = sorted(values)

    if percentile == Decimal("0"):
        return Decimal("0.000")

    index = math.ceil(len(sorted_values) * float(percentile)) - 1
    index = max(0, min(index, len(sorted_values) - 1))

    return sorted_values[index].quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)


def _calculate_draw_band_from_understat(
    understat_league_key: str,
    calibration_seasons: list[dict[str, Any]],
    target_draw_rate: Decimal,
    *,
    no_cache: bool,
    no_store: bool,
) -> Decimal:
    """
    Calculates draw_band from historical xG-difference distribution.

    Fixed method:
      draw_band = empirical percentile of abs(home_xg - away_xg)
      percentile = actual draw rate from previous 5 seasons
    """
    abs_diffs: list[Decimal] = []

    for season in calibration_seasons:
        df = _load_understat_source(
            understat_league_key,
            season["understat_season_key"],
            no_cache=no_cache,
            no_store=no_store,
        )

        for _, match in df.iterrows():
            home_xg_raw = match.get("home_xg")
            away_xg_raw = match.get("away_xg")

            if pd.isna(home_xg_raw) or pd.isna(away_xg_raw):
                continue

            home_xg = _decimal(home_xg_raw, "0.001")
            away_xg = _decimal(away_xg_raw, "0.001")

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

    Fixed logic:
      1. Use exactly previous 5 mapped seasons in the same league.
      2. If fewer than 5 previous seasons exist, return None.
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

    calibration_season_ids = [
        row["season_id"] for row in calibration_seasons
    ]

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


def _upsert_xg_standings_calibration(calibration: DrawBandCalibration) -> None:
    upsert_many(
        SQL_UPSERT_XG_STANDINGS_CALIBRATION,
        [
            (
                calibration.league_id,
                calibration.season_id,
                calibration.method,
                calibration.lookback_seasons,
                calibration.calibration_match_count,
                calibration.target_draw_rate,
                calibration.draw_band,
            )
        ],
    )


def _empty_team_agg(team_id: int) -> Dict[str, Any]:
    return {
        "team_id": team_id,
        "matches_played": 0,
        "won": 0,
        "draw": 0,
        "lost": 0,
        "xg": Decimal("0.000"),
        "xga": Decimal("0.000"),
        "xpts": Decimal("0.00"),
    }


def _add_match_result(
    agg: dict[int, Dict[str, Any]],
    team_id: int,
    team_xg: Decimal,
    opponent_xg: Decimal,
    draw_band: Decimal,
) -> None:
    row = agg[team_id]

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


def _rank_xg_rows(rows: list[Dict[str, Any]]) -> list[Dict[str, Any]]:
    """
    Sorting:
      xPts DESC
      xG diff DESC
      xG DESC
      team_id ASC
    """
    rows.sort(
        key=lambda r: (
            -r["xpts"],
            -(r["xg"] - r["xga"]),
            -r["xg"],
            r["team_id"],
        )
    )

    for index, row in enumerate(rows, start=1):
        row["position"] = index

    return rows


def _get_eligible_xg_standing_seasons(
    *,
    start_year: int,
    end_year: int,
    lookback_seasons: int = CALIBRATION_LOOKBACK_SEASONS,
) -> list[tuple[int, int]]:
    """
    Returns mapped Big 5 seasons that have at least previous 5 mapped seasons.

    Older seasons with insufficient previous seasons are excluded from build target.
    """
    rows = fetch_all(
        """
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
        ORDER BY
          s.league_id,
          s.starting_at
        """,
        (start_year, end_year, lookback_seasons),
    )

    return [(int(league_id), int(season_id)) for league_id, season_id in rows]


def build_xg_standings_for_season(
    league_id: int,
    season_id: int,
    *,
    no_cache: bool = True,
    no_store: bool = False,
    delete_existing: bool = True,
) -> int:
    """
    Build xG standings for one league-season.

    Important:
    - xPts is NOT Understat expected points.
    - xPts is calculated using 1touch xG-result rule.
    - Draws are decided by calibrated draw_band:
        team_xg - opponent_xg > draw_band => W, +3
        abs(team_xg - opponent_xg) <= draw_band => D, +1
        team_xg - opponent_xg < -draw_band => L, +0
    - draw_band is calibrated from previous 5 seasons.
    - If fewer than 5 previous mapped seasons exist, this season is skipped.
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
            "[xg_standings] skipped "
            f"league_id={league_id} season_id={season_id} "
            f"reason=not_enough_previous_mapped_seasons "
            f"required_previous_seasons={CALIBRATION_LOOKBACK_SEASONS}"
        )
        return 0

    _upsert_xg_standings_calibration(calibration)

    team_map = _get_team_map()

    df = _load_understat_source(
        understat_league_key,
        understat_season_key,
        no_cache=no_cache,
        no_store=no_store,
    )

    agg: dict[int, Dict[str, Any]] = {}

    skipped_without_xg = 0
    skipped_unmapped = []

    for _, match in df.iterrows():
        home_understat_id = _safe_int(match.get("home_team_id"))
        away_understat_id = _safe_int(match.get("away_team_id"))

        home_xg_raw = match.get("home_xg")
        away_xg_raw = match.get("away_xg")

        if (
            home_understat_id is None
            or away_understat_id is None
            or pd.isna(home_xg_raw)
            or pd.isna(away_xg_raw)
        ):
            skipped_without_xg += 1
            continue

        home_team_id = team_map.get(home_understat_id)
        away_team_id = team_map.get(away_understat_id)

        if home_team_id is None:
            skipped_unmapped.append(("home", home_understat_id, match.get("home_team")))
            continue

        if away_team_id is None:
            skipped_unmapped.append(("away", away_understat_id, match.get("away_team")))
            continue

        home_xg = _decimal(home_xg_raw, "0.001")
        away_xg = _decimal(away_xg_raw, "0.001")

        if home_team_id not in agg:
            agg[home_team_id] = _empty_team_agg(home_team_id)

        if away_team_id not in agg:
            agg[away_team_id] = _empty_team_agg(away_team_id)

        _add_match_result(
            agg,
            home_team_id,
            home_xg,
            away_xg,
            calibration.draw_band,
        )

        _add_match_result(
            agg,
            away_team_id,
            away_xg,
            home_xg,
            calibration.draw_band,
        )

    if skipped_unmapped:
        sample = skipped_unmapped[:10]
        raise RuntimeError(
            "Some Understat teams are not mapped to Sportmonks teams. "
            f"league_id={league_id}, season_id={season_id}, "
            f"sample={sample}"
        )

    ranked = _rank_xg_rows(list(agg.values()))

    batch = []

    for row in ranked:
        batch.append(
            (
                league_id,
                season_id,
                row["team_id"],
                row["position"],
                row["matches_played"],
                row["won"],
                row["draw"],
                row["lost"],
                row["xg"].quantize(Decimal("0.001")),
                row["xga"].quantize(Decimal("0.001")),
                row["xpts"].quantize(Decimal("0.00")),
            )
        )

    if delete_existing:
        execute(
            """
            DELETE FROM xg_standings
            WHERE league_id = %s
              AND season_id = %s
            """,
            (league_id, season_id),
        )

    if batch:
        upsert_many(SQL_UPSERT_XG_STANDINGS, batch)

    print(
        "[xg_standings] "
        f"league_id={league_id} season_id={season_id} "
        f"understat=({understat_league_key}, {understat_season_key}) "
        f"teams={len(batch)} skipped_without_xg={skipped_without_xg} "
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
    start_year: int = 2017,
    end_year: int = 2025,
    no_cache: bool = True,
    no_store: bool = False,
) -> int:
    """
    Build xG standings for all mapped Big 5 seasons.

    Older seasons with fewer than 5 previous mapped seasons are excluded.
    """
    rows = _get_eligible_xg_standing_seasons(
        start_year=start_year,
        end_year=end_year,
        lookback_seasons=CALIBRATION_LOOKBACK_SEASONS,
    )

    total = 0

    for league_id, season_id in rows:
        total += build_xg_standings_for_season(
            int(league_id),
            int(season_id),
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
    """
    Refresh xG standings for current Big 5 seasons only.

    If a current season has fewer than 5 previous mapped seasons, it is skipped.
    """
    rows = fetch_all(
        """
        SELECT
          s.league_id,
          s.season_id
        FROM seasons s
        JOIN understat_season_map usm
          ON usm.sportmonks_season_id = s.season_id
        WHERE s.is_current = 1
          AND s.league_id IN (8, 82, 301, 384, 564)
        ORDER BY
          s.league_id,
          s.starting_at
        """
    )

    total = 0

    for league_id, season_id in rows:
        total += build_xg_standings_for_season(
            int(league_id),
            int(season_id),
            no_cache=no_cache,
            no_store=no_store,
            delete_existing=True,
        )

    print(f"[xg_standings] refresh_current done. rows={total}")
    return total


if __name__ == "__main__":
    build_all_xg_standings()