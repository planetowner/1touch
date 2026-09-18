"""회원 잠금 아래에서 참여 내역·포인트 잔액·원장을 함께 저장해요."""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
import hashlib
import json

from fastapi import HTTPException

from ..db import fetch_all_dict, fetch_one_dict, transaction
from ..services.community_periods import utc_now
from .users_repo import lock_user
from ...core.betting import (OPEN_STATE_IDS, WELCOME_POINTS, prediction_options,
                             settlement, total_return)
from ...core.db_json import decoded
from ...core.probability import OUTCOMES
from ...core.probability_forecast import LEAGUE_RULES

FIXTURE_SQL = '''SELECT f.fixture_id,f.home_team_id,f.away_team_id,f.starting_at,
    f.state_id,fs.state_code,f.home_score,f.away_score,st.season_id,st.stage_type_id,
    s.competition_id,s.name AS season_name FROM fixtures f
    JOIN fixture_states fs ON fs.state_id=f.state_id JOIN stages st ON st.stage_id=f.stage_id
    JOIN seasons s ON s.season_id=st.season_id WHERE f.fixture_id=%s'''


def _stamp(value):
    return value.isoformat(timespec='microseconds') + 'Z' if isinstance(value, datetime) else value


def _bet(row):
    if row is None:
        return None
    result = {key: row[key] for key in (
        'bet_id', 'fixture_id', 'prediction_run_id', 'outcome', 'stake', 'potential_return',
        'status', 'revision', 'payout', 'settlement_reason', 'created_at', 'updated_at', 'settled_at')}
    probability = Decimal(str(row['probability']))
    result.update(probability=format(probability, '.18f'),
                  decimal_odds=format(Decimal(1) / probability, '.12f'),
                  potential_profit=row['potential_return'] - row['stake'])
    return {key: _stamp(value) for key, value in result.items()}


def _wallet(row):
    return {'balance': int(row['balance']) if row else 0, 'initialized': row is not None,
            'welcome_points': WELCOME_POINTS}


def get_wallet(user_id):
    return _wallet(fetch_one_dict('SELECT balance FROM user_point_wallets WHERE user_id=%s', (user_id,)))


def _initialize(cur, user_id, now):
    cur.execute('SELECT balance FROM user_point_wallets WHERE user_id=%s', (user_id,))
    wallet = cur.fetchone()
    if wallet is None:
        cur.execute('INSERT INTO user_point_wallets (user_id,balance,created_at,updated_at) VALUES (%s,%s,%s,%s)',
                    (user_id, WELCOME_POINTS, now, now))
        _entry(cur, user_id, None, 'welcome', '0' * 64, 'welcome', WELCOME_POINTS, WELCOME_POINTS, None, now)
        wallet = {'balance': WELCOME_POINTS}
    return wallet


def initialize_wallet(user_id):
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, user_id)
        return _wallet(_initialize(cur, user_id, utc_now()))


def _entry(cur, user_id, bet_id, request_id, request_hash, kind, amount, balance, revision, now):
    cur.execute('''INSERT INTO user_point_entries
        (user_id,bet_id,request_id,request_hash,kind,amount,balance_after,bet_revision,created_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)''',
        (user_id, bet_id, request_id, request_hash, kind, amount, balance, revision, now))


def _supported(fixture):
    # 현재 예측 모델이 제공하는 정규 리그 범위를 그대로 사용해요.
    return (fixture['competition_id'] in LEAGUE_RULES and fixture['season_name'] == '2026/2027'
            and fixture['stage_type_id'] == 223)


def _before_start(fixture, now):
    return (fixture['state_id'] in OPEN_STATE_IDS and fixture['starting_at'] is not None
            and now < fixture['starting_at'])


def _prediction(read_one, fixture, now):
    if not _supported(fixture) or fixture['starting_at'] is None:
        return None
    # 지난 경기 화면에서도 경기 후 전력이나 사후 복원 예측을 경기 전 배당처럼 보여주지 않아요.
    cutoff = min(now, fixture['starting_at'])
    selected = read_one('''SELECT run_id FROM probability_runs
        WHERE season_id=%s AND as_of<=%s AND as_of<%s
          AND JSON_UNQUOTE(JSON_EXTRACT(payload,'$.history_kind'))='observed_calculation'
        ORDER BY as_of DESC,created_at DESC,run_id DESC LIMIT 1''',
        (fixture['season_id'], cutoff, fixture['starting_at']))
    if selected is None:
        return None
    row = read_one('''SELECT r.run_id,r.as_of,
        JSON_EXTRACT(m.payload,'$.forecast_model.coefficients') AS coefficients,
        JSON_EXTRACT(h.payload,'$.elo') AS home_elo,JSON_EXTRACT(a.payload,'$.elo') AS away_elo
        FROM probability_runs r JOIN probability_models m ON m.model_id=r.model_id
        JOIN probability_team_results h ON h.run_id=r.run_id AND h.team_id=%s
        JOIN probability_team_results a ON a.run_id=r.run_id AND a.team_id=%s
        WHERE r.run_id=%s''', (fixture['home_team_id'], fixture['away_team_id'], selected['run_id']))
    if row is None:
        return None
    return {'prediction_run_id': row['run_id'], 'prediction_as_of': _stamp(row['as_of']),
            'options': prediction_options(decoded(row['coefficients']), row['home_elo'], row['away_elo'])}


