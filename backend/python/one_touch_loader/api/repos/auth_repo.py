"""인증 성공·코드 소진·세션 생성은 같은 트랜잭션에 묶어요."""
from datetime import timedelta
import hmac
import secrets

from fastapi import HTTPException
from mysql.connector import IntegrityError

from ..db import fetch_one_dict, transaction
from ..services.auth_security import (
    CODE_ATTEMPTS, CODE_LIFETIME_MINUTES, PASSWORDS, SESSION_DAYS,
    code_hash, new_token, token_hash,
)
from ..services.community_periods import utc_now
from ..services.email_sender import send_verification_code


def rate_limit(scope: str, limit: int, seconds: int) -> None:
    key, now = token_hash(scope), utc_now()
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        cur.execute("INSERT IGNORE INTO api_rate_limits VALUES (%s,%s,0)", (key, now))
        cur.execute("SELECT * FROM api_rate_limits WHERE scope_hash=%s FOR UPDATE", (key,))
        row = cur.fetchone()
        started = row["window_started_at"]
        count = row["attempts"]
        if now >= started + timedelta(seconds=seconds):
            started, count = now, 0
        count += 1
        cur.execute("UPDATE api_rate_limits SET window_started_at=%s,attempts=%s WHERE scope_hash=%s",
                    (started, count, key))
    # 제한을 넘은 요청도 커밋한 뒤 거절해야 실패 시 카운터가 롤백되지 않아요.
    if count > limit:
        remaining = max(1, int((started + timedelta(seconds=seconds) - now).total_seconds()))
        raise HTTPException(429, "Too many authentication requests", headers={"Retry-After": str(remaining)})


def _create_session(cur, user_id: int) -> dict:
    token = new_token()
    expires = utc_now() + timedelta(days=SESSION_DAYS)
    cur.execute("INSERT INTO user_sessions VALUES (%s,%s,%s)", (token_hash(token), user_id, expires))
    return {"access_token": token, "token_type": "bearer", "expires_at": expires.isoformat() + "Z"}


def session_user(token: str) -> dict:
    row = fetch_one_dict("""SELECT u.*, s.expires_at AS session_expires_at
        FROM user_sessions s JOIN users u ON u.user_id=s.user_id
        WHERE s.token_hash=%s AND s.expires_at>%s""", (token_hash(token), utc_now()))
    if row is None:
        raise HTTPException(401, "Invalid or expired session", headers={"WWW-Authenticate": "Bearer"})
    return row


def logout(token: str) -> None:
    with transaction() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM user_sessions WHERE token_hash=%s", (token_hash(token),))


def _limit_email_code(email: str) -> None:
    rate_limit(f"email-code:{email.casefold()}", 1, 60)
    rate_limit(f"email-code-hour:{email.casefold()}", 5, 3600)


def _issue_email_code(cur, email: str, purpose: str) -> dict:
    challenge, code = new_token(), f"{secrets.randbelow(1_000_000):06d}"
    digest = code_hash(challenge, code)
    cur.execute("""INSERT INTO email_verification_codes
        (challenge_hash,email,purpose,code_hash,expires_at,attempts) VALUES (%s,%s,%s,%s,%s,0)
        ON DUPLICATE KEY UPDATE challenge_hash=VALUES(challenge_hash),code_hash=VALUES(code_hash),
        expires_at=VALUES(expires_at),attempts=0""",
        (token_hash(challenge), email, purpose, digest, utc_now() + timedelta(minutes=CODE_LIFETIME_MINUTES)))
    # SES 접수가 실패하면 새 코드 저장도 취소해요. 메일 도착 여부는 공급자 접수와 별개예요.
    send_verification_code(email, code, purpose)
    return {"challenge_id": challenge, "expires_in": CODE_LIFETIME_MINUTES * 60}


def request_email_code(email: str, purpose: str) -> dict:
    _limit_email_code(email)
    with transaction() as conn, conn.cursor() as cur:
        return _issue_email_code(cur, email, purpose)


