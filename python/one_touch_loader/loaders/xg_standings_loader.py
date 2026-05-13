from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, Iterable, Optional

import pandas as pd
import soccerdata as sd

from ..core.db import execute, fetch_all, upsert_many


BIG5_LEAGUE_IDS = [8, 82, 301, 384, 564]


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


@dataclass
class XgStandingRow:
    league_id: int
    season_id: int
    team_id: int
    position: int
    matches_played: int
    won: int
    draw: int
    lost: int
    xg: Decimal
    xga: Decimal
    xpts: Decimal


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
) -> None:
    row = agg[team_id]

    row["matches_played"] += 1
    row["xg"] += team_xg
    row["xga"] += opponent_xg

    if team_xg > opponent_xg:
        row["won"] += 1
        row["xpts"] += Decimal("3.00")
    elif team_xg < opponent_xg:
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
    - xPts is calculated using 1touch rule:
        team_xg > opponent_xg => 3
        team_xg = opponent_xg => 1
        team_xg < opponent_xg => 0
    - won/draw/lost are also based on xG comparison, not actual match result.

    Returns:
      number of teams upserted
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
        )

        _add_match_result(
            agg,
            away_team_id,
            away_xg,
            home_xg,
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
        f"teams={len(batch)} skipped_without_xg={skipped_without_xg}"
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

    Uses seasons.starting_at year to limit range.
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
        ORDER BY
          s.league_id,
          s.starting_at
        """,
        (start_year, end_year),
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