from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class PlayerRatingReferenceOut(BaseModel):
    start_season_name: str
    end_season_name: str
    minimum_rated_matches: int = Field(description="각 리그·시즌 중반 이후의 최소 평점 경기 수예요.")
    early_season_minimum_rated_matches: Literal[1] = 1
    competition_ids: list[int]
    sample_count: int
    updated_at: datetime


class PlayerRankingOut(BaseModel):
    rank: int = Field(description="반올림 전 평균 평점 순위. 평균도 같으면 공동 순위예요.")
    player_id: int
    player_name: str
    player_image: str | None
    rated_matches: int
    average_rating: float
    percentile_score: float = Field(description="저장된 백분위. 조회한 선수 목록으로 다시 환산하지 않아요.")
    display_score: float = Field(description="백분위를 고정 환산한 1Touch 점수예요. 상위 1%는 90점이며 환산 후 소수점 한 자리로 반올림해요.")
    updated_at: datetime


class PlayerRankingsResponse(BaseModel):
    competition_id: int
    season_id: int
    season_name: str
    method: Literal["cumulative_all_leagues_percentile"] = "cumulative_all_leagues_percentile"
    reference: PlayerRatingReferenceOut
    total: int
    limit: int
    offset: int
    items: list[PlayerRankingOut]
