from __future__ import annotations

from typing import List, Optional
from pydantic import BaseModel


class TeamOut(BaseModel):
    team_id: int
    name: str
    short_code: Optional[str] = None
    image_path: Optional[str] = None


class FixtureOut(BaseModel):
    fixture_id: int
    league_id: int
    season_id: int
    competition_type: Optional[str] = None
    round_name: Optional[str] = None
    stage_id: Optional[int] = None
    group_id: Optional[int] = None
    leg_number: Optional[int] = None

    status: str
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


class HomeResponse(BaseModel):
    favorite_team: Optional[TeamOut] = None
    following_teams: List[TeamOut] = []

    next_match: Optional[FixtureOut] = None
    last_match: Optional[FixtureOut] = None

    calendar: List[FixtureOut] = []
