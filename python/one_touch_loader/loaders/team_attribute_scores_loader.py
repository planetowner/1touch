from __future__ import annotations

import json
from typing import Dict

import numpy as np
import pandas as pd

from one_touch_loader.core.db import fetch_all, upsert_many
from one_touch_loader.loaders.team_attribute_regression_trainer import (
    FEATURE_GROUPS,
    LOWER_IS_BETTER_FEATURES,
)
from one_touch_loader.loaders.team_attribute_training_features_loader import (
    get_current_big5_season_ids,
)


ALL_FEATURES = [
    feature
    for features in FEATURE_GROUPS.values()
    for feature in features
]

DISPLAY_BASE = 50.0
DISPLAY_SCALE = 15.0
DISPLAY_MIN = 5.0
DISPLAY_MAX = 95.0


UPSERT_SQL = """
INSERT INTO team_attribute_group_scores (
  model_id,
  league_id,
  season_id,
  team_id,
  attribute_group,
  raw_score,
  display_score_0_100,
  feature_contributions_json
)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  raw_score = VALUES(raw_score),
  display_score_0_100 = VALUES(display_score_0_100),
  feature_contributions_json = VALUES(feature_contributions_json)
"""


def _get_active_model_id() -> int:
    # Verified: team_attribute_regression_models has a UNIQUE(model_name)
    # constraint and exactly one is_active=1 row. No ORDER BY fallback —
    # if more than one model_name ever ends up active simultaneously, that
    # should surface here instead of being silently resolved by created_at.
    rows = fetch_all(
        """
        SELECT id
        FROM team_attribute_regression_models
        WHERE is_active = 1
        LIMIT 1
        """
    )

    if not rows:
        raise RuntimeError("No active team_attribute_regression_models row found.")

    return int(rows[0][0])


def _fetch_weights(model_id: int) -> Dict[str, Dict[str, float]]:
    rows = fetch_all(
        """
        SELECT
          attribute_group,
          feature_name,
          weight
        FROM team_attribute_regression_weights
        WHERE model_id = %s
        ORDER BY attribute_group, feature_name
        """,
        (model_id,),
    )

    if not rows:
        raise RuntimeError(f"No regression weights found for model_id={model_id}.")

    weights: Dict[str, Dict[str, float]] = {}

    for attribute_group, feature_name, weight in rows:
        weights.setdefault(str(attribute_group), {})[str(feature_name)] = float(weight)

    return weights


def _fetch_feature_dataframe(season_ids: list[int] | None = None) -> pd.DataFrame:
    cols = [
        "league_id",
        "season_id",
        "team_id",
        "matches_played",
        "points",
        "points_per_match",
        *ALL_FEATURES,
    ]

    where_sql = ""
    params: tuple = ()

    if season_ids:
        placeholders = ", ".join(["%s"] * len(season_ids))
        where_sql = f"WHERE season_id IN ({placeholders})"
        params = tuple(season_ids)

    sql = f"""
    SELECT
      {", ".join(cols)}
    FROM team_attribute_training_features
    {where_sql}
    ORDER BY league_id, season_id, team_id
    """

    rows = fetch_all(sql, params)
    df = pd.DataFrame(rows, columns=cols)

    if df.empty:
        raise RuntimeError("No rows found in team_attribute_training_features.")

    for col in ["points_per_match", *ALL_FEATURES]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    missing = df[ALL_FEATURES].isna().sum()
    missing = missing[missing > 0]

    if not missing.empty:
        raise RuntimeError(
            "Score input data contains NULL/NaN values:\n"
            + missing.to_string()
        )

    return df


def _add_league_season_zscores(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    group_keys = ["league_id", "season_id"]

    # std=0 inside a (league_id, season_id) means every team in that group has
    # the same value for that feature — verified to occur for stats Sportmonks
    # did not track in some seasons (e.g. key-passes, big-chances-created).
    # In that case the z-score is undefined; we keep it at 0.0 so the team's
    # display score is unaffected by an untracked feature.
    for feature in ALL_FEATURES:
        mean = out.groupby(group_keys)[feature].transform("mean")
        std = out.groupby(group_keys)[feature].transform(lambda s: s.std(ddof=0))

        z_col = f"{feature}_z"
        out[z_col] = (out[feature] - mean) / std.replace(0, np.nan)
        out[z_col] = out[z_col].replace([np.inf, -np.inf], np.nan).fillna(0.0)

        if feature in LOWER_IS_BETTER_FEATURES:
            out[z_col] = -out[z_col]

    return out


def _to_display_score(raw_score: float) -> float:
    display_score = DISPLAY_BASE + DISPLAY_SCALE * raw_score
    return float(max(DISPLAY_MIN, min(DISPLAY_MAX, display_score)))


def build_team_attribute_group_scores(
    model_id: int | None = None,
    season_ids: list[int] | None = None,
) -> int:
    model_id = model_id or _get_active_model_id()

    weights_by_group = _fetch_weights(model_id)
    df = _fetch_feature_dataframe(season_ids=season_ids)
    df = _add_league_season_zscores(df)

    db_rows = []

    for _, row in df.iterrows():
        league_id = int(row["league_id"])
        season_id = int(row["season_id"])
        team_id = int(row["team_id"])

        for attribute_group, features in FEATURE_GROUPS.items():
            group_weights = weights_by_group[attribute_group]

            raw_score = 0.0
            contributions = {}

            for feature in features:
                weight = float(group_weights[feature])
                z_value = float(row[f"{feature}_z"])
                raw_value = float(row[feature])
                contribution = z_value * weight

                raw_score += contribution

                contributions[feature] = {
                    "raw_value": raw_value,
                    "z_value": z_value,
                    "weight": weight,
                    "contribution": contribution,
                    "direction": (
                        "lower_is_better"
                        if feature in LOWER_IS_BETTER_FEATURES
                        else "higher_is_better"
                    ),
                }

            display_score = _to_display_score(raw_score)

            db_rows.append(
                (
                    model_id,
                    league_id,
                    season_id,
                    team_id,
                    attribute_group,
                    float(raw_score),
                    float(display_score),
                    json.dumps(contributions, ensure_ascii=False),
                )
            )

    upsert_many(UPSERT_SQL, db_rows)

    scope = "all seasons" if not season_ids else ",".join(str(x) for x in season_ids)

    print(
        f"[team-attributes] group scores built: "
        f"model_id={model_id} rows={len(db_rows)} "
        f"scope={scope} "
        f"display_formula=clamp(50 + 15 * weighted_z_score, 5, 95)"
    )

    return len(db_rows)


def build_current_team_attribute_group_scores(model_id: int | None = None) -> int:
    season_ids = get_current_big5_season_ids()

    if not season_ids:
        raise RuntimeError("No current Big 5 seasons found in seasons table.")

    return build_team_attribute_group_scores(
        model_id=model_id,
        season_ids=season_ids,
    )