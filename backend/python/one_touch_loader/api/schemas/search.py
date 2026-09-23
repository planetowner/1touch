from pydantic import BaseModel

from .common import FixtureOut, TeamOut
from .players import PlayerCandidate


class SearchResponse(BaseModel):
    players: list[PlayerCandidate]
    teams: list[TeamOut]
    fixtures: list[FixtureOut]
