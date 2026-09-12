from __future__ import annotations

import json

import numpy as np
import pandas as pd
from sklearn.linear_model import Ridge
from sklearn.metrics import r2_score

from one_touch_loader.core.db import transaction
from one_touch_loader.loaders.team_attribute_common import (
    FEATURE_GROUPS,
    LOWER_IS_BETTER_FEATURES,
)
from one_touch_loader.loaders.team_attribute_training_features_loader import (
    TARGET_SEASON_IDS as TRAINING_SEASON_IDS,
    fetch_team_attribute_feature_dataframe,
)


# 5개 영역을 각각 시즌 경기당 승점에 맞춰 학습해요. 순수한 영역별 능력을 검증한 정답은 아니에요.
MODEL_NAME = "team_attribute_ridge_v1"
MODEL_VERSION = 1
TARGET_NAME = "points_per_match"
TRAINING_SCOPE = "big5_2021_2022_to_2025_2026"
NORMALIZATION_SCOPE = "competition_season_zscore"
REGRESSION_METHOD = "ridge"
# Ridge는 서로 비슷한 통계의 계수가 지나치게 커지는 것을 억제해요. 기존 강도 1.0을 유지해요.
ALPHA = 1.0




def _fetch_training_dataframe() -> pd.DataFrame:
    df = fetch_team_attribute_feature_dataframe(TRAINING_SEASON_IDS, include_target=True)

    # 미제공 특성은 NULL로 받아 영역별로 제외하고, 학습 목표의 누락만 전체 오류로 처리해요.
    missing = df[["points_per_match"]].isna().sum()
    missing = missing[missing > 0]

    if not missing.empty:
        raise RuntimeError(
            "Training data contains NULL/NaN values:\n"
            + missing.to_string()
        )

    return df


def _add_competition_season_zscores(df: pd.DataFrame, features: list[str]) -> pd.DataFrame:
    # 한 영역의 고정 항목이 모두 계산된 팀·시즌만 비교해요. 다른 영역의 누락은 영향을 주지 않아요.
    out = df.dropna(subset=features).copy()
    group_keys = ["competition_id", "season_id"]

    # (값 - 평균) / 표준편차로 단위를 맞춰 같은 리그·시즌 안의 상대적 수준을 비교해요.
    # 실제 값이 모두 같아 표준편차가 0이면 기존처럼 상대값을 0으로 둬요. 미제공을 0으로 채우지는 않아요.
    for feature in features:
        mean = out.groupby(group_keys)[feature].transform("mean")
        std = out.groupby(group_keys)[feature].transform(lambda s: s.std(ddof=0))

        z_col = f"{feature}_z"
        out[z_col] = (out[feature] - mean) / std.replace(0, np.nan)
        out[z_col] = out[z_col].replace([np.inf, -np.inf], np.nan).fillna(0.0)

        # 상대에게 허용한 값은 부호를 바꿔 높은 상대값이 좋은 수비를 뜻하게 해요.
        if feature in LOWER_IS_BETTER_FEATURES:
            out[z_col] = -out[z_col]

    return out


def _persist_model_atomically(
    *,
    rows_used: int,
    avg_r2_score: float,
    notes: dict,
    build_weight_rows: callable,
) -> int:
    """활성 모델을 끄고 새 모델 행과 모든 특성 가중치를 한 트랜잭션에서 저장해요.

    활성 모델과 가중치가 서로 어긋나는 순간이 없게 해요. 조회 함수
    _get_active_model_id는 테이블 전체에서 활성 모델이 하나라고 봐요.
    따라서 같은 model_name만이 아니라 모든 활성 행을 먼저 끄고,
    is_active=1인 새 모델 하나를 넣어요.

    새 model_id가 정해지면 `build_weight_rows(model_id)`가 가중치 튜플 목록을 반환해요.
    """
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE team_attribute_regression_models
                SET is_active = 0
                WHERE is_active = 1
                """
            )

            cur.execute(
                """
                DELETE FROM team_attribute_regression_models
                WHERE model_name = %s
                  AND model_version = %s
                """,
                (MODEL_NAME, MODEL_VERSION),
            )

            cur.execute(
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

            model_id = int(cur.lastrowid)

            weight_rows = build_weight_rows(model_id)

            if weight_rows:
                cur.executemany(
                    """
                    INSERT INTO team_attribute_regression_weights (
                      model_id,
                      attribute_group,
                      feature_name,
                      coefficient,
                      weight
                    )
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    weight_rows,
                )

    return model_id