def get_market(user_id, fixture_id):
    fixture = fetch_one_dict(FIXTURE_SQL, (fixture_id,))
    if fixture is None:
        raise HTTPException(404, 'Fixture not found')
    now = utc_now()
    prediction = _prediction(fetch_one_dict, fixture, now)
    bet = fetch_one_dict('SELECT * FROM fixture_bets WHERE user_id=%s AND fixture_id=%s', (user_id, fixture_id))
    counts = dict.fromkeys(OUTCOMES, 0)
    for row in fetch_all_dict('''SELECT outcome,COUNT(*) AS participants FROM fixture_bets
            WHERE fixture_id=%s AND status IN ('open','won','lost') GROUP BY outcome''', (fixture_id,)):
        counts[row['outcome']] = int(row['participants'])
    total = sum(counts.values())
    open_now = _before_start(fixture, now)
    reason = ('unsupported_competition' if not _supported(fixture) else
              'kickoff_unconfirmed' if fixture['starting_at'] is None else
              'betting_closed' if not open_now else 'prediction_unavailable' if prediction is None else None)
    return {'fixture_id': fixture_id, 'available': prediction is not None,
            'can_bet': reason is None and (bet is None or bet['status'] in ('open', 'cancelled', 'refunded')),
            'can_cancel': open_now and bet is not None and bet['status'] == 'open',
            'unavailable_reason': reason, 'closes_at': _stamp(fixture['starting_at']),
            **(prediction or {'prediction_run_id': None, 'prediction_as_of': None, 'options': []}),
            'wallet': get_wallet(user_id), 'bet': _bet(bet),
            'participation': {'total': total, 'counts': counts,
                              'probabilities': {k: v / total for k, v in counts.items()} if total else None}}


def _read_one(cur, sql, params=()):
    cur.execute(sql, params)
    return cur.fetchone()


