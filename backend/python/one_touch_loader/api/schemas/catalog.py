from pydantic import BaseModel

from .common import TeamOut


class CompetitionOut(BaseModel):
    competition_id: int
    name: str
    image_path: str | None


class SeasonOut(BaseModel):
    season_id: int
    competition_id: int
    name: str
    is_current: bool


class TeamSeasonOut(BaseModel):
    team_id: int
    season_id: int
    competition_id: int


class CatalogResponse(BaseModel):
    teams: list[TeamOut]
    competitions: list[CompetitionOut]
    seasons: list[SeasonOut]
    memberships: list[TeamSeasonOut]
