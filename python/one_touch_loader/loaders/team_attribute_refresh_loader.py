from __future__ import annotations

from one_touch_loader.loaders.big5_bootstrap import run_big5_bootstrap
from one_touch_loader.loaders.standings_loader import refresh_current_standings
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


BIG5_NAMES = ["Premier League", "La Liga", "Serie A", "Bundesliga", "Ligue 1"]


def refresh_current_team_attributes(update_fixtures: bool = True) -> dict:
    """
    Refresh current-season team attribute scores.

    This does NOT retrain regression.
    It only applies the active regression model to current Big 5 seasons.

    Steps:
      1. update current fixtures/seasons/teams, optional
      2. rebuild current standings
      3. refresh current fixture team stats
      4. rebuild current team attribute features
      5. rebuild current team attribute group scores
    """

    if update_fixtures:
        run_big5_bootstrap(BIG5_NAMES)

    current_season_ids = get_current_big5_season_ids()

    if not current_season_ids:
        raise RuntimeError("No current Big 5 seasons found in seasons table.")

    refresh_current_standings()

    refresh_fixture_team_stats_for_current_seasons(only_status="past")

    feature_rows = build_current_team_attribute_training_features()

    score_rows = build_current_team_attribute_group_scores()

    result = {
        "current_season_ids": current_season_ids,
        "feature_rows": feature_rows,
        "score_rows": score_rows,
        "updated_fixtures": update_fixtures,
    }

    print(
        "[team-attributes] refresh-current done: "
        f"season_ids={current_season_ids} "
        f"feature_rows={feature_rows} "
        f"score_rows={score_rows} "
        f"updated_fixtures={update_fixtures}"
    )

    return result