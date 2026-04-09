from __future__ import annotations

from typing import Dict, List, Optional, Tuple

from ..core.db import fetch_all, upsert_many


# =========================================================
# SQL
# =========================================================

SQL_SELECT_RAW_STATS_BY_FIXTURE = """
SELECT
    fixture_id,
    season_id,
    league_id,
    team_id,
    opponent_team_id,
    location,
    stat_code,
    stat_value_num
FROM fixture_team_stats_raw
WHERE fixture_id = %s
ORDER BY team_id, stat_code
"""

SQL_SELECT_FIXTURE_IDS_FROM_RAW_BY_SEASON = """
SELECT DISTINCT fixture_id
FROM fixture_team_stats_raw
WHERE season_id = %s
ORDER BY fixture_id
"""

SQL_SELECT_FIXTURE_IDS_FROM_RAW_CURRENT_SEASONS = """
SELECT DISTINCT r.fixture_id
FROM fixture_team_stats_raw r
JOIN seasons s ON s.season_id = r.season_id
WHERE s.is_current = 1
ORDER BY r.fixture_id
"""

SQL_UPSERT_FIXTURE_TEAM_FEATURES = """
INSERT INTO fixture_team_features (
  fixture_id,
  season_id,
  league_id,
  team_id,
  opponent_team_id,
  location,

  accurate_crosses,
  assists,
  attacks,
  ball_possession,
  ball_safe,
  big_chances_created,
  corners,
  dangerous_attacks,
  dribble_attempts,
  duels_won,
  fouls,
  free_kicks,
  goal_attempts,
  goals,
  goals_kicks,
  hit_woodwork,
  injuries,
  interceptions,
  key_passes,
  long_passes,
  offsides,
  passes,
  saves,
  shots_blocked,
  shots_insidebox,
  shots_off_target,
  shots_on_target,
  shots_outsidebox,
  shots_total,
  substitutions,
  successful_dribbles,
  successful_dribbles_percentage,
  successful_headers,
  successful_long_passes,
  successful_long_passes_percentage,
  successful_passes,
  successful_passes_percentage,
  tackles,
  throwins,
  total_crosses,
  yellowcards
) VALUES (
  %s,%s,%s,%s,%s,%s,
  %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s
)
ON DUPLICATE KEY UPDATE
  season_id = VALUES(season_id),
  league_id = VALUES(league_id),
  opponent_team_id = VALUES(opponent_team_id),
  location = VALUES(location),

  accurate_crosses = VALUES(accurate_crosses),
  assists = VALUES(assists),
  attacks = VALUES(attacks),
  ball_possession = VALUES(ball_possession),
  ball_safe = VALUES(ball_safe),
  big_chances_created = VALUES(big_chances_created),
  corners = VALUES(corners),
  dangerous_attacks = VALUES(dangerous_attacks),
  dribble_attempts = VALUES(dribble_attempts),
  duels_won = VALUES(duels_won),
  fouls = VALUES(fouls),
  free_kicks = VALUES(free_kicks),
  goal_attempts = VALUES(goal_attempts),
  goals = VALUES(goals),
  goals_kicks = VALUES(goals_kicks),
  hit_woodwork = VALUES(hit_woodwork),
  injuries = VALUES(injuries),
  interceptions = VALUES(interceptions),
  key_passes = VALUES(key_passes),
  long_passes = VALUES(long_passes),
  offsides = VALUES(offsides),
  passes = VALUES(passes),
  saves = VALUES(saves),
  shots_blocked = VALUES(shots_blocked),
  shots_insidebox = VALUES(shots_insidebox),
  shots_off_target = VALUES(shots_off_target),
  shots_on_target = VALUES(shots_on_target),
  shots_outsidebox = VALUES(shots_outsidebox),
  shots_total = VALUES(shots_total),
  substitutions = VALUES(substitutions),
  successful_dribbles = VALUES(successful_dribbles),
  successful_dribbles_percentage = VALUES(successful_dribbles_percentage),
  successful_headers = VALUES(successful_headers),
  successful_long_passes = VALUES(successful_long_passes),
  successful_long_passes_percentage = VALUES(successful_long_passes_percentage),
  successful_passes = VALUES(successful_passes),
  successful_passes_percentage = VALUES(successful_passes_percentage),
  tackles = VALUES(tackles),
  throwins = VALUES(throwins),
  total_crosses = VALUES(total_crosses),
  yellowcards = VALUES(yellowcards)
"""


# =========================================================
# feature mapping
# =========================================================

