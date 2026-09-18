from fastapi import APIRouter, Depends, Query

from ..deps import get_user_id
from ..repos import betting_repo as repo
from ..schemas.betting import (BetMutationResponse, BettingMarketResponse, CancelBetBody,
                               PlaceBetBody, WalletResponse)

router = APIRouter()


@router.get('/users/me/points', response_model=WalletResponse)
def wallet(user_id: int = Depends(get_user_id)):
    return repo.get_wallet(user_id)


@router.post('/users/me/points/initialize', response_model=WalletResponse)
def initialize_wallet(user_id: int = Depends(get_user_id)):
    """기존·신규 회원 모두 첫 요청에서 1,000 pts를 한 번 받아요. 재요청은 잔액을 바꾸지 않아요."""
    return repo.initialize_wallet(user_id)


@router.get('/users/me/points/entries')
def point_entries(limit: int = Query(50, ge=1, le=200), before: int | None = Query(None, ge=1),
                  user_id: int = Depends(get_user_id)):
    return repo.list_point_entries(user_id, limit=limit, before=before)


@router.get('/fixtures/{fixture_id}/betting', response_model=BettingMarketResponse)
def betting_market(fixture_id: int, user_id: int = Depends(get_user_id)):
    """1Touch 승무패 확률·배당, 내 잔액·참여 내역, 참여자 수 기준 USER 비율이에요."""
    return repo.get_market(user_id, fixture_id)


@router.put('/fixtures/{fixture_id}/bet', response_model=BetMutationResponse)
def place_or_change_bet(fixture_id: int, body: PlaceBetBody, user_id: int = Depends(get_user_id)):
    """시작 전 한 건을 등록·변경해요. 배당이 갱신되면 409로 새 배당 확인을 요청해요."""
    return repo.mutate_bet(user_id, fixture_id, body.model_dump(mode='json'))


@router.post('/fixtures/{fixture_id}/bet/cancel', response_model=BetMutationResponse)
def cancel_bet(fixture_id: int, body: CancelBetBody, user_id: int = Depends(get_user_id)):
    return repo.mutate_bet(user_id, fixture_id, body.model_dump(mode='json'), cancel=True)
