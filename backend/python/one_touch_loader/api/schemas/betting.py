from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StringConstraints
from ...core.betting import STAKE_UNIT, WELCOME_POINTS

Outcome = Literal['home_win', 'draw', 'away_win']
RunId = Annotated[str, StringConstraints(pattern=r'^[a-f0-9]{64}$')]


class CancelBetBody(BaseModel):
    model_config = ConfigDict(extra='forbid')
    request_id: UUID
    expected_revision: int = Field(ge=0, strict=True)


class PlaceBetBody(CancelBetBody):
    outcome: Outcome
    stake: int = Field(ge=STAKE_UNIT, multiple_of=STAKE_UNIT, strict=True)
    prediction_run_id: RunId


class BettingOption(BaseModel):
    outcome: Outcome
    probability: str
    decimal_odds: str


class WalletResponse(BaseModel):
    balance: int
    initialized: bool
    welcome_points: int = WELCOME_POINTS


class BetResponse(BaseModel):
    bet_id: int
    fixture_id: int
    prediction_run_id: str
    outcome: Outcome
    stake: int
    probability: str
    decimal_odds: str
    potential_return: int
    potential_profit: int
    status: Literal['open', 'cancelled', 'won', 'lost', 'refunded']
    revision: int
    payout: int
    settlement_reason: str | None
    created_at: str
    updated_at: str
    settled_at: str | None


class ParticipationResponse(BaseModel):
    total: int
    counts: dict[Outcome, int]
    probabilities: dict[Outcome, float] | None


class BettingMarketResponse(BaseModel):
    fixture_id: int
    available: bool
    can_bet: bool
    can_cancel: bool
    unavailable_reason: str | None
    closes_at: str | None
    prediction_run_id: str | None
    prediction_as_of: str | None
    options: list[BettingOption]
    wallet: WalletResponse
    bet: BetResponse | None
    participation: ParticipationResponse


class BetMutationResponse(BaseModel):
    wallet: WalletResponse
    bet: BetResponse
