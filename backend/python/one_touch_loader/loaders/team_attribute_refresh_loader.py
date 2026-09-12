from __future__ import annotations

from one_touch_loader.loaders.team_stats_loader import (
    refresh_fixture_team_stats_for_current_seasons,
)
from one_touch_loader.loaders.team_attribute_training_features_loader import (
    build_current_team_attribute_training_features,
    get_current_big5_season_ids,
)
from one_touch_loader.loaders.team_attribute_scores_loader import (
    build_current_team_attribute_group_scores,
)


def refresh_current_team_attributes() -> dict:
    """
    현재 시즌의 팀 특성 점수를 갱신해요.

    회귀 모델을 다시 학습하지 않아요.
    활성 회귀 모델을 현재 Big 5 시즌에 적용하기만 해요.

    실행 순서는 다음과 같아요.
    1. 현재 경기의 팀 통계를 갱신해요.
    2. 현재 팀 특성값을 다시 만들어요.
    3. 현재 팀 특성 그룹 점수를 다시 만들어요.
    """

    current_season_ids = get_current_big5_season_ids()

    if not current_season_ids:
        raise RuntimeError("No current Big 5 seasons found in seasons table.")

    refresh_fixture_team_stats_for_current_seasons(only_status="past")

    feature_rows = build_current_team_attribute_training_features()

    score_rows = build_current_team_attribute_group_scores()

    result = {
        "current_season_ids": current_season_ids,
        "feature_rows": feature_rows,
        "score_rows": score_rows,
        "updated_fixtures": False,
    }

    print(
        "[team-attributes] refresh-current done: "
        f"season_ids={current_season_ids} "
        f"feature_rows={feature_rows} "
        f"score_rows={score_rows} "
        "updated_fixtures=False"
    )

    return result
