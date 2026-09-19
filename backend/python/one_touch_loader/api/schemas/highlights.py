from datetime import datetime
from typing import Literal
from pydantic import BaseModel, Field


class HighlightTeam(BaseModel):
    team_id: int | None
    name: str


class HighlightMatch(BaseModel):
    match_key: str
    fixture_id: int | None = Field(description="Sportmonks 경기 ID예요. DFB 공식 기록으로 확인한 경기는 null이에요.")
    competition_key: str
    competition_name: str
    season_name: str
    starting_at: datetime
    home: HighlightTeam
    away: HighlightTeam
    record_source: str
    record_url: str


class HighlightOut(BaseModel):
    video_id: str
    video_url: str
    title: str
    thumbnail_url: str | None
    published_at: datetime
    duration_seconds: int
    channel_id: str
    channel_name: str
    source_type: Literal["club", "competition"]
    is_extended: bool
    embeddable: bool = Field(description="현재 앱은 YouTube를 외부에서 열어요. false여도 외부 재생 가능한 영상은 포함돼요.")
    match: HighlightMatch


class TeamHighlightsResponse(BaseModel):
    team_id: int
    viewer_country: str = Field(description="언어·국적과 별개인 실제 시청 국가의 ISO 2자리 코드예요.")
    updated_at: datetime | None
    items: list[HighlightOut] = Field(description="국가 제한을 통과한 서로 다른 최근 경기 최대 3개예요. 부족하면 있는 만큼만 반환해요.")


class FixtureHighlightsResponse(BaseModel):
    fixture_id: int
    viewer_country: str | None = Field(description="null이면 국가별 재생 제한은 외부 YouTube에서 처리해요.")
    updated_at: datetime | None
    items: list[HighlightOut] = Field(max_length=1, description="해당 경기의 공식 영상 최대 1개예요. 조건에 맞는 영상이 없으면 빈 목록이에요.")
