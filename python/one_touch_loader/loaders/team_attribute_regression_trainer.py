from __future__ import annotations

import json
from typing import Dict, List

import numpy as np
import pandas as pd
from sklearn.linear_model import Ridge
from sklearn.metrics import r2_score

from one_touch_loader.core.db import fetch_all, execute, upsert_many


MODEL_NAME = "team_attribute_ridge_v1"
MODEL_VERSION = 1
TARGET_NAME = "points_per_match"
TRAINING_SCOPE = "big5_2020_2021_to_2024_2025"
NORMALIZATION_SCOPE = "league_season_zscore"
REGRESSION_METHOD = "ridge"
ALPHA = 1.0


TRAINING_SEASON_IDS = [
    17420, 18378, 19734, 21646, 23614,
    17361, 18444, 19744, 21795, 23744,
    17160, 18441, 19745, 21779, 23643,
    17488, 18576, 19806, 21818, 23746,
    17480, 18462, 19799, 21694, 23621,
]


FEATURE_GROUPS: Dict[str, List[str]] = {
    "possession_build_up": [
        "ball_possession_avg",
        "ball_safe_per_match",
        "passes_per_match",
        "pass_accuracy",
    ],
    "attacking_threat": [
        "dangerous_attacks_per_match",
        "total_crosses_per_match",
        "cross_accuracy",
        "dribble_attempts_per_match",
        "dribble_success_rate",
    ],
    "chance_creation": [
        "corners_per_match",
        "key_passes_per_match",
        "big_chances_created_per_match",
    ],
    "finishing": [
        "shots_insidebox_per_match",
        "conversion_rate",
        "shots_on_target_per_match",
        "shot_accuracy",
    ],
    "defending": [
        "goals_against_per_match",
        "shots_on_target_against_per_match",
        "shots_insidebox_against_per_match",
        "big_chances_against_per_match",
        "dangerous_attacks_against_per_match",
    ],
}


LOWER_IS_BETTER_FEATURES = {
    "goals_against_per_match",
    "shots_on_target_against_per_match",
    "shots_insidebox_against_per_match",
    "big_chances_against_per_match",
    "dangerous_attacks_against_per_match",
}


ALL_FEATURES = [
    feature
    for features in FEATURE_GROUPS.values()
    for feature in features
]


def _fetch_training_dataframe() -> pd.DataFrame:
    cols = [
        "league_id",
        "season_id",
        "team_id",
        "matches_played",
        "points",
        "points_per_match",
        *ALL_FEATURES,
    ]

    placeholders = ", ".join(["%s"] * len(TRAINING_SEASON_IDS))

    sql = f"""
    SELECT
      {", ".join(cols)}
    FROM team_attribute_training_features
    WHERE season_id IN ({placeholders})
    ORDER BY league_id, season_id, team_id
    """

    rows = fetch_all(sql, tuple(TRAINING_SEASON_IDS))
    df = pd.DataFrame(rows, columns=cols)

    if df.empty:
        raise RuntimeError("No rows found in team_attribute_training_features.")

    for col in ["points_per_match", *ALL_FEATURES]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    missing = df[["points_per_match", *ALL_FEATURES]].isna().sum()
    missing = missing[missing > 0]

    if not missing.empty:
        raise RuntimeError(
            "Training data contains NULL/NaN values:\n"
            + missing.to_string()
        )

    return df


