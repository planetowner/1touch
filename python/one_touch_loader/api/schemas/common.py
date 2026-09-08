from __future__ import annotations

from datetime import date
from typing import List, Optional
from pydantic import BaseModel


class TeamOut(BaseModel):
    team_id: int
    name: str
    short_code: Optional[str] = None
    image_path: Optional[str] = None


class FixtureOut(BaseModel):
    fixture_id: int
    competition_id: int
    season_id: int
    competition_type: str
    round_name: Optional[str] = None
    stage_id: int
    stage_name: str
    round_id: Optional[int] = None
    group_id: Optional[int] = None
    aggregate_id: Optional[int] = None
    leg: str
    venue_id: Optional[int] = None
    state_id: int
    state_code: str
    state_name: str

    status: Optional[str] = None
    starting_at: Optional[str] = None

    home_team_id: int
    away_team_id: int
    home_score: Optional[int] = None
    away_score: Optional[int] = None
    home_penalty_score: Optional[int] = None
    away_penalty_score: Optional[int] = None

    home_team_name: Optional[str] = None
    away_team_name: Optional[str] = None
    home_team_logo: Optional[str] = None
    away_team_logo: Optional[str] = None


class StandingRowOut(BaseModel):
    position: int
    # Official position at the previous completed round, and the resulting
    # movement (prev_position - position; positive = moved up). None when there
    # is no previous round or it does not apply (euro group/league-phase).
    prev_position: Optional[int] = None
    rank_delta: Optional[int] = None
    team_id: int
    team_name: Optional[str] = None
    team_logo: Optional[str] = None

    matches_played: int
    won: int
    draw: int
    lost: int
    goals_for: int
    goals_against: int
    goal_diff: int
    points: int

    last5_form: List[str] = []


class BestElevenPlayerOut(BaseModel):
    slot_key: str
    slot_index: int
    player_id: int
    player_name: Optional[str] = None
    player_image: Optional[str] = None
    position_name: Optional[str] = None
    detailed_position_name: Optional[str] = None
    starts: int = 0
    total_minutes: int = 0


class BestElevenFormationOut(BaseModel):
    formation: str
    matches_used: int
    total_valid_matches: int
    usage_percentage: float
    is_default: bool


class BestElevenResponse(BaseModel):
    formation: str
    matches_used: int
    total_valid_matches: int
    usage_percentage: float
    formations: List[BestElevenFormationOut] = []
    players: List[BestElevenPlayerOut] = []








class CurrentFormPointOut(BaseModel):
    round_no: int
    match_date: Optional[str] = None
    cumulative_points: int


class CurrentFormSeriesOut(BaseModel):
    team_id: int
    team_name: Optional[str] = None
    team_short_code: Optional[str] = None
    team_logo: Optional[str] = None
    league_id: int
    season_id: int
    season_name: str
    season_starting_at: Optional[str] = None
    season_ending_at: Optional[str] = None
    is_current: bool
    points: List[CurrentFormPointOut] = []


class CurrentFormResponse(BaseModel):
    current: CurrentFormSeriesOut
    comparison: CurrentFormSeriesOut
    max_round: int
    max_points: int


class CurrentFormOptionOut(BaseModel):
    team_id: int
    team_name: Optional[str] = None
    team_short_code: Optional[str] = None
    team_logo: Optional[str] = None
    league_id: int
    season_id: int
    season_name: str
    season_starting_at: Optional[str] = None
    season_ending_at: Optional[str] = None
    rounds_available: int
    latest_round: int


class CurrentFormOptionsResponse(BaseModel):
    items: List[CurrentFormOptionOut] = []
    limit: int


class TransferOut(BaseModel):
    transfer_id: int
    player_id: int
    player_name: Optional[str] = None
    player_image: Optional[str] = None
    direction: str                          # "in" 또는 "out"
    other_team_id: Optional[int] = None
    other_team_name: Optional[str] = None
    display_type: Optional[str] = None      # "Loan", "Free Agent", "€8.5M" 같은 표시값
    amount: Optional[int] = None
    transfer_date: Optional[str] = None


class TeamTransfersResponse(BaseModel):
    window_key: str                         # 예: "2026 winter"
    transfers_in: List[TransferOut] = []
    transfers_out: List[TransferOut] = []


class HomeResponse(BaseModel):
    favorite_team: Optional[TeamOut] = None
    following_teams: List[TeamOut] = []

    next_match: Optional[FixtureOut] = None
    last_match: Optional[FixtureOut] = None

    calendar: List[FixtureOut] = []