def _verify_code(cur, challenge: str, code: str, purpose: str) -> str | None:
    key = token_hash(challenge)
    cur.execute("SELECT * FROM email_verification_codes WHERE challenge_hash=%s FOR UPDATE", (key,))
    row = cur.fetchone()
    if row is None or row["purpose"] != purpose or row["expires_at"] <= utc_now() or row["attempts"] >= CODE_ATTEMPTS:
        return None
    cur.execute("UPDATE email_verification_codes SET attempts=attempts+1 WHERE challenge_hash=%s", (key,))
    if not hmac.compare_digest(bytes(row["code_hash"]), code_hash(challenge, code)):
        return None
    return row["email"]


def _consume_code(cur, challenge: str, code: str, purpose: str) -> str | None:
    email = _verify_code(cur, challenge, code, purpose)
    if email is not None:
        cur.execute("DELETE FROM email_verification_codes WHERE challenge_hash=%s", (token_hash(challenge),))
    return email


def register_email(challenge: str, code: str, password: str, profile: dict) -> dict:
    hashed = PASSWORDS.hash(password)
    result = None
    try:
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            email = _consume_code(cur, challenge, code, "signup")
            if email is not None:
                cur.execute("""INSERT INTO users (username,first_name,last_name,created_at)
                    VALUES (%s,%s,%s,%s)""",
                    (profile["username"], profile["first_name"], profile["last_name"], utc_now()))
                user_id = cur.lastrowid
                cur.execute("INSERT INTO user_email_credentials VALUES (%s,%s,%s)", (user_id, email, hashed))
                result = _create_session(cur, user_id)
    except IntegrityError as exc:
        if exc.errno != 1062:
            raise
        raise HTTPException(409, "Email or username is already registered") from exc
    if result is None:
        raise HTTPException(400, "Invalid, expired, or exhausted verification code")
    return result


def login_password(username: str, password: str) -> dict:
    rate_limit(f"password-login:{username.casefold()}", 10, 300)
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        # 이메일은 가입 인증·비밀번호 복구에 쓰고, 로그인은 현재 username으로만 찾아요.
        cur.execute("""SELECT c.user_id,c.password_hash FROM users u
            JOIN user_email_credentials c ON c.user_id=u.user_id
            WHERE u.username=%s FOR UPDATE""", (username,))
        row = cur.fetchone()
        if row is None or not PASSWORDS.verify(password, row["password_hash"]):
            raise HTTPException(401, "Invalid username or password")
        return _create_session(cur, row["user_id"])


def reset_password(challenge: str, code: str, password: str) -> None:
    hashed = PASSWORDS.hash(password)
    verified = False
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        email = _consume_code(cur, challenge, code, "password_reset")
        if email is not None:
            verified = True
            cur.execute("SELECT user_id FROM user_email_credentials WHERE email=%s FOR UPDATE", (email,))
            row = cur.fetchone()
            if row is not None:
                cur.execute("UPDATE user_email_credentials SET password_hash=%s WHERE user_id=%s", (hashed, row["user_id"]))
                # 비밀번호 재설정 뒤 기존 기기의 인증은 다시 받아요.
                cur.execute("DELETE FROM user_sessions WHERE user_id=%s", (row["user_id"],))
    if not verified:
        raise HTTPException(400, "Invalid, expired, or exhausted verification code")


def find_username(challenge: str, code: str) -> str:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        email = _consume_code(cur, challenge, code, "username_recovery")
        account = None
        if email is not None:
            cur.execute("""SELECT u.username FROM user_email_credentials c
                JOIN users u ON u.user_id=c.user_id WHERE c.email=%s""", (email,))
            account = cur.fetchone()
    # 주소 소유를 확인한 뒤에만 계정 유무·유저네임을 알려요. 새 로그인 세션은 만들지 않아요.
    if email is None:
        raise HTTPException(400, "Invalid, expired, or exhausted verification code")
    if account is None:
        raise HTTPException(404, "No email account found. Use the social provider used at signup")
    return account["username"]


