from __future__ import annotations

from typing import Dict, List, Optional, Tuple

from ..core.db import fetch_all, upsert_many


MODEL_NAME = "season_attribute_v1"
MODEL_VERSION = 1

ATTRIBUTE_NAMES = [
    "Attack",
    "Progression",
    "Pressure",
    "Dominance",
    "Defense",
    "Possession",
]

FEATURE_COLUMNS = [
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


SQL_SELECT_MODEL = """
SELECT
    model_id,
    model_name,
    version,
    normalization_method
FROM score_models
WHERE model_name = %s
  AND version = %s
  AND scope_type = 'fixture'
LIMIT 1
"""

SQL_SELECT_MODEL_WEIGHTS = """
SELECT
    attribute_name,
    feature_name,
    weight
FROM score_model_weights
WHERE model_id = %s
ORDER BY attribute_name, feature_name
"""

SQL_SELECT_SEASON_LEAGUE_BY_FIXTURE = """
SELECT
    season_id,
    league_id
FROM fixture_team_features
WHERE fixture_id = %s
LIMIT 1
"""

SQL_SELECT_FEATURE_ROWS_BY_SEASON_AND_LEAGUE = f"""
SELECT
    fixture_id,
    season_id,
    league_id,
    team_id,
    opponent_team_id,
    location,
    {", ".join(FEATURE_COLUMNS)}
FROM fixture_team_features
WHERE season_id = %s
  AND league_id = %s
ORDER BY fixture_id, location, team_id
"""

SQL_SELECT_DISTINCT_LEAGUES_BY_SEASON = """
SELECT DISTINCT
    league_id
FROM fixture_team_features
WHERE season_id = %s
ORDER BY league_id
"""

SQL_SELECT_CURRENT_SEASON_IDS = """
SELECT s.season_id
FROM seasons s
WHERE s.is_current = 1
ORDER BY s.season_id
"""

SQL_UPSERT_TEAM_ATTRIBUTE_SCORES = """
INSERT INTO team_attribute_scores (
  model_id,
  fixture_id,
  season_id,
  league_id,
  team_id,
  opponent_team_id,
  location,
  attack_score,
  progression_score,
  pressure_score,
  dominance_score,
  defense_score,
  possession_score
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE
  season_id = VALUES(season_id),
  league_id = VALUES(league_id),
  opponent_team_id = VALUES(opponent_team_id),
  location = VALUES(location),
  attack_score = VALUES(attack_score),
  progression_score = VALUES(progression_score),
  pressure_score = VALUES(pressure_score),
  dominance_score = VALUES(dominance_score),
  defense_score = VALUES(defense_score),
  possession_score = VALUES(possession_score)
"""


def _safe_float(v) -> float:
    if v is None:
        return 0.0
    if isinstance(v, bool):
        return 0.0
    if isinstance(v, (int, float)):
        return float(v)
    if isinstance(v, str):
        s = v.strip()
        if not s:
            return 0.0
        try:
            return float(s)
        except Exception:
            return 0.0
    try:
        return float(v)
    except Exception:
        return 0.0


def _safe_float_or_none(v) -> Optional[float]:
    if v is None:
        return None
    if isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return float(v)
    if isinstance(v, str):
        s = v.strip()
        if not s:
            return None
        try:
            return float(s)
        except Exception:
            return None
    try:
        return float(v)
    except Exception:
        return None


def _load_model() -> Tuple[int, str, int, str]:
    rows = fetch_all(SQL_SELECT_MODEL, (MODEL_NAME, MODEL_VERSION))
    if not rows:
        raise RuntimeError(
            f"Score model not found: model_name={MODEL_NAME} version={MODEL_VERSION}. "
            f"Make sure the SQL seed ran successfully."
        )
    model_id, model_name, version, normalization_method = rows[0]
    return int(model_id), str(model_name), int(version), str(normalization_method)


def _load_model_weights(model_id: int) -> Dict[str, Dict[str, float]]:
    rows = fetch_all(SQL_SELECT_MODEL_WEIGHTS, (model_id,))
    weights: Dict[str, Dict[str, float]] = {attr: {} for attr in ATTRIBUTE_NAMES}

    for attribute_name, feature_name, weight in rows:
        attr = str(attribute_name)
        feat = str(feature_name)
        if attr not in weights:
            continue
        weights[attr][feat] = _safe_float(weight)

    return weights


def _row_to_feature_dict_nullable(row: Tuple) -> Dict:
    head = {
        "fixture_id": int(row[0]),
        "season_id": int(row[1]),
        "league_id": int(row[2]),
        "team_id": int(row[3]),
        "opponent_team_id": int(row[4]),
        "location": str(row[5]),
    }

    feature_values = row[6:]
    features: Dict[str, Optional[float]] = {}
    for i, name in enumerate(FEATURE_COLUMNS):
        features[name] = _safe_float_or_none(feature_values[i])

    head["features"] = features
    return head


def _build_feature_ranges(feature_rows: List[Tuple]) -> Dict[str, Tuple[Optional[float], Optional[float]]]:
    mins: Dict[str, Optional[float]] = {name: None for name in FEATURE_COLUMNS}
    maxs: Dict[str, Optional[float]] = {name: None for name in FEATURE_COLUMNS}

    for row in feature_rows:
        feature_values = row[6:]
        for i, feature_name in enumerate(FEATURE_COLUMNS):
            value = _safe_float_or_none(feature_values[i])
            if value is None:
                continue

            current_min = mins[feature_name]
            current_max = maxs[feature_name]

            if current_min is None or value < current_min:
                mins[feature_name] = value
            if current_max is None or value > current_max:
                maxs[feature_name] = value

    ranges: Dict[str, Tuple[Optional[float], Optional[float]]] = {}
    for feature_name in FEATURE_COLUMNS:
        ranges[feature_name] = (mins[feature_name], maxs[feature_name])

    return ranges


def _normalize_feature_value(
    value: Optional[float],
    min_value: Optional[float],
    max_value: Optional[float],
) -> Optional[float]:
    if value is None:
        return None
    if min_value is None or max_value is None:
        return None

    span = max_value - min_value
    if abs(span) <= 1e-12:
        return 50.0

    score = ((value - min_value) / span) * 100.0

    if score < 0.0:
        score = 0.0
    elif score > 100.0:
        score = 100.0

    return score


def _build_normalized_feature_map(
    raw_features: Dict[str, Optional[float]],
    feature_ranges: Dict[str, Tuple[Optional[float], Optional[float]]],
) -> Dict[str, Optional[float]]:
    normalized: Dict[str, Optional[float]] = {}

    for feature_name in FEATURE_COLUMNS:
        value = raw_features.get(feature_name)
        min_value, max_value = feature_ranges.get(feature_name, (None, None))
        normalized[feature_name] = _normalize_feature_value(value, min_value, max_value)

    return normalized


def _calc_attribute_score(
    attribute_name: str,
    normalized_features: Dict[str, Optional[float]],
    weights_by_attribute: Dict[str, Dict[str, float]],
) -> float:
    feature_weights = weights_by_attribute.get(attribute_name, {})
    if not feature_weights:
        return 50.0

    weighted_sum = 0.0
    weight_sum = 0.0

    for feature_name, weight in feature_weights.items():
        feature_score = normalized_features.get(feature_name)
        if feature_score is None:
            continue

        weighted_sum += feature_score * weight
        weight_sum += weight

    if weight_sum <= 0:
        return 50.0

    return round(weighted_sum / weight_sum, 4)


def _build_upsert_rows(
    model_id: int,
    feature_rows: List[Tuple],
    weights_by_attribute: Dict[str, Dict[str, float]],
    feature_ranges: Dict[str, Tuple[Optional[float], Optional[float]]],
) -> List[Tuple]:
    upsert_rows: List[Tuple] = []

    for row in feature_rows:
        team = _row_to_feature_dict_nullable(row)
        normalized_features = _build_normalized_feature_map(team["features"], feature_ranges)

        attack = _calc_attribute_score("Attack", normalized_features, weights_by_attribute)
        progression = _calc_attribute_score("Progression", normalized_features, weights_by_attribute)
        pressure = _calc_attribute_score("Pressure", normalized_features, weights_by_attribute)
        dominance = _calc_attribute_score("Dominance", normalized_features, weights_by_attribute)
        defense = _calc_attribute_score("Defense", normalized_features, weights_by_attribute)
        possession = _calc_attribute_score("Possession", normalized_features, weights_by_attribute)

        upsert_rows.append(
            (
                int(model_id),
                int(team["fixture_id"]),
                int(team["season_id"]),
                int(team["league_id"]),
                int(team["team_id"]),
                int(team["opponent_team_id"]),
                team["location"],
                attack,
                progression,
                pressure,
                dominance,
                defense,
                possession,
            )
        )

    return upsert_rows


def build_team_attribute_scores_season_norm_for_fixture(fixture_id: int) -> None:
    model_id, model_name, version, normalization_method = _load_model()
    weights_by_attribute = _load_model_weights(model_id)

    season_league_rows = fetch_all(SQL_SELECT_SEASON_LEAGUE_BY_FIXTURE, (fixture_id,))
    if not season_league_rows:
        print(f"[team-scores-season] fixture not found in fixture_team_features: fixture_id={fixture_id}")
        return

    season_id, league_id = season_league_rows[0]
    season_id = int(season_id)
    league_id = int(league_id)

    all_rows = fetch_all(SQL_SELECT_FEATURE_ROWS_BY_SEASON_AND_LEAGUE, (season_id, league_id))
    if not all_rows:
        print(
            f"[team-scores-season] no feature rows found for league/season scope: "
            f"season_id={season_id} league_id={league_id}"
        )
        return

    fixture_rows = [row for row in all_rows if int(row[0]) == int(fixture_id)]
    if not fixture_rows:
        print(f"[team-scores-season] no feature rows found for fixture_id={fixture_id}")
        return

    feature_ranges = _build_feature_ranges(all_rows)
    upsert_rows = _build_upsert_rows(
        model_id=model_id,
        feature_rows=fixture_rows,
        weights_by_attribute=weights_by_attribute,
        feature_ranges=feature_ranges,
    )

    if upsert_rows:
        upsert_many(SQL_UPSERT_TEAM_ATTRIBUTE_SCORES, upsert_rows)

    print(
        f"[team-scores-season] fixture {fixture_id}: "
        f"model={model_name} v{version} normalization={normalization_method} "
        f"season_id={season_id} league_id={league_id} score_rows={len(upsert_rows)}"
    )


def build_team_attribute_scores_season_norm_for_season(season_id: int) -> None:
    model_id, model_name, version, normalization_method = _load_model()
    weights_by_attribute = _load_model_weights(model_id)

    league_rows = fetch_all(SQL_SELECT_DISTINCT_LEAGUES_BY_SEASON, (season_id,))
    league_ids = [int(row[0]) for row in league_rows]

    if not league_ids:
        print(f"[team-scores-season] no leagues found in fixture_team_features: season_id={season_id}")
        return

    total_rows = 0

    for league_id in league_ids:
        feature_rows = fetch_all(SQL_SELECT_FEATURE_ROWS_BY_SEASON_AND_LEAGUE, (season_id, league_id))
        if not feature_rows:
            print(
                f"[team-scores-season] skip empty scope: season_id={season_id} league_id={league_id}"
            )
            continue

        feature_ranges = _build_feature_ranges(feature_rows)
        upsert_rows = _build_upsert_rows(
            model_id=model_id,
            feature_rows=feature_rows,
            weights_by_attribute=weights_by_attribute,
            feature_ranges=feature_ranges,
        )

        if upsert_rows:
            upsert_many(SQL_UPSERT_TEAM_ATTRIBUTE_SCORES, upsert_rows)

        total_rows += len(upsert_rows)

        print(
            f"[team-scores-season] season={season_id} league={league_id}: "
            f"model={model_name} v{version} normalization={normalization_method} "
            f"score_rows={len(upsert_rows)}"
        )

    print(
        f"[team-scores-season] season {season_id} done: "
        f"leagues_processed={len(league_ids)} total_score_rows={total_rows}"
    )


def build_team_attribute_scores_season_norm_for_current_seasons() -> None:
    season_rows = fetch_all(SQL_SELECT_CURRENT_SEASON_IDS)
    season_ids = [int(row[0]) for row in season_rows]

    total_seasons = 0
    for season_id in season_ids:
        build_team_attribute_scores_season_norm_for_season(season_id)
        total_seasons += 1

    print(
        f"[team-scores-season] current seasons done: "
        f"seasons_processed={total_seasons}"
    )