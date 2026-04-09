from __future__ import annotations

from typing import Dict, List, Tuple

from ..core.db import fetch_all, upsert_many


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


SQL_SELECT_ACTIVE_MODEL = """
SELECT
    model_id,
    model_name,
    version,
    normalization_method
FROM score_models
WHERE is_active = 1
  AND scope_type = 'fixture'
ORDER BY version DESC, model_id DESC
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

SQL_SELECT_FEATURE_ROWS_BY_FIXTURE = f"""
SELECT
    fixture_id,
    season_id,
    league_id,
    team_id,
    opponent_team_id,
    location,
    {", ".join(FEATURE_COLUMNS)}
FROM fixture_team_features
WHERE fixture_id = %s
ORDER BY location, team_id
"""

SQL_SELECT_FIXTURE_IDS_FROM_FEATURES_BY_SEASON = """
SELECT DISTINCT fixture_id
FROM fixture_team_features
WHERE season_id = %s
ORDER BY fixture_id
"""

SQL_SELECT_FIXTURE_IDS_FROM_FEATURES_CURRENT_SEASONS = """
SELECT DISTINCT ftf.fixture_id
FROM fixture_team_features ftf
JOIN seasons s ON s.season_id = ftf.season_id
WHERE s.is_current = 1
ORDER BY ftf.fixture_id
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


