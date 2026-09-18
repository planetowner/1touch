"""저장된 경기 결과로 정산할 내역을 확인하고 --apply일 때만 포인트를 바꿔요."""
import argparse
import json

from ..api.db import fetch_all_dict
from ..api.repos.betting_repo import settle_bet


def run_cli(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(argv)
    bets = fetch_all_dict('''SELECT b.bet_id FROM fixture_bets b JOIN fixtures f ON f.fixture_id=b.fixture_id
        WHERE b.status='open' AND f.state_id IN (5,10,12,14,15,17,20) ORDER BY b.bet_id''')
    results = []
    for bet in bets:
        result = settle_bet(bet['bet_id'], apply=args.apply)
        if result:
            results.append(result)
    print(json.dumps({'applied': args.apply, 'settlements': results}, ensure_ascii=False))


if __name__ == '__main__':
    run_cli()
