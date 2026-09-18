from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class PlayerRatingReferenceOut(BaseModel):
    start_season_name: str
    end_season_name: str
    minimum_rated_matches: int
    sample_count: int
    frozen_at: datetime


class PlayerRankingOut(BaseModel):
    rank: int = Field(description="반올림 전 평균 평점 순위. 평균도 같으면 공동 순위예요.")
    player_id: int
    player_name: str
    player_image: str | None
    rated_matches: int
    average_rating: float
    percentile_score: float = Field(description="저장된 백분위. 조회한 선수 목록으로 다시 환산하지 않아요.")
    display_score: float = Field(description="소수점 한 자리 표시용 점수예요.")
    updated_at: datetime


class PlayerRankingsResponse(BaseModel):
    competition_id: int
    season_id: int
    season_name: str
    method: Literal["fixed_historical_percentile"] = "fixed_historical_percentile"
    reference: PlayerRatingReferenceOut
    total: int
    limit: int
    offset: int
    items: list[PlayerRankingOut]