STAT_CODE_TO_FEATURE_NAME: Dict[str, str] = {
    "accurate-crosses": "accurate_crosses",
    "assists": "assists",
    "attacks": "attacks",
    "ball-possession": "ball_possession",
    "ball-safe": "ball_safe",
    "big-chances-created": "big_chances_created",
    "corners": "corners",
    "dangerous-attacks": "dangerous_attacks",
    "dribble-attempts": "dribble_attempts",
    "duels-won": "duels_won",
    "fouls": "fouls",
    "free-kicks": "free_kicks",
    "goal-attempts": "goal_attempts",
    "goals": "goals",
    "goals-kicks": "goals_kicks",
    "hit-woodwork": "hit_woodwork",
    "injuries": "injuries",
    "interceptions": "interceptions",
    "key-passes": "key_passes",
    "long-passes": "long_passes",
    "offsides": "offsides",
    "passes": "passes",
    "saves": "saves",
    "shots-blocked": "shots_blocked",
    "shots-insidebox": "shots_insidebox",
    "shots-off-target": "shots_off_target",
    "shots-on-target": "shots_on_target",
    "shots-outsidebox": "shots_outsidebox",
    "shots-total": "shots_total",
    "substitutions": "substitutions",
    "successful-dribbles": "successful_dribbles",
    "successful-dribbles-percentage": "successful_dribbles_percentage",
    "successful-headers": "successful_headers",
    "successful-long-passes": "successful_long_passes",
    "successful-long-passes-percentage": "successful_long_passes_percentage",
    "successful-passes": "successful_passes",
    "successful-passes-percentage": "successful_passes_percentage",
    "tackles": "tackles",
    "throwins": "throwins",
    "total-crosses": "total_crosses",
    "yellowcards": "yellowcards",
}

FEATURE_COLUMNS_IN_ORDER: List[str] = [
    "accurate_crosses",
    "assists",
    "attacks",
    "ball_possession",
    "ball_safe",
    "big_chances_created",
    "corners",
    "dangerous_attacks",
    "dribble_attempts",
    "duels_won",
    "fouls",
    "free_kicks",
    "goal_attempts",
    "goals",
    "goals_kicks",
    "hit_woodwork",
    "injuries",
    "interceptions",
    "key_passes",
    "long_passes",
    "offsides",
    "passes",
    "saves",
    "shots_blocked",
    "shots_insidebox",
    "shots_off_target",
    "shots_on_target",
    "shots_outsidebox",
    "shots_total",
    "substitutions",
    "successful_dribbles",
    "successful_dribbles_percentage",
    "successful_headers",
    "successful_long_passes",
    "successful_long_passes_percentage",
    "successful_passes",
    "successful_passes_percentage",
    "tackles",
    "throwins",
    "total_crosses",
    "yellowcards",
]


# =========================================================
# helpers
# =========================================================

def _build_empty_feature_map() -> Dict[str, Optional[float]]:
    return {name: None for name in FEATURE_COLUMNS_IN_ORDER}


def _normalize_fixture_rows_to_feature_rows(raw_rows: List[Tuple]) -> List[Tuple]:
    """
    raw rows (same fixture) -> fixture_team_features upsert rows
    """
    grouped: Dict[Tuple[int, int], Dict] = {}

    for row in raw_rows:
        (
            fixture_id,
            season_id,
            league_id,
            team_id,
            opponent_team_id,
            location,
            stat_code,
            stat_value_num,
        ) = row

        key = (int(fixture_id), int(team_id))

        if key not in grouped:
            grouped[key] = {
                "fixture_id": int(fixture_id),
                "season_id": int(season_id),
                "league_id": int(league_id),
                "team_id": int(team_id),
                "opponent_team_id": int(opponent_team_id),
                "location": location,
                "features": _build_empty_feature_map(),
            }

        feature_name = STAT_CODE_TO_FEATURE_NAME.get(stat_code)
        if feature_name:
            grouped[key]["features"][feature_name] = float(stat_value_num) if stat_value_num is not None else None

    result_rows: List[Tuple] = []

    for _, item in grouped.items():
        head = (
            item["fixture_id"],
            item["season_id"],
            item["league_id"],
            item["team_id"],
            item["opponent_team_id"],
            item["location"],
        )
        feature_values = tuple(item["features"][name] for name in FEATURE_COLUMNS_IN_ORDER)
        result_rows.append(head + feature_values)

    return result_rows


# =========================================================
# main functions
# =========================================================

def build_fixture_team_features(fixture_id: int) -> None:
    raw_rows = fetch_all(SQL_SELECT_RAW_STATS_BY_FIXTURE, (fixture_id,))
    if not raw_rows:
        print(f"[team-features] no raw rows found: fixture_id={fixture_id}")
        return

    upsert_rows = _normalize_fixture_rows_to_feature_rows(raw_rows)

    if upsert_rows:
        upsert_many(SQL_UPSERT_FIXTURE_TEAM_FEATURES, upsert_rows)

    print(
        f"[team-features] fixture {fixture_id}: "
        f"feature_rows={len(upsert_rows)}"
    )


def build_fixture_team_features_for_season(season_id: int) -> None:
    fixture_rows = fetch_all(SQL_SELECT_FIXTURE_IDS_FROM_RAW_BY_SEASON, (season_id,))
    fixture_ids = [int(row[0]) for row in fixture_rows]

    total = 0
    for fixture_id in fixture_ids:
        build_fixture_team_features(fixture_id)
        total += 1

    print(
        f"[team-features] season {season_id}: "
        f"fixtures_processed={total}"
    )


def build_fixture_team_features_for_current_seasons() -> None:
    fixture_rows = fetch_all(SQL_SELECT_FIXTURE_IDS_FROM_RAW_CURRENT_SEASONS)
    fixture_ids = [int(row[0]) for row in fixture_rows]

    total = 0
    for fixture_id in fixture_ids:
        build_fixture_team_features(fixture_id)
        total += 1

    print(
        f"[team-features] current seasons done: "
        f"fixtures_processed={total}"
    )