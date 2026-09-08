from __future__ import annotations

from typing import Dict

from one_touch_loader.core.db import fetch_all, transaction
from one_touch_loader.loaders.team_attribute_common import (
    FEATURE_GROUPS,
)
from one_touch_loader.loaders.team_attribute_regression_trainer import (
    _add_competition_season_zscores,
)
from one_touch_loader.loaders.team_attribute_training_features_loader import (
    get_current_big5_season_ids,
    fetch_team_attribute_feature_dataframe,
)


# 같은 리그·시즌의 상대값을 50 중심으로 표시하는 기존 규칙이에요. 백분위나 리그 간 절대 능력이 아니에요.
DISPLAY_BASE = 50.0
DISPLAY_SCALE = 15.0
DISPLAY_MIN = 5.0
DISPLAY_MAX = 95.0


INSERT_SQL = """
INSERT INTO team_attribute_group_scores (
  model_id,
  season_id,
  team_id,
  attribute_group,
  display_score_0_100
)
VALUES (%s, %s, %s, %s, %s)
"""


def _get_active_model_id() -> int:
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


def _to_display_score(raw_score: float) -> float:
    # 극단값을 표시 범위 5~95로 제한하는 기존 환산식을 유지해요.
    display_score = DISPLAY_BASE + DISPLAY_SCALE * raw_score
    return float(max(DISPLAY_MIN, min(DISPLAY_MAX, display_score)))


def build_team_attribute_group_scores(
    model_id: int | None = None,
    season_ids: list[int] | None = None,
) -> int:
    model_id = model_id or _get_active_model_id()

    weights_by_group = _fetch_weights(model_id)
    df = fetch_team_attribute_feature_dataframe(season_ids=season_ids)

    db_rows = []

    for attribute_group, features in FEATURE_GROUPS.items():
        # 학습과 같은 누락 제외·표준화 규칙을 써요. 가중치가 0인 항목도 필수 비교 항목에 포함해요.
        group_df = _add_competition_season_zscores(df, features)
        group_weights = weights_by_group[attribute_group]
        print(
            f"[team-attributes][{attribute_group}] scored_rows={len(group_df)} "
            f"unavailable_rows={len(df) - len(group_df)}"
        )
        for _, row in group_df.iterrows():
            season_id = int(row["season_id"])
            team_id = int(row["team_id"])

            raw_score = 0.0

            for feature in features:
                # 학습 후 고정된 가중치와 상대값을 곱해 더해요. 팀별로 항목을 빼거나 가중치를 다시 나누지 않아요.
                weight = float(group_weights[feature])
                z_value = float(row[f"{feature}_z"])
                contribution = z_value * weight

                raw_score += contribution

            display_score = _to_display_score(raw_score)

            db_rows.append(
                (
                    model_id,
                    season_id,
                    team_id,
                    attribute_group,
                    float(display_score),
                )
            )

    # 미산출로 바뀐 영역의 예전 점수가 남지 않게 요청한 모델·시즌 결과를 한 트랜잭션에서 교체해요.
    delete_sql = "DELETE FROM team_attribute_group_scores WHERE model_id = %s"
    delete_params = (model_id,)
    if season_ids:
        delete_sql += f" AND season_id IN ({', '.join(['%s'] * len(season_ids))})"
        delete_params += tuple(season_ids)
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(delete_sql, delete_params)
            if db_rows:
                # 같은 범위를 먼저 지웠으므로 중복 갱신 없이 새 결과만 넣어요.
                cur.executemany(INSERT_SQL, db_rows)

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
