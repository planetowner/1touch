from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class IndicatorScore(BaseModel):
    raw_score: float | None
    percentile: float | None = Field(ge=0, le=100)
    grade: Literal["Very Poor", "Poor", "Fair", "Good", "Excellent", "Very Good"] | None
    band: int | None = Field(ge=0, le=4)
    reference_count: int
    unavailable_reason: str | None


class FormScore(IndicatorScore):
    rated_matches: int
    appearances: int
    last_match_at: datetime | None
    season_rating: float | None


class WageEfficiencyScore(IndicatorScore):
    season_rating: float | None
    minutes_played: int
    rated_minutes: int
    available_minutes: int
    minutes_share: float | None
    actual_weekly_wage_eur: int | None
    # 기존 응답 필드는 유지하지만, 확정 모델은 급여 대신 평점·출전 비중을 예측하므로 null이에요.
    expected_weekly_wage_eur: float | None
    rated_matches: int
    expected_rating: float | None = None
    expected_minutes_share: float | None = None
    rating_sd: float | None = None
    minutes_share_sd: float | None = None
    rating_standardized_difference: float | None = None
    minutes_standardized_difference: float | None = None
    fair_boundary: float | None = None
    very_boundary: float | None = None


class PlayerIndicatorsResponse(BaseModel):
    player_id: int
    team_id: int
    season_id: int
    season_name: str
    competition_id: int
    position_group_id: int | None
    as_of: datetime
    comparison_scope: Literal["current_season_big_five_all_positions"]
    form: FormScore
    cost_effectiveness: WageEfficiencyScore
    form_calibration: dict | None
