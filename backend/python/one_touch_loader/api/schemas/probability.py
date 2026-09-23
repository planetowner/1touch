from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ProbabilityEvent(BaseModel):
    event: str
    competition_id: int
    category: str
    probability: float = Field(ge=0, le=1)
    change_pp: float | None = None
    entropy: float | None = None


class PositionProbability(BaseModel):
    position: int
    probability: float = Field(ge=0, le=1)


class PointsInterval(BaseModel):
    lower: int
    upper: int
    target_coverage: float
    included_probability: float
    method: Literal["equal_tail"]
    unit: Literal["points"]


class ProjectedPoints(BaseModel):
    mean: float
    likely_range: PointsInterval
    change_points: float | None = None


class ProbabilityHistoryPoint(BaseModel):
    as_of: datetime
    kind: Literal["reconstructed", "daily_calculation", "observed_calculation"]
    played: int
    events: list[ProbabilityEvent]
    expected_points: float


class WhatIfFixture(BaseModel):
    fixture_id: int
    home_team_id: int
    away_team_id: int
    starting_at: str
    round_name: str | None
    probabilities: list[float] = Field(description="홈승·무승부·원정승 순서예요.", min_length=3, max_length=3)


class WhatIfScenario(BaseModel):
    outcome: Literal["win", "draw", "loss"] = Field(description="조회한 팀 기준 결과예요.")
    events: list[ProbabilityEvent]
    positions: list[PositionProbability]
    projected_points: ProjectedPoints


class WhatIf(BaseModel):
    fixture: WhatIfFixture
    scenarios: list[WhatIfScenario]


class ProbabilityComparison(BaseModel):
    basis: Literal['previous_league_fixture_pre_match_snapshot', 'previous_european_fixture_pre_match_snapshot']
    available: bool
    as_of: datetime | None = Field(description='실제 비교에 사용한 경기 전 예측의 기준 시각이에요.')
    fixture_at: datetime | None = Field(description='이번 예측에 반영된 직전 해당 대회 경기의 킥오프예요.')


class EuropeanTitleProbability(BaseModel):
    event: Literal['ucl_winner', 'uel_winner', 'uecl_winner']
    competition_id: int
    season_id: int
    season_name: str
    probability: float = Field(ge=0, le=1)
    as_of: datetime
    model_id: str
    simulations: int
    probability_method: str
    strength_source_url: str
    coefficient_source_url: str
    sampling_standard_error_pp: float
    change_pp: float | None
    comparison: ProbabilityComparison
    validation: dict
    limitations: list[str]


class TeamProbabilityResponse(BaseModel):
    team_id: int
    team_name: str
    competition_id: int
    season_id: int
    season_name: str
    as_of: datetime
    cutoff: Literal["utc_day_start", "observed_state"]
    calculated_at: datetime
    model_id: str
    strength_source: Literal["clubelo"]
    probability_method: str = Field(description="ClubElo의 공식 확률이 아니라 1Touch가 학습한 변환 모델이에요.")
    simulations: int
    max_sampling_standard_error_pp: float
    validation: dict
    elo: float
    current_points: int
    played: int
    maximum_points: int
    positions: list[PositionProbability]
    projected_points: ProjectedPoints
    comparison: ProbabilityComparison
    events: list[ProbabilityEvent]
    cards: list[ProbabilityEvent]
    european_title: EuropeanTitleProbability | None = None
    history: list[ProbabilityHistoryPoint]
    what_if: WhatIf | None
    limitations: list[str]
    pending_outcomes: list[str]
