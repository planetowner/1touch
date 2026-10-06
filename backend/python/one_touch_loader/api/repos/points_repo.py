"""베팅과 커뮤니티가 같은 지갑 초기화와 원장 기록을 사용해요."""
from ..db import fetch_one_dict, transaction
from ..services.community_periods import utc_now
from ...core.betting import WELCOME_POINTS
from .users_repo import lock_user


def wallet_response(row):
    return {'balance': int(row['balance']) if row else 0, 'initialized': row is not None,
            'welcome_points': WELCOME_POINTS}


def get_wallet(user_id):
    return wallet_response(fetch_one_dict('SELECT balance FROM user_point_wallets WHERE user_id=%s', (user_id,)))


def record_entry(cur, user_id, bet_id, request_id, request_hash, kind, amount, balance, revision, now,
                 *, post_id=None):
    cur.execute('''INSERT INTO user_point_entries
        (user_id,bet_id,request_id,request_hash,kind,amount,balance_after,bet_revision,created_at,post_id)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)''',
        (user_id, bet_id, request_id, request_hash, kind, amount, balance, revision, now, post_id))


def apply_delta(cur, user_id, wallet, amount, now, *, kind, request_id, request_hash='0' * 64,
                bet_id=None, revision=None, post_id=None):
    # 가입 이후의 모든 증감은 잔액과 원장을 함께 바꿔요. 호출부의 트랜잭션이 둘을 함께 확정해요.
    balance = wallet['balance'] + amount
    cur.execute('UPDATE user_point_wallets SET balance=%s,updated_at=%s WHERE user_id=%s', (balance, now, user_id))
    record_entry(cur, user_id, bet_id, request_id, request_hash, kind, amount, balance, revision, now, post_id=post_id)
    return balance


def initialize_locked_wallet(cur, user_id, now):
    # 호출하는 쪽에서 회원 행을 먼저 잠가 가입 보상과 다른 적립이 겹치지 않게 해요.
    cur.execute('SELECT balance,country_code FROM user_point_wallets WHERE user_id=%s', (user_id,))
    wallet = cur.fetchone()
    if wallet is None:
        cur.execute('INSERT INTO user_point_wallets (user_id,balance,created_at,updated_at) VALUES (%s,%s,%s,%s)',
                    (user_id, WELCOME_POINTS, now, now))
        record_entry(cur, user_id, None, 'welcome', '0' * 64, 'welcome', WELCOME_POINTS, WELCOME_POINTS, None, now)
        wallet = {'balance': WELCOME_POINTS, 'country_code': None}
    return wallet


def initialize_wallet(user_id, country_code=None):
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        lock_user(cur, user_id)
        wallet = initialize_locked_wallet(cur, user_id, utc_now())
        # 접속 IP로 확인한 국가를 저장해요. 판별하지 못한 요청은 기존 국가를 지우지 않아요.
        # 작성자가 오프라인일 때 받은 반응도 마지막으로 확인한 국가 기준으로 적립해요.
        if country_code is not None and country_code != wallet['country_code']:
            cur.execute('UPDATE user_point_wallets SET country_code=%s WHERE user_id=%s', (country_code, user_id))
        return wallet_response(wallet)
