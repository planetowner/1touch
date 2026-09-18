"""승무패 모델의 확률을 포인트 배당으로 바꾸는 공통 규칙이에요."""
from decimal import Decimal

from .probability import OUTCOMES, WDLModel

WELCOME_POINTS = 1000
STAKE_UNIT = 10
PROBABILITY_UNIT = Decimal('0.000000000000000001')
# 실제 종료만 정산해요. 연기·취소·포기·행정 결과는 경기 결과에 베팅한 것으로 보지 않아요.
REFUND_STATE_IDS = (10, 12, 14, 15, 17, 20)
OPEN_STATE_IDS = (1, 16)


def total_return(stake: int, probability: Decimal) -> int:
    # 정수 비율로 나누면 Decimal 연산 정밀도와 무관하게 항상 정확히 버림해요.
    numerator, denominator = probability.as_integer_ratio()
    return stake * denominator // numerator


def prediction_options(coefficients, home_elo, away_elo) -> list[dict]:
    probabilities = WDLModel(tuple(coefficients)).predict([float(home_elo) - float(away_elo)])[0]
    options = []
    for outcome, probability in zip(OUTCOMES, probabilities):
        # 화면 미리보기와 DB 정산이 동일한 십진 확률을 사용해요.
        value = Decimal(str(float(probability))).quantize(PROBABILITY_UNIT)
        if not 0 < value <= 1:
            raise ValueError('Prediction probability must be positive and at most one')
        options.append({'outcome': outcome, 'probability': format(value, '.18f'),
                        'decimal_odds': format(Decimal(1) / value, '.12f')})
    return options


def settlement(fixture: dict, bet: dict) -> dict | None:
    state = fixture['state_id']
    if state in REFUND_STATE_IDS:
        return {'status': 'refunded', 'payout': bet['stake'], 'kind': 'bet_refund',
                'reason': fixture['state_code']}
    if state != 5 or fixture['home_score'] is None or fixture['away_score'] is None:
        return None
    home, away = fixture['home_score'], fixture['away_score']
    actual = 'home_win' if home > away else 'away_win' if away > home else 'draw'
    won = bet['outcome'] == actual
    return {'status': 'won' if won else 'lost', 'payout': bet['potential_return'] if won else 0,
            'kind': 'bet_win' if won else 'bet_loss', 'reason': 'FT'}
