"""승무패 모델의 확률을 포인트 배당으로 바꾸는 공통 규칙이에요."""
from decimal import Decimal

from .probability import OUTCOMES, WDLModel
from .fixture_states import COMPLETED_STATE_IDS

WELCOME_POINTS = 1000
STAKE_UNIT = 10
PROBABILITY_UNIT = Decimal('0.000000000000000001')
# 실제 종료만 정산해요. 연기·취소·포기·행정 결과는 경기 결과에 베팅한 것으로 보지 않아요.
REFUND_STATE_IDS = (10, 12, 14, 15, 17, 20)
OPEN_STATE_IDS = (1, 16)
SETTLEMENT_STATE_IDS = (*COMPLETED_STATE_IDS, *REFUND_STATE_IDS)
SETTLEMENT_RULE = 'single_match_final_v1'


def total_return(stake: int, probability: Decimal) -> int:
    # 정수 비율로 나누면 Decimal 연산 정밀도와 무관하게 항상 정확히 버림해요.
    numerator, denominator = probability.as_integer_ratio()
    return stake * denominator // numerator


def prediction_options(coefficients, home_elo, away_elo, *, draw_allowed=True) -> list[dict]:
    probabilities = WDLModel(tuple(coefficients)).predict(
        [float(home_elo) - float(away_elo)], draw_allowed=draw_allowed)[0]
    options = []
    for outcome, probability in zip(OUTCOMES, probabilities):
        if outcome == 'draw' and not draw_allowed:
            continue
        # 화면 미리보기와 DB 정산이 동일한 십진 확률을 사용해요.
        value = Decimal(str(float(probability))).quantize(PROBABILITY_UNIT)
        if not 0 < value <= 1:
            raise ValueError('Prediction probability must be positive and at most one')
        options.append({'outcome': outcome, 'probability': format(value, '.18f'),
                        'decimal_odds': format(Decimal(1) / value, '.12f')})
    return options


def match_outcome(fixture: dict, *, draw_allowed=True) -> str | None:
    if fixture['state_id'] not in COMPLETED_STATE_IDS:
        return None
    home, away = fixture['home_score'], fixture['away_score']
    if home is None or away is None:
        return None
    # 합산 동점으로 승부차기를 해도 해당 경기 스코어의 승자가 먼저예요.
    if home != away:
        return 'home_win' if home > away else 'away_win'
    home_pen, away_pen = fixture.get('home_penalty_score'), fixture.get('away_penalty_score')
    # 실제 FT/AET 자료에 승부차기 미실시를 0–0으로 저장한 사례가 있어요.
    has_penalties = (home_pen is not None or away_pen is not None) and (home_pen, away_pen) != (0, 0)
    if has_penalties or fixture['state_id'] == 8:
        if home_pen is None or away_pen is None or home_pen == away_pen:
            return None
        return 'home_win' if home_pen > away_pen else 'away_win'
    # 단판 승자 시장의 동점은 결과 누락일 수 있어요. 무승부로 조기 정산하지 않아요.
    return 'draw' if draw_allowed else None


def settlement(fixture: dict, bet: dict, *, draw_allowed=True) -> dict | None:
    state = fixture['state_id']
    if state in REFUND_STATE_IDS:
        return {'status': 'refunded', 'payout': bet['stake'], 'kind': 'bet_refund',
                'reason': fixture['state_code']}
    actual = match_outcome(fixture, draw_allowed=draw_allowed)
    if actual is None:
        return None
    won = bet['outcome'] == actual
    return {'status': 'won' if won else 'lost', 'payout': bet['potential_return'] if won else 0,
            'kind': 'bet_win' if won else 'bet_loss', 'reason': fixture['state_code']}
