"""저장된 경기 결과로 정산할 내역을 확인하고 --apply일 때만 포인트를 바꿔요."""
import argparse
import json

from ..api.db import fetch_all_dict
from ..core.betting import SETTLEMENT_STATE_IDS


def run_cli(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(argv)
    marks = ','.join('%s' for _ in SETTLEMENT_STATE_IDS)
    bets = fetch_all_dict(f'''SELECT b.bet_id FROM fixture_bets b JOIN fixtures f ON f.fixture_id=b.fixture_id
        WHERE b.status='open' AND f.state_id IN ({marks}) ORDER BY b.bet_id''', SETTLEMENT_STATE_IDS)
    results = []
    if bets:
        # 빈 예약 실행에서는 정산 저장소와 그 예측 의존성을 불러오지 않아요.
        from ..api.repos.betting_repo import settle_bet

        for bet in bets:
            result = settle_bet(bet['bet_id'], apply=args.apply)
            if result:
                results.append(result)
    print(json.dumps({'applied': args.apply, 'settlements': results}, ensure_ascii=False))


if __name__ == '__main__':
    run_cli()