def _add_league_season_zscores(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    group_keys = ["league_id", "season_id"]

    for feature in ALL_FEATURES:
        mean = out.groupby(group_keys)[feature].transform("mean")
        std = out.groupby(group_keys)[feature].transform(lambda s: s.std(ddof=0))

        z_col = f"{feature}_z"
        out[z_col] = (out[feature] - mean) / std.replace(0, np.nan)
        out[z_col] = out[z_col].replace([np.inf, -np.inf], np.nan).fillna(0.0)

        # Defensive "against" features are lower-is-better.
        # Flip them so higher z means better defending.
        if feature in LOWER_IS_BETTER_FEATURES:
            out[z_col] = -out[z_col]

    return out


def _create_model_row(rows_used: int, avg_r2_score: float, notes: dict) -> int:
    execute(
        """
        UPDATE team_attribute_regression_models
        SET is_active = 0
        WHERE model_name = %s
        """,
        (MODEL_NAME,),
    )

    execute(
        """
        DELETE FROM team_attribute_regression_models
        WHERE model_name = %s
          AND model_version = %s
        """,
        (MODEL_NAME, MODEL_VERSION),
    )

    execute(
        """
        INSERT INTO team_attribute_regression_models (
          model_name,
          model_version,
          target_name,
          training_scope,
          normalization_scope,
          regression_method,
          alpha,
          rows_used,
          r2_score,
          notes,
          is_active
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 1)
        """,
        (
            MODEL_NAME,
            MODEL_VERSION,
            TARGET_NAME,
            TRAINING_SCOPE,
            NORMALIZATION_SCOPE,
            REGRESSION_METHOD,
            ALPHA,
            rows_used,
            avg_r2_score,
            json.dumps(notes, ensure_ascii=False),
        ),
    )

    model_rows = fetch_all(
        """
        SELECT id
        FROM team_attribute_regression_models
        WHERE model_name = %s
          AND model_version = %s
        """,
        (MODEL_NAME, MODEL_VERSION),
    )

    if not model_rows:
        raise RuntimeError("Failed to create regression model row.")

    return int(model_rows[0][0])


def _weights_from_coefficients(coefficients: np.ndarray) -> tuple[list[float], list[float]]:
    positive_coefficients = [max(float(coef), 0.0) for coef in coefficients]
    total_positive = sum(positive_coefficients)

    if total_positive > 0:
        weights = [coef / total_positive for coef in positive_coefficients]
    else:
        # Fallback. This should be rare.
        # If all coefficients are negative, use equal weights instead of producing all zeros.
        n = len(coefficients)
        weights = [1.0 / n for _ in range(n)]

    return positive_coefficients, weights


def train_team_attribute_regression_weights() -> int:
    df = _fetch_training_dataframe()
    df = _add_league_season_zscores(df)

    y = df[TARGET_NAME].astype(float).to_numpy()

    group_results = {}
    weight_rows = []

    for attribute_group, features in FEATURE_GROUPS.items():
        z_features = [f"{feature}_z" for feature in features]
        X = df[z_features].astype(float).to_numpy()

        model = Ridge(alpha=ALPHA, fit_intercept=True)
        model.fit(X, y)

        predictions = model.predict(X)
        group_r2 = float(r2_score(y, predictions))
        coefficients = model.coef_

        positive_coefficients, weights = _weights_from_coefficients(coefficients)

        group_results[attribute_group] = {
            "features": features,
            "intercept": float(model.intercept_),
            "r2_score": group_r2,
            "coefficients": {
                feature: float(coef)
                for feature, coef in zip(features, coefficients)
            },
            "positive_coefficients": {
                feature: float(pos_coef)
                for feature, pos_coef in zip(features, positive_coefficients)
            },
            "weights": {
                feature: float(weight)
                for feature, weight in zip(features, weights)
            },
            "lower_is_better_features": [
                feature
                for feature in features
                if feature in LOWER_IS_BETTER_FEATURES
            ],
        }

    avg_r2_score = float(
        np.mean([result["r2_score"] for result in group_results.values()])
    )

    model_id = _create_model_row(
        rows_used=len(df),
        avg_r2_score=avg_r2_score,
        notes={
            "description": (
                "Ridge regression trained per attribute group. "
                "Features are z-scored within each league-season. "
                "Lower-is-better defensive features are sign-flipped after z-score. "
                "For UI attribute scoring, negative coefficients are ignored and "
                "positive coefficients are normalized into non-negative weights."
            ),
            "feature_groups": FEATURE_GROUPS,
            "lower_is_better_features": sorted(LOWER_IS_BETTER_FEATURES),
            "group_results": group_results,
        },
    )

    for attribute_group, features in FEATURE_GROUPS.items():
        result = group_results[attribute_group]

        for feature in features:
            coef = result["coefficients"][feature]
            pos_coef = result["positive_coefficients"][feature]
            weight = result["weights"][feature]

            weight_rows.append(
                (
                    model_id,
                    attribute_group,
                    feature,
                    float(coef),
                    float(pos_coef),
                    float(weight),
                )
            )

    upsert_many(
        """
        INSERT INTO team_attribute_regression_weights (
          model_id,
          attribute_group,
          feature_name,
          coefficient,
          positive_coefficient,
          weight
        )
        VALUES (%s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
          coefficient = VALUES(coefficient),
          positive_coefficient = VALUES(positive_coefficient),
          weight = VALUES(weight)
        """,
        weight_rows,
    )

    print(
        f"[team-attributes] regression trained: "
        f"model_id={model_id} rows_used={len(df)} avg_r2={avg_r2_score:.6f}"
    )

    for group, result in group_results.items():
        print(f"[team-attributes][{group}] r2={result['r2_score']:.6f}")
        for feature in FEATURE_GROUPS[group]:
            coef = result["coefficients"][feature]
            pos_coef = result["positive_coefficients"][feature]
            weight = result["weights"][feature]
            direction = (
                "lower_is_better"
                if feature in LOWER_IS_BETTER_FEATURES
                else "higher_is_better"
            )
            print(
                f"  {feature}: "
                f"coef={coef:.8f}, "
                f"positive_coef={pos_coef:.8f}, "
                f"weight={weight:.8f}, "
                f"direction={direction}"
            )

    return model_id