def mutate_bet(user_id, fixture_id, body, *, cancel=False):
    request_id = str(body['request_id'])
    digest = hashlib.sha256(json.dumps({'fixture_id': fixture_id, 'cancel': cancel, **body},
                                      sort_keys=True, default=str).encode()).hexdigest()
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        # 참여·변경·취소·자동 정산은 회원→경기→베팅 순서로 잠가요.
        lock_user(cur, user_id)
        fixture = _read_one(cur, FIXTURE_SQL + ' FOR UPDATE', (fixture_id,))
        if fixture is None:
            raise HTTPException(404, 'Fixture not found')
        bet = _read_one(cur, 'SELECT * FROM fixture_bets WHERE user_id=%s AND fixture_id=%s FOR UPDATE',
                        (user_id, fixture_id))
        prior = _read_one(cur, 'SELECT request_hash FROM user_point_entries WHERE user_id=%s AND request_id=%s',
                          (user_id, request_id))
        if prior:
            if prior['request_hash'] != digest:
                raise HTTPException(409, {'code': 'request_conflict', 'message': 'Request ID was already used'})
            wallet = _read_one(cur, 'SELECT balance FROM user_point_wallets WHERE user_id=%s', (user_id,))
            return {'wallet': _wallet(wallet), 'bet': _bet(bet)}
        now = utc_now()
        if not _before_start(fixture, now):
            raise HTTPException(409, {'code': 'betting_closed', 'message': 'Betting is closed'})
        if body['expected_revision'] != (bet['revision'] if bet else 0):
            raise HTTPException(409, {'code': 'bet_changed', 'message': 'Reload your current bet'})
        if bet and bet['status'] in ('won', 'lost'):
            raise HTTPException(409, {'code': 'already_settled', 'message': 'Bet was already settled'})
        wallet = _initialize(cur, user_id, now)
        old_stake = bet['stake'] if bet and bet['status'] == 'open' else 0
        revision = (bet['revision'] if bet else 0) + 1
        if cancel:
            if not old_stake:
                raise HTTPException(409, {'code': 'no_open_bet', 'message': 'No open bet to cancel'})
            delta, kind = old_stake, 'bet_cancel'
            cur.execute("UPDATE fixture_bets SET status='cancelled',revision=%s,payout=%s,updated_at=%s WHERE bet_id=%s",
                        (revision, old_stake, now, bet['bet_id']))
            bet_id = bet['bet_id']
        else:
            prediction = _prediction(lambda sql, params: _read_one(cur, sql, params), fixture, now)
            if prediction is None:
                raise HTTPException(409, {'code': 'prediction_unavailable', 'message': 'Prediction is unavailable'})
            if body['prediction_run_id'] != prediction['prediction_run_id']:
                raise HTTPException(409, {'code': 'prediction_changed', 'message': 'Review the updated odds'})
            option = next(o for o in prediction['options'] if o['outcome'] == body['outcome'])
            probability = Decimal(option['probability'])
            stake = body['stake']
            if stake > wallet['balance'] + old_stake:
                raise HTTPException(409, {'code': 'insufficient_points', 'message': 'Not enough points'})
            potential = total_return(stake, probability)
            delta, kind = old_stake - stake, 'bet_change' if old_stake else 'bet_place'
            values = (body['prediction_run_id'], body['outcome'], stake, probability, potential, revision, now)
            if bet:
                bet_id = bet['bet_id']
                cur.execute('''UPDATE fixture_bets SET prediction_run_id=%s,outcome=%s,stake=%s,probability=%s,
                    potential_return=%s,revision=%s,updated_at=%s,status='open',payout=0,
                    settlement_reason=NULL,settled_at=NULL,settled_home_score=NULL,settled_away_score=NULL
                    WHERE bet_id=%s''', (*values, bet_id))
            else:
                cur.execute('''INSERT INTO fixture_bets
                    (prediction_run_id,outcome,stake,probability,potential_return,revision,updated_at,
                     user_id,fixture_id,status,created_at) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,'open',%s)''',
                    (*values, user_id, fixture_id, now))
                bet_id = cur.lastrowid
        balance = wallet['balance'] + delta
        cur.execute('UPDATE user_point_wallets SET balance=%s,updated_at=%s WHERE user_id=%s', (balance, now, user_id))
        _entry(cur, user_id, bet_id, request_id, digest, kind, delta, balance, revision, now)
        return {'wallet': _wallet({'balance': balance}),
                'bet': _bet(_read_one(cur, 'SELECT * FROM fixture_bets WHERE bet_id=%s', (bet_id,)))}


def settle_bet(bet_id, *, apply=False):
    owner = fetch_one_dict('SELECT user_id,fixture_id FROM fixture_bets WHERE bet_id=%s', (bet_id,))
    if owner is None:
        return None
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, owner['user_id'])
        fixture = _read_one(cur, FIXTURE_SQL + ' FOR UPDATE', (owner['fixture_id'],))
        bet = _read_one(cur, 'SELECT * FROM fixture_bets WHERE bet_id=%s FOR UPDATE', (bet_id,))
        if bet is None or bet['status'] != 'open':
            return None
        result = settlement(fixture, bet)
        if result is None or not apply:
            return {'bet_id': bet_id, **result} if result else None
        wallet = _read_one(cur, 'SELECT balance FROM user_point_wallets WHERE user_id=%s', (owner['user_id'],))
        now, revision = utc_now(), bet['revision'] + 1
        balance = wallet['balance'] + result['payout']
        cur.execute('''UPDATE fixture_bets SET status=%s,payout=%s,settlement_reason=%s,
            settled_home_score=%s,settled_away_score=%s,settled_at=%s,updated_at=%s,revision=%s WHERE bet_id=%s''',
            (result['status'], result['payout'], result['reason'], fixture['home_score'], fixture['away_score'],
             now, now, revision, bet_id))
        cur.execute('UPDATE user_point_wallets SET balance=%s,updated_at=%s WHERE user_id=%s',
                    (balance, now, owner['user_id']))
        _entry(cur, owner['user_id'], bet_id, f'settle:{bet_id}:{revision}', '0' * 64,
               result['kind'], result['payout'], balance, revision, now)
        return {'bet_id': bet_id, **result}


def list_point_entries(user_id, *, limit=50, before=None):
    suffix, params = (' AND entry_id<%s', (user_id, before)) if before else ('', (user_id,))
    rows = fetch_all_dict('''SELECT entry_id,bet_id,kind,amount,balance_after,created_at FROM user_point_entries
        WHERE user_id=%s''' + suffix + ' ORDER BY entry_id DESC LIMIT %s', (*params, limit))
    return {'items': [{k: _stamp(v) for k, v in row.items()} for row in rows],
            'next_before': rows[-1]['entry_id'] if len(rows) == limit else None}