def _load_active_model() -> Tuple[int, str, int, str]:
    rows = fetch_all(SQL_SELECT_ACTIVE_MODEL)
    if not rows:
        raise RuntimeError(
            "No active fixture score model found in score_models. "
            "Make sure the SQL seed ran successfully."
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


def _row_to_feature_dict(row: Tuple) -> Dict:
    head = {
        "fixture_id": int(row[0]),
        "season_id": int(row[1]),
        "league_id": int(row[2]),
        "team_id": int(row[3]),
        "opponent_team_id": int(row[4]),
        "location": str(row[5]),
    }

    feature_values = row[6:]
    features: Dict[str, float] = {}
    for i, name in enumerate(FEATURE_COLUMNS):
        features[name] = _safe_float(feature_values[i])

    head["features"] = features
    return head


def _pair_feature_score(team_value: float, opp_value: float) -> float:
    team_value = max(0.0, _safe_float(team_value))
    opp_value = max(0.0, _safe_float(opp_value))

    total = team_value + opp_value
    if total <= 0:
        return 50.0

    return (team_value / total) * 100.0


def _calc_attribute_score(
    attribute_name: str,
    team_features: Dict[str, float],
    opp_features: Dict[str, float],
    weights_by_attribute: Dict[str, Dict[str, float]],
) -> float:
    feature_weights = weights_by_attribute.get(attribute_name, {})
    if not feature_weights:
        return 50.0

    weighted_sum = 0.0
    weight_sum = 0.0

    for feature_name, weight in feature_weights.items():
        team_value = team_features.get(feature_name, 0.0)
        opp_value = opp_features.get(feature_name, 0.0)
        feature_score = _pair_feature_score(team_value, opp_value)

        weighted_sum += feature_score * weight
        weight_sum += weight

    if weight_sum <= 0:
        return 50.0

    return round(weighted_sum / weight_sum, 4)


def _debug_print_feature_subset(team: Dict) -> None:
    f = team["features"]
    print(
        f"[team-scores][debug] team={team['team_id']} loc={team['location']} "
        f"goals={f['goals']} shots_total={f['shots_total']} shots_on_target={f['shots_on_target']} "
        f"big_chances_created={f['big_chances_created']} dangerous_attacks={f['dangerous_attacks']} "
        f"passes={f['passes']} successful_passes={f['successful_passes']} "
        f"successful_passes_percentage={f['successful_passes_percentage']} "
        f"tackles={f['tackles']} interceptions={f['interceptions']} "
        f"duels_won={f['duels_won']} ball_possession={f['ball_possession']} "
        f"ball_safe={f['ball_safe']} shots_blocked={f['shots_blocked']} saves={f['saves']}"
    )


def _build_upsert_rows_for_fixture(
    model_id: int,
    fixture_rows: List[Tuple],
    weights_by_attribute: Dict[str, Dict[str, float]],
) -> List[Tuple]:
    if len(fixture_rows) < 2:
        return []

    rows = [_row_to_feature_dict(r) for r in fixture_rows]

    if len(rows) != 2:
        print(f"[team-scores][debug] unexpected feature row count={len(rows)}; using first 2 rows only")
        rows = rows[:2]

    team_a = rows[0]
    team_b = rows[1]

    _debug_print_feature_subset(team_a)
    _debug_print_feature_subset(team_b)

    a_attack = _calc_attribute_score("Attack", team_a["features"], team_b["features"], weights_by_attribute)
    a_progression = _calc_attribute_score("Progression", team_a["features"], team_b["features"], weights_by_attribute)
    a_pressure = _calc_attribute_score("Pressure", team_a["features"], team_b["features"], weights_by_attribute)
    a_dominance = _calc_attribute_score("Dominance", team_a["features"], team_b["features"], weights_by_attribute)
    a_defense = _calc_attribute_score("Defense", team_a["features"], team_b["features"], weights_by_attribute)
    a_possession = _calc_attribute_score("Possession", team_a["features"], team_b["features"], weights_by_attribute)

    b_attack = _calc_attribute_score("Attack", team_b["features"], team_a["features"], weights_by_attribute)
    b_progression = _calc_attribute_score("Progression", team_b["features"], team_a["features"], weights_by_attribute)
    b_pressure = _calc_attribute_score("Pressure", team_b["features"], team_a["features"], weights_by_attribute)
    b_dominance = _calc_attribute_score("Dominance", team_b["features"], team_a["features"], weights_by_attribute)
    b_defense = _calc_attribute_score("Defense", team_b["features"], team_a["features"], weights_by_attribute)
    b_possession = _calc_attribute_score("Possession", team_b["features"], team_a["features"], weights_by_attribute)

    print(
        f"[team-scores][debug] fixture={team_a['fixture_id']} "
        f"team={team_a['team_id']} attack={a_attack} progression={a_progression} "
        f"pressure={a_pressure} dominance={a_dominance} defense={a_defense} possession={a_possession}"
    )
    print(
        f"[team-scores][debug] fixture={team_b['fixture_id']} "
        f"team={team_b['team_id']} attack={b_attack} progression={b_progression} "
        f"pressure={b_pressure} dominance={b_dominance} defense={b_defense} possession={b_possession}"
    )

    return [
        (
            int(model_id),
            int(team_a["fixture_id"]),
            int(team_a["season_id"]),
            int(team_a["league_id"]),
            int(team_a["team_id"]),
            int(team_a["opponent_team_id"]),
            team_a["location"],
            a_attack,
            a_progression,
            a_pressure,
            a_dominance,
            a_defense,
            a_possession,
        ),
        (
            int(model_id),
            int(team_b["fixture_id"]),
            int(team_b["season_id"]),
            int(team_b["league_id"]),
            int(team_b["team_id"]),
            int(team_b["opponent_team_id"]),
            team_b["location"],
            b_attack,
            b_progression,
            b_pressure,
            b_dominance,
            b_defense,
            b_possession,
        ),
    ]


def build_team_attribute_scores_for_fixture(fixture_id: int) -> None:
    model_id, model_name, version, normalization_method = _load_active_model()
    weights_by_attribute = _load_model_weights(model_id)

    print(
        f"[team-scores][debug] active_model id={model_id} "
        f"name={model_name} version={version} normalization={normalization_method}"
    )
    for attr in ATTRIBUTE_NAMES:
        print(
            f"[team-scores][debug] weights[{attr}] count={len(weights_by_attribute.get(attr, {}))} "
            f"features={sorted(weights_by_attribute.get(attr, {}).keys())}"
        )

    fixture_rows = fetch_all(SQL_SELECT_FEATURE_ROWS_BY_FIXTURE, (fixture_id,))
    print(f"[team-scores][debug] feature_rows_found={len(fixture_rows)} for fixture={fixture_id}")

    if not fixture_rows:
        print(f"[team-scores] no feature rows found: fixture_id={fixture_id}")
        return

    upsert_rows = _build_upsert_rows_for_fixture(
        model_id=model_id,
        fixture_rows=fixture_rows,
        weights_by_attribute=weights_by_attribute,
    )

    if upsert_rows:
        upsert_many(SQL_UPSERT_TEAM_ATTRIBUTE_SCORES, upsert_rows)

    print(
        f"[team-scores] fixture {fixture_id}: "
        f"model={model_name} v{version} normalization={normalization_method} "
        f"score_rows={len(upsert_rows)}"
    )


def build_team_attribute_scores_for_season(season_id: int) -> None:
    fixture_rows = fetch_all(SQL_SELECT_FIXTURE_IDS_FROM_FEATURES_BY_SEASON, (season_id,))
    fixture_ids = [int(row[0]) for row in fixture_rows]

    total = 0
    for fixture_id in fixture_ids:
        build_team_attribute_scores_for_fixture(fixture_id)
        total += 1

    print(
        f"[team-scores] season {season_id}: "
        f"fixtures_processed={total}"
    )


def build_team_attribute_scores_for_current_seasons() -> None:
    fixture_rows = fetch_all(SQL_SELECT_FIXTURE_IDS_FROM_FEATURES_CURRENT_SEASONS)
    fixture_ids = [int(row[0]) for row in fixture_rows]

    total = 0
    for fixture_id in fixture_ids:
        build_team_attribute_scores_for_fixture(fixture_id)
        total += 1

    print(
        f"[team-scores] current seasons done: "
        f"fixtures_processed={total}"
    )