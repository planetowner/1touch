from datetime import datetime
from typing import Literal
from pydantic import BaseModel, Field


class NewsArticleOut(BaseModel):
    article_id: int
    title: str
    source: str
    url: str
    image_url: str | None
    published_at: datetime


class TeamNewsResponse(BaseModel):
    team_id: int
    language: Literal["ko", "en"]
    items: list[NewsArticleOut] = Field(max_length=3, description="선택한 팀의 최근 14일 기사 중 최신 3개예요. 부족하면 있는 만큼만 반환해요.")
