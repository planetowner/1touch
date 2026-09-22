from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class BracketTeam(BaseModel):
    team_id: int
    name: str
    short_code: str | None
    logo: str | None


class BracketSlot(BaseModel):
    slot: Literal['home', 'away']
    team_id: int | None
    label: str
    source_tie_id: str | None


class BracketFixture(BaseModel):
    fixture_id: int
    home_team_id: int | None
    away_team_id: int | None
    home_score: int | None
    away_score: int | None
    home_penalty_score: int | None
    away_penalty_score: int | None
    starting_at: datetime | None
    state_id: int
    state: str
    leg: Literal['1/1', '1/2', '2/2']
    source_leg: str
    aggregate_id: int | None
    detail_available: bool


class BracketTie(BaseModel):
    tie_id: str
    stage_id: int
    stage_key: str
    format: Literal['single_match', 'two_leg']
    legs_complete: bool
    slots: list[BracketSlot]
    fixtures: list[BracketFixture]
    aggregate_score: list[int] | None
    winner_team_id: int | None
    winner_basis: str | None
    status: Literal['scheduled', 'live', 'completed', 'unresolved']
    next_tie_id: str | None


class BracketStage(BaseModel):
    stage_id: int
    key: str
    name: str
    order: int
    ties: list[BracketTie]


class BracketEdge(BaseModel):
    from_tie_id: str
    to_tie_id: str
    to_slot: Literal['home', 'away']
    source: Literal['results', 'provider_bracket']


class TournamentBracketResponse(BaseModel):
    competition_id: int
    season_id: int
    season_name: str
    scope: Literal['main_knockout', 'cup']
    source: Literal['sportmonks']
    fetched_at: datetime
    input_sha256: str
    status: Literal['not_published', 'in_progress', 'completed']
    path_status: Literal['not_published', 'partial', 'complete']
    champion_team_id: int | None
    stages: list[BracketStage]
    teams: dict[str, BracketTeam]
    edges: list[BracketEdge]
    unlinked_tie_ids: list[str]
    issues: list[dict]
