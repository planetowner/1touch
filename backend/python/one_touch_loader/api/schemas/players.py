from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel


class PlayerCandidate(BaseModel):
    player_id: int
    name: str
    image: str | None


class PlayerCandidatesResponse(BaseModel):
    players: list[PlayerCandidate]


class PlayerProfile(PlayerCandidate):
    height_cm: int | None
    weight_kg: int | None
    date_of_birth: date | None
    nationality: str | None
    nationality_image: str | None
    team_id: int | None
    team_name: str | None
    team_image: str | None
    jersey_number: int | None
    squad_role: str | None
    position_group: str | None


class PlayerSeason(BaseModel):
    season_id: int
    season_name: str
    competition_id: int
    competition_name: str


class PlayerRecord(BaseModel):
    appearances: int
    starts: int
    minutes: int
    wins: int
    win_rate: float | None
    rating: float | None
    rated_matches: int


class PlayerCompetitionRecord(PlayerRecord):
    competition_id: int
    competition_name: str


class PlayerMetric(BaseModel):
    code: str
    label: str
    kind: Literal['count', 'decimal', 'pair', 'percentage']
    source: Literal['understat', 'sportmonks']
    value: float | None
    stat_type_ids: list[int]
    numerator: float | None = None
    denominator: float | None = None


class PlayerSeasonMetric(PlayerMetric):
    per90: float | None
    rank: int | None
    reference_count: int
    percentile: float | None
    observed_matches: int
    total_matches: int


class PlayerCategory(BaseModel):
    code: str
    label: str
    metrics: list[PlayerSeasonMetric]


class PlayerMatch(BaseModel):
    fixture_id: int
    starting_at: datetime
    state_id: int
    competition_name: str
    round_name: str | None
    opponent_name: str | None
    opponent_image: str | None
    result: Literal['WIN', 'DEF', 'DRAW'] | None
    home_score: int | None
    away_score: int | None
    rating: float | None
    metrics: list[PlayerMetric]


class PlayerPerformance(BaseModel):
    fixture_id: int
    round: int
    rating: float | None


class PlayerAnalysis(BaseModel):
    position_group: str | None
    categories: list[PlayerCategory]
    top_stats: list[PlayerSeasonMetric]
    reference_minimum_minutes: int
    reference_players: int
    appearances: int
    starts: int
    team_matches: int
    starting_rate: float | None
    win_rate: float | None
    performance: list[PlayerPerformance]


class PlayerCareer(PlayerRecord):
    season_name: str
    team_id: int
    team_name: str
    team_code: str | None
    team_image: str | None
    competitions: list[PlayerCompetitionRecord]


class PlayerClub(BaseModel):
    team_id: int
    team_name: str | None
    team_image: str | None
    start_date: date | None
    end_date: date | None


class PlayerClubHistoryResponse(BaseModel):
    player_id: int
    clubs: list[PlayerClub]


class PlayerHonour(BaseModel):
    team_id: int
    team_name: str | None
    team_image: str | None
    competition_id: int
    competition_name: str | None
    season_id: int
    season_name: str | None


class PlayerDetailResponse(BaseModel):
    player_id: int
    profile: PlayerProfile
    current_season_name: str | None
    current_position: str | None
    seasons: list[PlayerSeason]
    selected_season: PlayerSeason | None
    competitions: list[PlayerCompetitionRecord]
    matches: list[PlayerMatch]
    analysis: PlayerAnalysis | None
    career: list[PlayerCareer]
    clubs: list[PlayerClub]
    honours: list[PlayerHonour]


class PlayerRankingLeague(BaseModel):
    competition_id: int
    season_id: int
    season_name: str
    name: str
    available_players: int


class PlayerRank(PlayerCandidate):
    position: str | None
    rank: int
    display_score: float
    average_rating: float
    rated_matches: int


class CurrentPlayerRankingResponse(BaseModel):
    season_name: str | None
    leagues: list[PlayerRankingLeague]
    items: list[PlayerRank]
    total: int
    limit: int
    offset: int
    competition_id: int | None
    position: str | None


class PlayerWatch(PlayerCandidate):
    recent_average: float
    previous_average: float
    change: float


class PlayersToWatchResponse(BaseModel):
    items: list[PlayerWatch]
    scope: Literal['all_competitions_recent_10_appearances']