def find_social_username(provider: str, subject: str) -> str | None:
    account = fetch_one_dict("""SELECT u.username FROM user_social_identities i
        JOIN users u ON u.user_id=i.user_id WHERE i.provider=%s AND i.subject=%s""", (provider, subject))
    # 찾기 화면에서 다른 소셜 계정을 골라도 새 회원을 만들지 않아요.
    if account is None:
        raise HTTPException(404, "No account found for this social identity")
    return account["username"]


def _lock_email_account(cur, user_id: int, password: str) -> dict:
    rate_limit(f"email-change-password:{user_id}", 10, 300)
    cur.execute("SELECT email,password_hash FROM user_email_credentials WHERE user_id=%s FOR UPDATE", (user_id,))
    account = cur.fetchone()
    if account is None:
        raise HTTPException(403, "Email changes require an email password account")
    if not PASSWORDS.verify(password, account["password_hash"]):
        raise HTTPException(401, "Invalid current password")
    return account


def request_email_change(user_id: int, email: str, password: str) -> dict:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        account = _lock_email_account(cur, user_id, password)
        current = account["email"]
        if current.casefold() == email.casefold():
            raise HTTPException(400, "Use a different email address")
        _limit_email_code(current)
        _limit_email_code(email)
        # 기존·새 주소 모두 인증할 때까지 현재 주소를 유지해요. 두 코드도 같은 저장 규칙을 써요.
        return {"current_email": _issue_email_code(cur, current, "email_change"),
                "new_email": _issue_email_code(cur, email, "email_change")}


def change_email(user_id: int, password: str, current_email: dict, new_email: dict) -> None:
    changed = False
    try:
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            account = _lock_email_account(cur, user_id, password)
            current = _verify_code(cur, current_email["challenge_id"], current_email["code"], "email_change")
            new = _verify_code(cur, new_email["challenge_id"], new_email["code"], "email_change")
            if (current is not None and new is not None and current.casefold() == account["email"].casefold()
                    and current.casefold() != new.casefold()):
                cur.execute("UPDATE user_email_credentials SET email=%s WHERE user_id=%s", (new, user_id))
                # 변경 전에 발급된 복구 코드를 새 계정 주소에 재사용하지 못하게 함께 소진해요.
                cur.execute("DELETE FROM email_verification_codes WHERE email IN (%s,%s)", (current, new))
                cur.execute("DELETE FROM user_sessions WHERE user_id=%s", (user_id,))
                changed = True
    except IntegrityError as exc:
        if exc.errno != 1062:
            raise
        raise HTTPException(409, "Email is already registered") from exc
    # 한쪽이 틀려도 입력 시도 횟수는 남겨요. 두 주소를 확인했을 때만 코드를 소진해요.
    if not changed:
        raise HTTPException(400, "Invalid, expired, exhausted, or unrelated email verification codes")


def login_social(provider: str, subject: str) -> dict:
    with transaction() as conn, conn.cursor(dictionary=True) as cur:
        cur.execute("SELECT user_id FROM user_social_identities WHERE provider=%s AND subject=%s", (provider, subject))
        row = cur.fetchone()
        if row is None:
            cur.execute("INSERT INTO users (created_at) VALUES (%s)", (utc_now(),))
            user_id = cur.lastrowid
            cur.execute("""INSERT INTO user_social_identities VALUES (%s,%s,%s)
                ON DUPLICATE KEY UPDATE subject=VALUES(subject)""", (provider, subject, user_id))
            # 격리 MySQL에서 동시 첫 로그인 시 같은 공급자 ID의 PK 충돌을 재현했어요.
            # 먼저 저장된 관계를 잠금 조회하고, 이번 요청의 미사용 사용자 행만 없애요.
            cur.execute("SELECT user_id FROM user_social_identities WHERE provider=%s AND subject=%s FOR UPDATE", (provider, subject))
            canonical_id = cur.fetchone()["user_id"]
            if canonical_id != user_id:
                cur.execute("DELETE FROM users WHERE user_id=%s", (user_id,))
                user_id = canonical_id
        else:
            user_id = row["user_id"]
        return _create_session(cur, user_id)