def _weights_from_coefficients(coefficients: np.ndarray) -> tuple[list[float], list[float]]:
    # 지표가 좋아질 때 표시 점수가 낮아지지 않게 음수 계수를 0으로 바꾸고, 나머지 합을 1로 맞춰요.
    # 사용자가 유지하기로 한 기존 방식이에요. 이 후처리로 표시 점수는 학습한 회귀식과 달라져요.
    positive_coefficients = [max(float(coef), 0.0) for coef in coefficients]
    total_positive = sum(positive_coefficients)

    if total_positive <= 0:
        raise RuntimeError(
            "All coefficients in a feature group are non-positive — cannot "
            "build non-negative display weights. Inspect the trained model "
            "or feature definitions before continuing."
        )

    weights = [coef / total_positive for coef in positive_coefficients]
    return positive_coefficients, weights


def train_team_attribute_regression_weights() -> int:
    df = _fetch_training_dataframe()

    group_results = {}

    for attribute_group, features in FEATURE_GROUPS.items():
        group_df = _add_competition_season_zscores(df, features)
        z_features = [f"{feature}_z" for feature in features]
        X = group_df[z_features].astype(float).to_numpy()
        y = group_df[TARGET_NAME].astype(float).to_numpy()

        # 영역별 통계로 시즌 경기당 승점을 설명하는 계수를 학습해요. 부분 경기 수도 가중치에 추가하지 않아요.
        model = Ridge(alpha=ALPHA, fit_intercept=True)
        model.fit(X, y)

        # 기존 R²는 학습 자료에 대한 적합도예요. 다른 시즌 성능이나 후처리한 표시 점수의 검증값은 아니에요.
        predictions = model.predict(X)
        group_r2 = float(r2_score(y, predictions))
        coefficients = model.coef_

        positive_coefficients, weights = _weights_from_coefficients(coefficients)

        group_results[attribute_group] = {
            "rows_used": len(group_df),
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
        }

    avg_r2_score = float(
        np.mean([result["r2_score"] for result in group_results.values()])
    )

    def _build_weight_rows(model_id: int) -> list[tuple]:
        rows: list[tuple] = []
        for attribute_group, features in FEATURE_GROUPS.items():
            result = group_results[attribute_group]
            for feature in features:
                rows.append(
                    (
                        model_id,
                        attribute_group,
                        feature,
                        float(result["coefficients"][feature]),
                        float(result["weights"][feature]),
                    )
                )
        return rows

    model_id = _persist_model_atomically(
        rows_used=len(df),
        avg_r2_score=avg_r2_score,
        notes={
            # 계수·가중치는 가중치 테이블에 두고, 영역별 학습 진단값만 남겨요.
            "group_results": {
                group: {key: result[key] for key in ("rows_used", "intercept", "r2_score")}
                for group, result in group_results.items()
            },
        },
        build_weight_rows=_build_weight_rows,
    )

    print(
        f"[team-attributes] regression trained: "
        f"model_id={model_id} rows_used={len(df)} avg_r2={avg_r2_score:.6f}"
    )

    for group, result in group_results.items():
        print(
            f"[team-attributes][{group}] rows_used={result['rows_used']} "
            f"unavailable_rows={len(df) - result['rows_used']} r2={result['r2_score']:.6f}"
        )
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
