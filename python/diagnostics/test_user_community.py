"""네트워크 공급자는 모의 응답으로, 저장·경쟁 요청은 격리 MySQL로 검사해요."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
import io
import os
from threading import Barrier
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from uuid import uuid4

import mysql.connector
from fastapi import HTTPException
from fastapi.testclient import TestClient
from PIL import Image
from botocore.response import StreamingBody
from pydantic import ValidationError
from diagnostics import test_auth_providers as provider_tests

# 테스트 수집만 해도 운영 DB 풀이 열리지 않게 해요.
with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.core import db
    from one_touch_loader.api.main import create_app
    from one_touch_loader.api.repos import auth_repo, posts_repo, teams_repo, users_repo, chat_repo
    from one_touch_loader.api.services import auth_security, media_storage, social_login
    from one_touch_loader.api.services.community_periods import PostPeriod, period_bounds, utc_now
    from one_touch_loader.api.schemas.users import PasswordLoginBody, RegisterEmailBody, ResetPasswordBody
    from diagnostics.verify_community_management import verify_schema
    from diagnostics.verify_social_webhook_receipts import verify_schema as verify_social_schema
    from diagnostics.verify_account_management import verify_schema as verify_account_schema


class PasswordContractTests(unittest.TestCase):
    profile = {"username": "member", "first_name": "First", "last_name": "Last"}
    code = {"challenge_id": "c" * 43, "code": "123456"}

    def test_same_password_policy_applies_to_signup_reset_and_login(self):
        cases = [(RegisterEmailBody, {**self.profile, **self.code}),
                 (ResetPasswordBody, self.code), (PasswordLoginBody, {"username": "member"})]
        for model, fields in cases:
            for password in ("Aa12345", "abcdefgh1", "ABCDEFGH1", "Abcdefgh", "abcdefgÉ1", "ABCDEFGé1", "Abcdefg１"):
                with self.subTest(model=model.__name__, password=password), self.assertRaises(ValidationError):
                    model.model_validate({**fields, "password": password})
            for password in ("Abcdefg1", "Abcdefg1!", " Abcdefg1 "):
                with self.subTest(model=model.__name__, password=password):
                    self.assertEqual(model.model_validate({**fields, "password": password}).password, password)

    def test_signup_requires_both_username_and_password(self):
        body = {**self.profile, **self.code, "password": "Abcdefg1"}
        for missing in ("username", "password"):
            with self.subTest(missing=missing), self.assertRaises(ValidationError):
                RegisterEmailBody.model_validate({key: value for key, value in body.items() if key != missing})
        with self.assertRaises(ValidationError):
            RegisterEmailBody.model_validate({**body, "username": "   "})

    def test_login_requires_username_field_instead_of_email(self):
        with self.assertRaises(ValidationError):
            PasswordLoginBody.model_validate({"email": "member@example.com", "password": "Abcdefg1"})
        self.assertEqual(PasswordLoginBody(username=" member ", password="Abcdefg1").username, "member")


class ProviderDisplayTests(unittest.TestCase):
    def test_country_and_device_determine_signup_choices_without_database(self):
        client = TestClient(create_app())
        for platform, country, expected in (
            ("ios", "KR", ["kakao", "apple", "google", "email"]),
            ("android", "KR", ["kakao", "google", "email"]),
            ("ios", "US", ["apple", "google", "email"]),
            ("android", "US", ["google", "email"]),
            ("ios", "DE", ["apple", "google", "email"]),
            ("android", "DE", ["google", "email"]),
            ("android", "kr", ["kakao", "google", "email"]),
        ):
            with self.subTest(platform=platform, country=country):
                response = client.get("/v1/auth/providers", params={"platform": platform, "country_code": country})
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json(), {"providers": expected})

    def test_missing_or_unknown_device_is_not_assumed_to_be_iphone(self):
        client = TestClient(create_app())
        for query in ("country_code=KR", "country_code=KR&platform=web", "country_code=KR&platform=", "platform=ios"):
            with self.subTest(query=query):
                self.assertEqual(client.get("/v1/auth/providers?" + query).status_code, 422)


class PeriodTests(unittest.TestCase):
    def test_same_instant_belongs_to_different_local_days(self):
        now = datetime(2026, 9, 10, 1)
        self.assertEqual(period_bounds(PostPeriod.today, "Asia/Seoul", now),
                         (datetime(2026, 9, 9, 15), datetime(2026, 9, 10, 15)))
        self.assertEqual(period_bounds(PostPeriod.today, "America/New_York", now),
                         (datetime(2026, 9, 9, 4), datetime(2026, 9, 10, 4)))

    def test_week_starts_monday_and_spring_change_is_167_hours(self):
        start, end = period_bounds(PostPeriod.week, "America/New_York", datetime(2026, 3, 8, 12))
        self.assertEqual(start, datetime(2026, 3, 2, 5))
        self.assertEqual(end - start, timedelta(hours=167))

    def test_autumn_week_is_169_hours_and_year_rolls_over(self):
        start, end = period_bounds(PostPeriod.week, "America/New_York", datetime(2026, 11, 1, 12))
        self.assertEqual(end - start, timedelta(hours=169))
        self.assertEqual(period_bounds(PostPeriod.month, "Asia/Seoul", datetime(2026, 12, 31)),
                         (datetime(2026, 11, 30, 15), datetime(2026, 12, 31, 15)))
        self.assertEqual(period_bounds(PostPeriod.year, "UTC", datetime(2026, 12, 31)),
                         (datetime(2026, 1, 1), datetime(2027, 1, 1)))


class MediaTests(unittest.TestCase):
    def test_image_type_comes_from_content(self):
        file = io.BytesIO()
        Image.new("RGB", (3, 3)).save(file, format="PNG")
        self.assertEqual(media_storage.inspect_upload(file), ("image/png", len(file.getvalue())))

    def test_html_and_oversized_media_are_rejected(self):
        with self.assertRaises(HTTPException):
            media_storage.inspect_upload(io.BytesIO(b"<script>alert(1)</script>"))
        file = io.BytesIO()
        file.seek(media_storage.VIDEO_LIMIT)
        file.write(b"x")
        with self.assertRaises(HTTPException) as error:
            media_storage.inspect_upload(file)
        self.assertEqual(error.exception.status_code, 413)


@unittest.skipUnless(os.getenv("USER_COMMUNITY_TEST_MYSQL") == "1", "Requires the isolated local MySQL test instance")
class CommunityDatabaseCase(unittest.TestCase):
    management_schema = True
    social_webhooks_schema = True
    account_management_schema = True
    post_drafts_schema = True
    @classmethod
    def setUpClass(cls):
        cls.config = {"host": "127.0.0.1", "port": 14873, "user": "root", "password": "", "connection_timeout": 5}
        with mysql.connector.connect(**cls.config) as conn, conn.cursor() as cur:
            cur.execute("SELECT @@datadir")
            actual = Path(cur.fetchone()[0]).resolve()
            expected = Path(__file__).resolve().parents[2] / "logs/user-community-mysql-test/data"
            if actual != expected.resolve():
                raise AssertionError(f"Refusing non-test MySQL: {actual}")

    def setUp(self):
        self.database = "community_test_" + uuid4().hex
        with mysql.connector.connect(**self.config) as conn, conn.cursor() as cur:
            cur.execute(f"CREATE DATABASE {self.database} CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci")
        self.configured = {**self.config, "database": self.database}
        self.pool_patch = patch.object(db, "_pool", SimpleNamespace(get_connection=lambda: mysql.connector.connect(**self.configured)))
        self.pool_patch.start()
        self.secret_patch = patch.dict(os.environ, {"AUTH_CODE_SECRET": "test-secret-not-used-outside-tests-123456"})
        self.secret_patch.start()
        self.execute("CREATE TABLE teams (team_id BIGINT UNSIGNED PRIMARY KEY,name VARCHAR(100),short_code VARCHAR(10),image_path TEXT)")
        self.execute("CREATE TABLE players (player_id BIGINT UNSIGNED PRIMARY KEY,display_name VARCHAR(100),image_path TEXT)")
        self.execute("CREATE TABLE competitions (competition_id BIGINT UNSIGNED PRIMARY KEY,competition_type VARCHAR(20))")
        self.execute("CREATE TABLE seasons (season_id BIGINT UNSIGNED PRIMARY KEY,competition_id BIGINT UNSIGNED,is_current INT)")
        self.execute("CREATE TABLE team_seasons (team_id BIGINT UNSIGNED,season_id BIGINT UNSIGNED)")
        self.execute("CREATE TABLE fixtures (fixture_id BIGINT UNSIGNED PRIMARY KEY,home_team_id BIGINT UNSIGNED,away_team_id BIGINT UNSIGNED)")
        # 교체 전 빈 테이블만 모사해요. 운영 테이블을 복사하거나 변경하지 않아요.
        for table in ("post_reports", "posts", "user_following_teams", "user_profiles", "users"):
            self.execute(f"CREATE TABLE {table} (old_id INT)")
        sql = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_user_community_minimal.sql"
        for statement in sql.read_text(encoding="utf-8").split(";"):
            if statement.strip():
                self.execute(statement)
        # 실제 배포처럼 최초 스키마 위에 후속 ALTER를 적용해요.
        if self.management_schema:
            self.apply_management_schema()
            if self.social_webhooks_schema:
                self.apply_social_webhooks_schema()
                if self.account_management_schema:
                    self.apply_account_management_schema()
                    if self.post_drafts_schema:
                        self.apply_post_drafts_schema()
        self.execute("INSERT INTO teams (team_id,name) VALUES (6,'A'),(14,'B'),(503,'C'),(591,'D')")
        self.execute("INSERT INTO players VALUES (832,'Player A',NULL),(268,'Player B',NULL)")
        self.execute("INSERT INTO competitions VALUES (8,'league'),(82,'league'),(301,'league')")
        self.execute("INSERT INTO seasons VALUES (100,8,1),(200,82,1),(300,301,1)")
        self.execute("INSERT INTO team_seasons VALUES (6,100),(14,100),(503,200),(591,300)")
        self.execute("INSERT INTO fixtures VALUES (10,6,503),(20,14,591)")
        self.a, self.token_a = self.user("alpha", 6)
        self.b, self.token_b = self.user("beta", 503)
        self.c, self.token_c = self.user("gamma", 14)
        self.client = TestClient(create_app())
        # 운영의 단일 event loop처럼 여러 테스트 소켓도 같은 portal을 공유해야 해요.
        self.client.__enter__()

    def tearDown(self):
        self.client.__exit__(None, None, None)
        self.client.close()
        self.secret_patch.stop()
        self.pool_patch.stop()
        # setUpClass에서 datadir를 확인한 전용 테스트 서버의 임의 테스트 DB만 정리해요.
        with mysql.connector.connect(**self.config) as conn, conn.cursor() as cur:
            cur.execute(f"DROP DATABASE {self.database}")

    def execute(self, sql, params=()):
        with mysql.connector.connect(**self.configured) as conn, conn.cursor(dictionary=True) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall() if cur.with_rows else cur.lastrowid
            conn.commit()
            return rows

    def apply_management_schema(self):
        sql = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_community_management.sql"
        for statement in sql.read_text(encoding="utf-8").split(";"):
            if statement.strip():
                self.execute(statement)

    def apply_social_webhooks_schema(self):
        sql = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_social_webhook_receipts.sql"
        for statement in sql.read_text(encoding="utf-8").split(";"):
            if statement.strip():
                self.execute(statement)

    def user(self, username, favorite=None):
        user_id = self.execute("INSERT INTO users (username,first_name,last_name,created_at) VALUES (%s,'First','Last',%s)", (username, utc_now()))
        if favorite:
            # 테스트 입력은 구·신 스키마에 공통인 관계로 준비하고, 변경 규칙은 각 API 테스트에서 검사해요.
            self.execute("""INSERT INTO user_following_teams (user_id,competition_id,team_id,position)
                SELECT %s,s.competition_id,ts.team_id,0 FROM team_seasons ts
                JOIN seasons s ON s.season_id=ts.season_id WHERE ts.team_id=%s""", (user_id, favorite))
            self.execute("UPDATE users SET favorite_team_id=%s WHERE user_id=%s", (favorite, user_id))
        with db.transaction() as conn, conn.cursor(dictionary=True) as cur:
            token = auth_repo._create_session(cur, user_id)["access_token"]
        return user_id, token

    def request(self, method, url, token=None, **kwargs):
        return self.client.request(method, url, headers={"Authorization": f"Bearer {token or self.token_a}"}, **kwargs)

    def post(self, user_id=None, team_id=6, **kwargs):
        return posts_repo.create_post(user_id or self.a, team_id, "general", "Title", "Body", kwargs.get("attachment_ids", []))

    def apply_account_management_schema(self):
        sql = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_account_management.sql"
        for statement in sql.read_text(encoding="utf-8").split(";"):
            if statement.strip():
                self.execute(statement)

    def apply_post_drafts_schema(self):
        sql = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_post_drafts.sql"
        for statement in sql.read_text(encoding="utf-8").split(";"):
            if statement.strip():
                self.execute(statement)


class MigrationPreservationTests(CommunityDatabaseCase):
    management_schema = False

    def test_existing_users_posts_replies_sessions_and_attachments_survive_alter(self):
        now = utc_now()
        post = self.execute("INSERT INTO posts (team_id,user_id,category,title,body,created_at) VALUES (6,%s,'news','Old title','Old body',%s)", (self.a, now))
        comment = self.execute("INSERT INTO post_comments (post_id,user_id,body,created_at) VALUES (%s,%s,'Old comment',%s)", (post, self.a, now))
        self.execute("INSERT INTO post_comments (post_id,user_id,reply_to_id,body,created_at) VALUES (%s,%s,%s,'Old reply',%s)", (post, self.a, comment, now))
        self.execute("INSERT INTO post_attachments (user_id,post_id,position,link_url,created_at) VALUES (%s,%s,0,'https://example.com',%s)", (self.a, post, now))
        self.execute("INSERT INTO fixture_chat_messages (fixture_id,user_id,body,created_at) VALUES (10,%s,'Old message',%s)", (self.a, now))
        tables = ("users", "posts", "post_comments", "post_attachments", "fixture_chat_messages", "user_sessions", "user_following_teams")
        before = {table: self.execute(f"SELECT * FROM {table}") for table in tables}
        verify_schema(before=True)
        self.apply_management_schema()
        verify_schema(before=False)
        for table, original in before.items():
            current = self.execute(f"SELECT * FROM {table}")
            self.assertEqual([{key: row[key] for key in original[0]} for row in current], original, table)
        self.assertEqual(posts_repo.get_post(self.a, post)["body"], "Old body")
        self.assertEqual(posts_repo.list_comments(self.a, post, 0, 10)[1]["reply_to_id"], comment)


class MySQLCommunityTests(CommunityDatabaseCase):

    def test_schema_after_matches_minimal_contract(self):
        report = verify_account_schema(before=False)
        self.assertEqual(report["tables"]["users"], 3)

    def test_follower_count_uses_home_team_and_tracks_changes_and_deletion(self):
        url = "/v1/community/followers?team_id=6"
        self.assertEqual(self.client.get(url).status_code, 401)
        self.assertEqual(self.request("GET", url, self.token_b).status_code, 403)
        self.execute("INSERT INTO user_following_teams VALUES (%s,8,6,1)", (self.b,))
        self.assertEqual(self.request("GET", url).json(), {"team_id": 6, "follower_count": 1})
        changed = self.request("PUT", "/v1/users/me/following/teams", self.token_b,
                               json={"teamIds": [6, 503], "favoriteTeamId": 6})
        self.assertEqual(changed.status_code, 200)
        self.assertEqual(self.request("GET", url).json()["follower_count"], 2)
        self.request("PUT", f"/v1/users/me/blocks/{self.b}")
        self.execute("UPDATE users SET suspended_until=%s WHERE user_id=%s", (utc_now() + timedelta(days=1), self.b))
        self.assertEqual(self.request("GET", url).json()["follower_count"], 2)
        self.assertEqual(self.request("DELETE", "/v1/users/me", self.token_b).status_code, 200)
        self.assertEqual(self.request("GET", url).json()["follower_count"], 1)

    def test_common_rules_share_one_row_and_require_community_or_admin_access(self):
        url = "/v1/community/rules?team_id=6"
        admin_url = "/v1/admin/community/rules"
        self.assertEqual(self.client.get(url).status_code, 401)
        self.assertEqual(self.request("GET", url).json(), {"rules": None})
        self.assertEqual(self.request("GET", url, self.token_b).status_code, 403)
        self.assertEqual(self.request("PUT", admin_url, json={"body": "Rules"}).status_code, 403)
        with patch.dict(os.environ, {"COMMUNITY_ADMIN_USER_IDS": str(self.a)}):
            self.assertEqual(self.request("GET", admin_url).json(), {"rules": None})
            for content in ("First rules", "Updated rules"):
                self.assertEqual(self.request("PUT", admin_url, json={"body": content}).status_code, 200)
                first = self.request("GET", url).json()
                second = self.request("GET", "/v1/community/rules?team_id=503", self.token_b).json()
                self.assertEqual(first, {"rules": {"body": content}})
                self.assertEqual(first, second)
                self.assertEqual(self.request("GET", admin_url).json(), first)
            self.assertEqual(self.request("PUT", admin_url, json={"body": "   "}).status_code, 422)
            self.assertEqual(self.request("PUT", admin_url, self.token_b, json={"body": "Changed"}).status_code, 403)
        self.assertEqual(self.execute("SELECT * FROM community_rules"), [{"rules_id": 1, "body": "Updated rules"}])
        with self.assertRaises(mysql.connector.DatabaseError) as error:
            self.execute("INSERT INTO community_rules VALUES (2,'Another copy')")
        self.assertEqual(error.exception.errno, 3819)

    def test_untrusted_user_header_and_expired_session_are_rejected(self):
        self.assertEqual(self.client.get("/v1/users/me", headers={"X-User-Id": str(self.a)}).status_code, 401)
        self.execute("UPDATE user_sessions SET expires_at=%s", (utc_now() - timedelta(seconds=1),))
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 401)

    def test_logout_invalidates_the_token(self):
        self.assertEqual(self.request("POST", "/v1/auth/logout").status_code, 200)
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 401)

    def test_signup_code_is_consumed_and_password_is_hashed(self):
        with patch.object(auth_repo, "send_verification_code") as send:
            challenge = auth_repo.request_email_code("new@example.com", "signup")["challenge_id"]
        code = send.call_args.args[1]
        self.assertRegex(code, r"^\d{6}$")
        profile = {"username": "new", "first_name": "First", "last_name": "Last"}
        token = auth_repo.register_email(challenge, code, "Password123", profile)["access_token"]
        row = self.execute("SELECT password_hash FROM user_email_credentials")[0]
        self.assertNotEqual(row["password_hash"], "Password123")
        self.assertEqual(auth_repo.session_user(token)["username"], "new")
        with self.assertRaises(HTTPException):
            auth_repo.register_email(challenge, code, "Password123", profile)
        self.assertEqual(len(self.execute("SELECT * FROM user_email_credentials")), 1)

    def test_signup_logout_and_login_with_username(self):
        with patch.object(auth_repo, "send_verification_code") as send:
            challenge = auth_repo.request_email_code("signup@example.com", "signup")["challenge_id"]
        registered = self.request("POST", "/v1/auth/email/register", json={
            "challenge_id": challenge, "code": send.call_args.args[1], "password": "Abcdefg1",
            "username": "newmember", "first_name": "F", "last_name": "L"})
        self.assertEqual(registered.status_code, 201, registered.text)
        token = registered.json()["access_token"]
        user_id = auth_repo.session_user(token)["user_id"]
        self.assertEqual(self.request("POST", "/v1/auth/logout", token).status_code, 200)
        logged_in = self.request("POST", "/v1/auth/login", json={"username": "newmember", "password": "Abcdefg1"})
        self.assertEqual(logged_in.status_code, 200, logged_in.text)
        self.assertEqual(auth_repo.session_user(logged_in.json()["access_token"])["user_id"], user_id)

    def test_email_address_and_wrong_password_do_not_authenticate(self):
        self.execute("INSERT INTO user_email_credentials VALUES (%s,%s,%s)",
                     (self.a, "alpha@example.com", auth_security.PASSWORDS.hash("Password123")))
        for body in ({"username": "alpha@example.com", "password": "Password123"},
                     {"username": "alpha", "password": "WrongPassword123"},
                     {"username": "missing", "password": "Password123"}):
            self.assertEqual(self.request("POST", "/v1/auth/login", json=body).status_code, 401)
        self.assertEqual(self.request("POST", "/v1/auth/login", json={"email": "alpha@example.com", "password": "Password123"}).status_code, 422)
        self.assertEqual(len(self.execute("SELECT * FROM user_sessions")), 3)
        self.assertNotIn("/v1/auth/email/login", self.client.app.openapi()["paths"])

    def test_password_login_uses_current_username_and_keeps_social_only_accounts_separate(self):
        self.execute("INSERT INTO user_email_credentials VALUES (%s,%s,%s)",
                     (self.a, "alpha@example.com", auth_security.PASSWORDS.hash("Password123")))
        response = self.request("PUT", "/v1/users/me/profile", json={
            "username": "renamed", "first_name": "F", "last_name": "L"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(auth_repo.session_user(auth_repo.login_password("renamed", "Password123")["access_token"])["user_id"], self.a)
        with self.assertRaises(HTTPException):
            auth_repo.login_password("alpha", "Password123")
        # 소셜 회원의 표시용 username만으로 비밀번호 로그인 계정을 새로 만들지 않아요.
        self.execute("INSERT INTO user_social_identities VALUES ('google','test-subject',%s)", (self.b,))
        with self.assertRaises(HTTPException):
            auth_repo.login_password("beta", "Password123")
        self.assertEqual(len(self.execute("SELECT * FROM user_email_credentials")), 1)

    def test_failed_code_attempts_are_committed_and_cannot_be_reset_by_verification(self):
        with patch.object(auth_repo, "send_verification_code") as send:
            challenge = auth_repo.request_email_code("attempts@example.com", "signup")["challenge_id"]
        code = send.call_args.args[1]
        wrong = "000000" if code != "000000" else "111111"
        profile = {"username": "new", "first_name": "F", "last_name": "L"}
        for _ in range(5):
            with self.assertRaises(HTTPException):
                auth_repo.register_email(challenge, wrong, "Password123", profile)
        self.assertEqual(self.execute("SELECT attempts FROM email_verification_codes")[0]["attempts"], 5)
        with self.assertRaises(HTTPException):
            auth_repo.register_email(challenge, code, "Password123", profile)

    def test_email_failure_does_not_store_usable_code(self):
        with patch.object(auth_repo, "send_verification_code", side_effect=HTTPException(502, "SES unavailable")):
            with self.assertRaises(HTTPException):
                auth_repo.request_email_code("fail@example.com", "signup")
        self.assertEqual(self.execute("SELECT * FROM email_verification_codes"), [])

    def test_password_reset_invalidates_old_sessions(self):
        self.execute("INSERT INTO user_email_credentials VALUES (%s,%s,%s)",
                     (self.a, "alpha@example.com", auth_security.PASSWORDS.hash("Password123")))
        with patch.object(auth_repo, "send_verification_code") as send:
            challenge = auth_repo.request_email_code("alpha@example.com", "password_reset")["challenge_id"]
        auth_repo.reset_password(challenge, send.call_args.args[1], "ChangedPassword123")
        with self.assertRaises(HTTPException):
            auth_repo.session_user(self.token_a)
        auth_repo.login_password("alpha", "ChangedPassword123")

    def test_first_favorite_change_and_concurrent_second_change(self):
        teams_repo.set_following_and_favorite(self.a, [6, 503], 503)
        r = self.request("PUT", "/v1/users/me/following/teams", json={"teamIds": [6, 503], "favoriteTeamId": 6})
        self.assertEqual(r.status_code, 409)
        self.assertIn("available_at", r.json()["detail"])
        self.assertEqual(users_repo.get_favorite_team_id(self.a), 503)

    def test_two_initial_changes_cannot_both_use_free_change(self):
        def change(team):
            try:
                teams_repo.set_following_and_favorite(self.a, [6, 503, 591], team)
                return "ok"
            except ValueError:
                return "blocked"
        with ThreadPoolExecutor(2) as executor:
            results = list(executor.map(change, [503, 591]))
        self.assertCountEqual(results, ["ok", "blocked"])

    def test_simultaneous_first_social_login_creates_one_user(self):
        with mysql.connector.connect(**self.configured) as conn, conn.cursor(dictionary=True) as cur:
            cursor_class = type(cur)
        original = cursor_class.execute
        barrier = Barrier(2)
        def synchronized(cursor, query, *args, **kwargs):
            result = original(cursor, query, *args, **kwargs)
            if query.startswith("SELECT user_id FROM user_social_identities WHERE") and "FOR UPDATE" not in query:
                barrier.wait(timeout=5)
            return result
        with patch.object(cursor_class, "execute", synchronized), ThreadPoolExecutor(2) as executor:
            tokens = list(executor.map(lambda _: auth_repo.login_social("google", "same-subject"), range(2)))
        users = [auth_repo.session_user(result["access_token"])["user_id"] for result in tokens]
        self.assertEqual(users[0], users[1])
        self.assertEqual(len(self.execute("SELECT * FROM users")), 4)

    def test_invalid_team_selection_rolls_back_existing_selection(self):
        for ids, favorite in (([6, 14], 6), ([6], 503), ([], 6)):
            with self.assertRaises(ValueError):
                teams_repo.set_following_and_favorite(self.a, ids, favorite)
        self.assertEqual(teams_repo.list_following_team_ids(self.a), [6])

    def test_following_order_and_player_order_are_preserved(self):
        r = self.request("PUT", "/v1/users/me/following/teams", json={"teamIds": [503, 6], "favoriteTeamId": 6})
        self.assertEqual(r.status_code, 200)
        self.assertEqual([x["team_id"] for x in self.request("GET", "/v1/users/me/following/teams").json()], [503, 6])
        self.request("PUT", "/v1/users/me/following/players", json={"player_ids": [268, 832]})
        self.assertEqual([x["player_id"] for x in self.request("GET", "/v1/users/me/following/players").json()["items"]], [268, 832])

    def test_only_home_team_can_read_write_like_and_report(self):
        post_id = self.post()
        teams_repo.set_following_and_favorite(self.b, [6, 503], 503)
        for method, path, body in [("GET", f"/v1/posts/{post_id}", None), ("GET", "/v1/posts?team_id=6", None),
                                  ("GET", f"/v1/posts/{post_id}/comments", None), ("PUT", f"/v1/posts/{post_id}/like", None),
                                  ("POST", f"/v1/posts/{post_id}/report", {"reason": "Spam"}),
                                  ("POST", f"/v1/posts/{post_id}/comments", {"body": "comment"})]:
            self.assertEqual(self.request(method, path, self.token_b, json=body).status_code, 403, path)

    def test_likes_are_idempotent_and_best_threshold_is_ten(self):
        post_id = self.post()
        for _ in range(2):
            posts_repo.set_like(self.a, "post", post_id, True)
        self.assertEqual(posts_repo.get_post(self.a, post_id)["like_count"], 1)
        self.assertEqual(self.request("GET", "/v1/posts?team_id=6&sort=best").json()["items"], [])
        for index in range(9):
            liker, _ = self.user(f"liker{index}", 6)
            posts_repo.set_like(liker, "post", post_id, True)
        self.assertEqual(len(self.request("GET", "/v1/posts?team_id=6&sort=best").json()["items"]), 1)
        posts_repo.set_like(self.a, "post", post_id, False)
        self.assertEqual(self.request("GET", "/v1/posts?team_id=6&sort=best").json()["items"], [])

    def test_popular_sort_and_local_date_filter(self):
        first, second = self.post(), self.post()
        self.execute("UPDATE posts SET created_at=%s WHERE post_id=%s", (datetime(2026, 9, 9, 14), first))
        self.execute("UPDATE posts SET created_at=%s WHERE post_id=%s", (datetime(2026, 9, 10, 1), second))
        posts_repo.set_like(self.a, "post", first, True)
        with patch.object(posts_repo, "utc_now", return_value=datetime(2026, 9, 10, 2)):
            items = self.request("GET", "/v1/posts?team_id=6&sort=popular&period=today&timezone=Asia/Seoul").json()["items"]
            other_device = self.request("GET", "/v1/posts?team_id=6&sort=popular&period=today&timezone=America/New_York").json()["items"]
            self.assertEqual(self.request("GET", "/v1/posts?team_id=6&period=today").status_code, 422)
            self.assertEqual(self.request("GET", "/v1/posts?team_id=6&period=today&timezone=wrong").status_code, 422)
        self.assertEqual([x["post_id"] for x in items], [second])
        self.assertEqual([x["post_id"] for x in other_device], [first, second])
        self.assertNotIn("timezone", self.request("GET", "/v1/users/me").json())

    def test_nested_replies_preserve_target_and_other_post_is_rejected(self):
        one, two = self.post(), self.post()
        parent = posts_repo.create_comment(self.a, one, "first", None)
        reply = posts_repo.create_comment(self.a, one, "reply", parent)
        nested = posts_repo.create_comment(self.a, one, "nested", reply)
        with self.assertRaises(HTTPException):
            posts_repo.create_comment(self.a, two, "wrong", reply)
        items = posts_repo.list_comments(self.a, one, 0, 50)
        self.assertEqual([x["reply_to_id"] for x in items], [None, parent, reply])
        posts_repo.set_like(self.a, "comment", nested, True)
        posts_repo.set_like(self.a, "comment", nested, True)
        self.assertEqual(posts_repo.list_comments(self.a, one, 0, 50)[-1]["like_count"], 1)

    def test_foreign_attachment_rejects_post_and_rolls_back(self):
        item = self.request("POST", "/v1/attachments/link", self.token_b, json={"url": "https://example.com/"}).json()["attachment_id"]
        with self.assertRaises(HTTPException):
            self.post(attachment_ids=[item])
        self.assertEqual(self.execute("SELECT * FROM posts"), [])

    def test_attachment_access_changes_with_home_team(self):
        key = "posts/test-key"
        attachment_id = self.execute("INSERT INTO post_attachments (user_id,object_key,content_type,byte_size,created_at) VALUES (%s,%s,'image/png',3,%s)", (self.a, key, utc_now()))
        post_id = self.post(attachment_ids=[attachment_id])
        with patch.object(media_storage, "object_operation") as storage:
            denied = self.request("GET", f"/v1/attachments/{attachment_id}/content", self.token_b)
            self.assertEqual(denied.status_code, 403)
            storage.assert_not_called()
        teams_repo.set_following_and_favorite(self.a, [503], 503)
        self.assertEqual(self.request("GET", f"/v1/posts/{post_id}").status_code, 403)
        self.assertEqual(self.request("GET", f"/v1/attachments/{attachment_id}/content").status_code, 403)

    def test_uploaded_file_uses_verified_type_and_serves_private_byte_range(self):
        file = io.BytesIO()
        Image.new("RGB", (3, 3)).save(file, format="PNG")
        data = file.getvalue()
        with patch.object(media_storage, "object_operation") as storage:
            response = self.request("POST", "/v1/attachments/upload",
                                    files={"file": ("wrong.html", data, "text/html")})
            self.assertEqual(response.status_code, 201, response.text)
            self.assertEqual(storage.call_args.kwargs["ContentType"], "image/png")
            self.assertEqual(storage.call_args.kwargs["ContentLength"], len(data))
            attachment_id = response.json()["attachment_id"]
            stored = self.execute("SELECT * FROM post_attachments WHERE attachment_id=%s", (attachment_id,))[0]
            storage.return_value = {"Body": StreamingBody(io.BytesIO(data[2:8]), 6),
                                    "ContentLength": 6, "ContentRange": f"bytes 2-7/{len(data)}"}
            response = self.client.get(f"/v1/attachments/{attachment_id}/content",
                                       headers={"Authorization": f"Bearer {self.token_a}", "Range": "bytes=2-7"})
            self.assertEqual(response.status_code, 206)
            self.assertEqual(response.content, data[2:8])
            self.assertEqual(response.headers["cache-control"], "private, no-store")
            self.assertEqual(response.headers["x-content-type-options"], "nosniff")
            storage.assert_called_with("get_object", Key=stored["object_key"], Range="bytes=2-7")
            storage.reset_mock()
            response = self.client.get(f"/v1/attachments/{attachment_id}/content",
                                       headers={"Authorization": f"Bearer {self.token_a}", "Range": "bytes=9999-"})
            self.assertEqual(response.status_code, 416)
            storage.assert_not_called()

    def test_upload_failure_rolls_back_attachment(self):
        file = io.BytesIO()
        Image.new("RGB", (3, 3)).save(file, format="PNG")
        with patch.object(media_storage, "object_operation", side_effect=HTTPException(502, "R2 unavailable")):
            response = self.request("POST", "/v1/attachments/upload", files={"file": ("image.png", file.getvalue())})
        self.assertEqual(response.status_code, 502)
        self.assertEqual(self.execute("SELECT * FROM post_attachments"), [])

    def test_post_attachment_order_and_draft_deletion(self):
        ids = [self.request("POST", "/v1/attachments/link", json={"url": f"https://example.com/{i}"}).json()["attachment_id"] for i in range(3)]
        self.assertEqual(self.request("DELETE", f"/v1/attachments/{ids[0]}", self.token_b).status_code, 403)
        self.assertEqual(self.request("DELETE", f"/v1/attachments/{ids[0]}").status_code, 200)
        post_id = self.post(attachment_ids=ids[:0:-1])
        self.assertEqual([row["attachment_id"] for row in posts_repo.get_post(self.a, post_id)["attachments"]], ids[:0:-1])
        self.assertEqual(self.request("DELETE", f"/v1/attachments/{ids[1]}").status_code, 403)

    def test_chat_history_both_teams_and_other_fixture_denied(self):
        chat_repo.create_message(self.a, 10, "hello")
        self.assertEqual(self.request("GET", "/v1/fixtures/10/chat/messages", self.token_b).status_code, 200)
        self.assertEqual(self.request("GET", "/v1/fixtures/10/chat/messages", self.token_c).status_code, 403)
        self.assertEqual(self.request("GET", "/v1/fixtures/20/chat/messages").status_code, 403)

    def test_websocket_messages_persist_and_use_session_username(self):
        with self.client.websocket_connect("/v1/fixtures/10/chat") as a:
            a.send_json({"token": self.token_a})
            self.assertEqual(a.receive_json()["type"], "ready")
            with self.client.websocket_connect("/v1/fixtures/10/chat") as b:
                b.send_json({"token": self.token_b})
                b.receive_json()
                a.send_json({"text": "hello"})
                one, two = a.receive_json(), b.receive_json()
                self.assertEqual(one, two)
                self.assertEqual(one["username"], "alpha")
                self.assertTrue(one["created_at"].endswith("Z"))
        self.assertEqual(len(chat_repo.history(self.a, 10, None, None, 50)), 1)

    def test_websocket_revokes_access_after_favorite_change(self):
        from starlette.websockets import WebSocketDisconnect
        with self.client.websocket_connect("/v1/fixtures/10/chat") as socket:
            socket.send_json({"token": self.token_a})
            socket.receive_json()
            teams_repo.set_following_and_favorite(self.a, [14], 14)
            socket.send_json({"text": "not allowed"})
            with self.assertRaises(WebSocketDisconnect) as error:
                socket.receive_json()
            self.assertEqual(error.exception.code, 4403)
        self.assertEqual(self.execute("SELECT * FROM fixture_chat_messages"), [])

    def test_websocket_revoked_recipient_does_not_receive_next_message(self):
        from starlette.websockets import WebSocketDisconnect
        with self.client.websocket_connect("/v1/fixtures/10/chat") as a:
            a.send_json({"token": self.token_a})
            a.receive_json()
            with self.client.websocket_connect("/v1/fixtures/10/chat") as b:
                b.send_json({"token": self.token_b})
                b.receive_json()
                auth_repo.logout(self.token_b)
                a.send_json({"text": "after logout"})
                self.assertEqual(a.receive_json()["text"], "after logout")
                with self.assertRaises(WebSocketDisconnect) as error:
                    b.receive_json()
                self.assertEqual(error.exception.code, 4401)

    def test_websocket_binary_frame_is_rejected_as_invalid_text(self):
        from starlette.websockets import WebSocketDisconnect
        with self.client.websocket_connect("/v1/fixtures/10/chat") as socket:
            socket.send_json({"token": self.token_a})
            socket.receive_json()
            socket.send_bytes(b"not a text frame")
            with self.assertRaises(WebSocketDisconnect) as error:
                socket.receive_json()
            self.assertEqual(error.exception.code, 4400)
        self.assertEqual(self.execute("SELECT * FROM fixture_chat_messages"), [])

    def test_edit_post_preserves_creation_and_reorders_own_attachments(self):
        ids = [self.request("POST", "/v1/attachments/link", json={"url": f"https://example.com/{i}"}).json()["attachment_id"] for i in range(3)]
        post = self.post(attachment_ids=ids[:2])
        created = self.execute("SELECT created_at FROM posts WHERE post_id=%s", (post,))[0]["created_at"]
        body = {"category": "news", "title": "Edited", "body": "Changed", "attachment_ids": ids[::-1]}
        self.assertEqual(self.request("PUT", f"/v1/posts/{post}", json=body).status_code, 200)
        item = self.request("GET", f"/v1/posts/{post}").json()
        self.assertEqual([row["attachment_id"] for row in item["attachments"]], ids[::-1])
        self.assertIsNotNone(item["edited_at"])
        self.assertEqual(self.execute("SELECT created_at FROM posts WHERE post_id=%s", (post,))[0]["created_at"], created)
        other, token = self.user("other-editor", 6)
        self.assertEqual(self.request("PUT", f"/v1/posts/{post}", token, json=body).status_code, 403)
        self.assertEqual(self.request("DELETE", f"/v1/posts/{post}", token).status_code, 403)
        foreign = self.request("POST", "/v1/attachments/link", token, json={"url": "https://example.com/foreign"}).json()["attachment_id"]
        self.assertEqual(self.request("PUT", f"/v1/posts/{post}", json={**body, "attachment_ids": [foreign]}).status_code, 400)
        self.assertEqual([row["attachment_id"] for row in posts_repo.get_post(self.a, post)["attachments"]], ids[::-1])

    def test_deleted_post_hides_children_and_queues_only_its_file(self):
        attachment = self.execute("INSERT INTO post_attachments (user_id,object_key,content_type,byte_size,created_at) VALUES (%s,'posts/remove','image/png',3,%s)", (self.a, utc_now()))
        post = self.post(attachment_ids=[attachment])
        comment = posts_repo.create_comment(self.a, post, "comment", None)
        posts_repo.report_content(self.a, "post", post, "report")
        self.assertEqual(self.request("DELETE", f"/v1/posts/{post}").status_code, 200)
        self.assertEqual(self.execute("SELECT object_key FROM media_deletions"), [{"object_key": "posts/remove"}])
        for method, url, payload in [("GET", f"/v1/posts/{post}", None), ("GET", f"/v1/posts/{post}/comments", None),
                                     ("PUT", f"/v1/comments/{comment}/like", None), ("GET", f"/v1/attachments/{attachment}/content", None),
                                     ("POST", f"/v1/posts/{post}/comments", {"body": "late"})]:
            self.assertEqual(self.request(method, url, json=payload).status_code, 404, url)
        self.assertEqual(self.request("GET", "/v1/posts?team_id=6").json()["items"], [])
        self.assertEqual(len(self.execute("SELECT * FROM content_reports")), 1)

    def test_deleted_comment_keeps_nested_reply_ids_without_original_text(self):
        post = self.post()
        parent = posts_repo.create_comment(self.a, post, "parent", None)
        child = posts_repo.create_comment(self.a, post, "reply", parent)
        self.assertEqual(self.request("PUT", f"/v1/comments/{parent}", json={"body": "edited", "reply_to_id": child}).status_code, 422)
        self.assertEqual(self.request("PUT", f"/v1/comments/{parent}", json={"body": "edited"}).status_code, 200)
        self.assertEqual(self.request("DELETE", f"/v1/comments/{parent}").status_code, 200)
        items = posts_repo.list_comments(self.a, post, 0, 10)
        self.assertEqual((items[0]["body"], items[0]["state"], items[1]["reply_to_id"]), ("", "deleted", parent))
        self.assertEqual(posts_repo.get_post(self.a, post)["comment_count"], 1)
        self.assertEqual(self.request("POST", f"/v1/posts/{post}/comments", json={"body": "late", "reply_to_id": parent}).status_code, 400)

    def test_block_applies_only_to_viewer_and_direct_content_access(self):
        other, token = self.user("blocked-writer", 6)
        own_post, other_post = self.post(), self.post(other)
        comment = posts_repo.create_comment(other, own_post, "hidden reply", None)
        self.assertEqual(self.request("PUT", f"/v1/users/me/blocks/{other}").status_code, 200)
        self.assertEqual(self.request("PUT", f"/v1/users/me/blocks/{other}").status_code, 200)
        self.assertEqual(len(self.request("GET", "/v1/users/me/blocks").json()["items"]), 1)
        self.assertEqual([x["post_id"] for x in self.request("GET", "/v1/posts?team_id=6").json()["items"]], [own_post])
        self.assertEqual(self.request("GET", f"/v1/posts/{other_post}").status_code, 404)
        self.assertEqual(self.request("GET", f"/v1/posts/{own_post}", token).status_code, 200)
        hidden = posts_repo.list_comments(self.a, own_post, 0, 10)[0]
        self.assertEqual((hidden["comment_id"], hidden["body"], hidden["state"]), (comment, "", "blocked"))
        self.assertEqual(self.request("PUT", f"/v1/comments/{comment}/like").status_code, 404)
        self.assertEqual(self.request("DELETE", f"/v1/users/me/blocks/{other}").status_code, 200)
        self.assertEqual(self.request("GET", f"/v1/posts/{other_post}").status_code, 200)
        self.assertEqual(self.request("PUT", f"/v1/users/me/blocks/{self.a}").status_code, 400)

    def test_live_chat_block_hides_sender_without_disconnecting_recipient(self):
        self.request("PUT", f"/v1/users/me/blocks/{self.a}", self.token_b)
        with self.client.websocket_connect("/v1/fixtures/10/chat") as a, self.client.websocket_connect("/v1/fixtures/10/chat") as b:
            a.send_json({"token": self.token_a}); a.receive_json()
            b.send_json({"token": self.token_b}); b.receive_json()
            a.send_json({"text": "blocked message"})
            a.receive_json()
            b.send_json({"text": "still connected"})
            self.assertEqual(b.receive_json()["text"], "still connected")
            self.assertEqual(a.receive_json()["text"], "still connected")
            self.request("DELETE", f"/v1/users/me/blocks/{self.a}", self.token_b)
            a.send_json({"text": "unblocked"})
            a.receive_json()
            self.assertEqual(b.receive_json()["text"], "unblocked")
        self.request("PUT", f"/v1/users/me/blocks/{self.a}", self.token_b)
        self.assertEqual([x["text"] for x in chat_repo.history(self.b, 10, None, None, 10)], ["still connected"])

    def test_account_deletion_unlinks_authors_and_removes_private_relations(self):
        viewer, token = self.user("remaining-reader", 6)
        published, draft = [self.request("POST", "/v1/attachments/link", json={"url": f"https://example.com/{i}"}).json()["attachment_id"] for i in range(2)]
        post = self.post(attachment_ids=[published])
        comment = posts_repo.create_comment(self.a, post, "preserved", None)
        reply = posts_repo.create_comment(viewer, post, "reply", comment)
        chat_repo.create_message(self.a, 10, "anonymous chat")
        posts_repo.set_like(self.a, "post", post, True)
        self.execute("INSERT INTO user_email_credentials VALUES (%s,'alpha@example.com','not-a-real-hash')", (self.a,))
        self.execute("INSERT INTO user_social_identities VALUES ('google','old-subject',%s)", (self.a,))
        self.execute("INSERT INTO user_avatars VALUES (%s,'avatars/old','image/png',3)", (self.a,))
        self.request("PUT", f"/v1/users/me/blocks/{self.b}")
        self.assertEqual(self.request("DELETE", "/v1/users/me").status_code, 200)
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 401)
        for table in ("users", "user_email_credentials", "user_social_identities", "user_sessions", "user_following_teams", "post_likes", "user_avatars", "user_blocks"):
            self.assertEqual(self.execute(f"SELECT * FROM {table} WHERE user_id=%s", (self.a,)), [], table)
        item = posts_repo.get_post(viewer, post)
        self.assertEqual((item["user_id"], item["username"], item["author_deleted"], item["like_count"]), (None, None, True, 0))
        comments = posts_repo.list_comments(viewer, post, 0, 10)
        self.assertEqual((comments[0]["body"], comments[0]["user_id"], comments[1]["reply_to_id"]), ("preserved", None, comment))
        self.assertIsNone(chat_repo.history(viewer, 10, None, None, 10)[0]["user_id"])
        self.assertEqual(self.execute("SELECT attachment_id FROM post_attachments"), [{"attachment_id": published}])
        self.assertEqual(self.execute("SELECT object_key FROM media_deletions"), [{"object_key": "avatars/old"}])
        self.assertNotEqual(auth_repo.session_user(auth_repo.login_social("google", "old-subject")["access_token"])["user_id"], self.a)

    def test_profile_photo_reuses_verified_upload_and_requires_visible_author(self):
        image = io.BytesIO(); Image.new("RGB", (2, 2)).save(image, format="PNG")
        files = {"file": ("photo.html", image.getvalue(), "text/html")}
        with patch.object(media_storage, "object_operation") as storage:
            self.assertEqual(self.request("PUT", "/v1/users/me/avatar", files=files).status_code, 200)
            first = self.execute("SELECT object_key FROM user_avatars")[0]["object_key"]
            self.assertEqual(self.request("PUT", "/v1/users/me/avatar", files=files).status_code, 200)
            self.assertEqual(self.execute("SELECT object_key FROM media_deletions"), [{"object_key": first}])
            storage.reset_mock()
            self.assertEqual(self.request("GET", f"/v1/users/{self.a}/avatar", self.token_b).status_code, 404)
            storage.assert_not_called()
            chat_repo.create_message(self.a, 10, "visible author")
            storage.return_value = {"Body": StreamingBody(io.BytesIO(b"abc"), 3), "ContentLength": 3}
            self.assertEqual(self.request("GET", f"/v1/users/{self.a}/avatar", self.token_b).content, b"abc")
            self.request("PUT", f"/v1/users/me/blocks/{self.a}", self.token_b)
            storage.reset_mock()
            self.assertEqual(self.request("GET", f"/v1/users/{self.a}/avatar", self.token_b).status_code, 404)
            storage.assert_not_called()
        self.assertEqual(self.request("DELETE", "/v1/users/me/avatar").status_code, 200)
        self.assertIsNone(self.request("GET", "/v1/users/me").json()["avatar_url"])

    def test_report_resolution_requires_server_admin_and_preserves_evidence(self):
        other, token = self.user("reported-author", 6)
        post = self.post(other)
        posts_repo.report_content(self.a, "post", post, "spam")
        report = self.execute("SELECT report_id FROM content_reports")[0]["report_id"]
        self.assertEqual(self.request("GET", "/v1/admin/reports").status_code, 403)
        with patch.dict(os.environ, {"COMMUNITY_ADMIN_USER_IDS": str(self.a)}):
            self.assertEqual(self.request("GET", "/v1/admin/reports", token).status_code, 403)
            self.assertEqual(self.request("PUT", f"/v1/admin/reports/{report}", json={"resolution": "hidden"}).status_code, 200)
            self.assertEqual(self.request("GET", f"/v1/posts/{post}").status_code, 404)
            reports = self.request("GET", "/v1/admin/reports?resolved=true").json()["items"]
            self.assertEqual((reports[0]["content_body"], reports[0]["resolved_by"]), ("Body", self.a))
            self.assertEqual(self.request("GET", "/v1/admin/reports").json()["items"], [])
            self.assertEqual(self.request("PUT", f"/v1/admin/reports/{report}", json={"resolution": "dismissed"}).status_code, 409)

    def test_suspension_blocks_community_but_allows_account_deletion(self):
        post = self.post()
        with patch.dict(os.environ, {"COMMUNITY_ADMIN_USER_IDS": str(self.b)}):
            url = f"/v1/admin/users/{self.a}/suspension"
            end = (utc_now() + timedelta(days=1)).isoformat() + "Z"
            self.assertEqual(self.request("PUT", url, self.token_b, json={"suspended_until": end}).status_code, 200)
            self.assertEqual(self.request("GET", f"/v1/posts/{post}").status_code, 403)
            self.assertEqual(self.request("GET", "/v1/fixtures/10/chat/messages").status_code, 403)
            self.assertEqual(self.request("GET", "/v1/users/me").status_code, 200)
            self.assertEqual(self.request("PUT", url, self.token_b, json={"suspended_until": None}).status_code, 200)
            self.assertEqual(self.request("GET", f"/v1/posts/{post}").status_code, 200)
            self.request("PUT", url, self.token_b, json={"suspended_until": end})
            self.assertEqual(self.request("DELETE", "/v1/users/me").status_code, 200)

    def test_cleanup_preview_does_not_write_and_storage_failure_keeps_queue(self):
        from one_touch_loader.loaders import community_maintenance
        key = "posts/queued"
        self.execute("INSERT INTO media_deletions VALUES (%s)", (key,))
        self.execute("UPDATE user_sessions SET expires_at=%s WHERE user_id=%s", (utc_now() - timedelta(seconds=1), self.c))
        with patch.object(community_maintenance, "object_operation") as storage:
            report = community_maintenance.maintain_community(check=True)
            self.assertEqual((report["queued_files"], report["user_sessions"]), (1, 1))
            self.assertEqual(len(self.execute("SELECT * FROM user_sessions")), 3)
            storage.assert_not_called()
            storage.side_effect = HTTPException(502, "storage down")
            with self.assertRaises(HTTPException):
                community_maintenance.maintain_community(check=False)
            self.assertEqual(self.execute("SELECT object_key FROM media_deletions"), [{"object_key": key}])
            storage.side_effect = None
            report = community_maintenance.maintain_community(check=False)
            self.assertEqual(report["deleted_files"], 1)
            self.assertEqual(self.execute("SELECT * FROM media_deletions"), [])

    def test_cleanup_never_removes_published_attachments(self):
        from one_touch_loader.loaders.community_maintenance import maintain_community
        published, draft = [self.request("POST", "/v1/attachments/link", json={"url": f"https://example.com/{i}"}).json()["attachment_id"] for i in range(2)]
        self.post(attachment_ids=[published])
        self.execute("UPDATE post_attachments SET created_at=%s", (utc_now() - timedelta(days=8),))
        self.assertEqual(maintain_community(check=True)["unused_attachments"], 1)
        self.assertEqual(maintain_community(check=False)["unused_attachments"], 1)
        self.assertEqual(self.execute("SELECT attachment_id FROM post_attachments"), [{"attachment_id": published}])

    def test_social_account_deletion_requires_unlink_and_rolls_back_on_provider_failure(self):
        self.execute("INSERT INTO user_social_identities VALUES ('apple','apple-sub',%s)", (self.a,))
        self.assertEqual(self.request("DELETE", "/v1/users/me").status_code, 400)
        proof = {"apple": {"code": "fresh-code", "client_id": "our-app", "nonce": "a" * 16}}
        with patch.object(social_login, "unlink_apple", side_effect=HTTPException(503, "provider down")):
            self.assertEqual(self.request("DELETE", "/v1/users/me", json=proof).status_code, 503)
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 200)
        with patch.object(social_login, "unlink_apple") as unlink:
            self.assertEqual(self.request("DELETE", "/v1/users/me", json=proof).status_code, 200)
            unlink.assert_called_once_with("apple-sub", **proof["apple"])

    def test_upload_commit_failure_removes_new_file_without_replacing_avatar(self):
        image = io.BytesIO(); Image.new("RGB", (2, 2)).save(image, format="PNG")
        from one_touch_loader.api.routes import avatars
        from contextlib import contextmanager
        @contextmanager
        def failing_transaction():
            with db.transaction() as conn:
                yield conn
                raise RuntimeError("Commit failed")
        self.execute("INSERT INTO user_avatars VALUES (%s,'avatars/previous','image/png',3)", (self.a,))
        with patch.object(media_storage, "object_operation") as storage, patch.object(avatars, "transaction", failing_transaction):
            with self.assertRaisesRegex(RuntimeError, "Commit failed"):
                self.request("PUT", "/v1/users/me/avatar", files={"file": ("photo.png", image.getvalue())})
        self.assertEqual([call.args[0] for call in storage.call_args_list], ["put_object", "delete_object"])
        self.assertEqual(storage.call_args.kwargs["Key"], storage.call_args_list[0].kwargs["Key"])
        self.assertEqual(self.execute("SELECT object_key FROM user_avatars"), [{"object_key": "avatars/previous"}])
        self.assertEqual(self.execute("SELECT * FROM media_deletions"), [])


class KakaoWebhookTests(CommunityDatabaseCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        provider_tests.ProviderTests.setUpClass()

    def setUp(self):
        super().setUp()
        self.execute("INSERT INTO user_social_identities VALUES ('kakao','321',%s)", (self.a,))
        self.kakao_settings = patch.dict(os.environ, {"KAKAO_APP_ID": "123", "KAKAO_REST_API_KEY": "our-rest-key"})
        self.kakao_settings.start()
        self.addCleanup(self.kakao_settings.stop)
        keys = SimpleNamespace(get_signing_key_from_jwt=lambda token: SimpleNamespace(key=provider_tests.ProviderTests.public))
        self.kakao_keys = patch.object(social_login, "_keys", return_value=keys)
        self.kakao_keys.start()
        self.addCleanup(self.kakao_keys.stop)

    def webhook(self, token=None):
        return self.client.post('/v1/auth/kakao/events', content=token or provider_tests.ProviderTests().kakao_event_token(),
                                headers={'Content-Type': 'application/secevent+jwt'})

    def test_unlink_anonymizes_content_and_repeat_does_not_delete_new_account(self):
        post = self.post()
        comment = posts_repo.create_comment(self.a, post, 'keep reply', None)
        chat_repo.create_message(self.a, 10, 'keep chat')
        self.execute("INSERT INTO user_avatars VALUES (%s,'avatars/old','image/png',3)", (self.a,))
        with patch.object(social_login, 'unlink_kakao') as unlink:
            response = self.webhook()
            self.assertEqual((response.status_code, response.content), (202, b''))
            unlink.assert_not_called()
        self.assertEqual(self.request('GET', '/v1/users/me').status_code, 401)
        self.assertIsNone(self.execute('SELECT user_id FROM posts WHERE post_id=%s', (post,))[0]['user_id'])
        self.assertIsNone(self.execute('SELECT user_id FROM post_comments WHERE comment_id=%s', (comment,))[0]['user_id'])
        self.assertIsNone(self.execute('SELECT user_id FROM fixture_chat_messages')[0]['user_id'])
        self.assertEqual(self.execute('SELECT object_key FROM media_deletions'), [{'object_key': 'avatars/old'}])
        replacement = auth_repo.login_social('kakao', '321')['access_token']
        self.assertEqual(self.webhook().status_code, 202)
        self.assertNotEqual(auth_repo.session_user(replacement)['user_id'], self.a)
        self.assertEqual(len(self.execute('SELECT * FROM social_webhook_receipts')), 1)

    def test_invalid_tokens_never_touch_accounts_and_use_kakao_error_body(self):
        for token in (b'not-signed', provider_tests.ProviderTests().kakao_event_token(app_id='wrong-app')):
            result = self.webhook(token)
            self.assertEqual(result.status_code, 400)
            self.assertEqual(set(result.json()), {'err', 'description'})
        self.assertEqual(self.request('GET', '/v1/users/me').status_code, 200)
        self.assertEqual(self.execute('SELECT * FROM social_webhook_receipts'), [])
        result = self.client.post('/v1/auth/kakao/events', content=b'token', headers={'Content-Type': 'application/json'})
        self.assertEqual((result.status_code, result.json()['err']), (400, 'invalid_request'))

    def test_database_failure_rolls_back_receipt_and_retry_completes(self):
        with patch.object(users_repo, '_delete_account_rows', side_effect=mysql.connector.Error('test database failure')):
            with self.assertRaises(mysql.connector.Error):
                self.webhook()
        self.assertEqual(self.execute('SELECT * FROM social_webhook_receipts'), [])
        self.assertEqual(self.request('GET', '/v1/users/me').status_code, 200)
        self.assertEqual(self.webhook().status_code, 202)

    def test_simultaneous_delivery_and_unknown_member_are_acknowledged(self):
        token = provider_tests.ProviderTests().kakao_event_token()
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: self.webhook(token).status_code, range(2)))
        self.assertEqual(results, [202, 202])
        self.assertEqual(len(self.execute('SELECT * FROM social_webhook_receipts')), 1)
        # 계정 삭제 직후 다른 SET이 도착해도 이미 없는 회원을 오류로 처리하지 않아요.
        self.assertEqual(self.webhook(provider_tests.ProviderTests().kakao_event_token(jti='another-event')).status_code, 202)


class SocialWebhookMigrationTests(CommunityDatabaseCase):
    social_webhooks_schema = False

    def test_existing_kakao_receipts_survive_shared_table_migration(self):
        event_hash = auth_security.token_hash("previously-processed-event")
        self.execute("INSERT INTO kakao_webhook_receipts VALUES (%s)", (event_hash,))
        before_users = self.execute("SELECT * FROM users ORDER BY user_id")
        verify_social_schema(before=True)
        self.apply_social_webhooks_schema()
        verify_social_schema(before=False)
        self.assertEqual(self.execute("SELECT * FROM social_webhook_receipts"),
                         [{"provider": "kakao", "event_hash": event_hash}])
        self.assertEqual(self.execute("SELECT * FROM users ORDER BY user_id"), before_users)
        self.execute("INSERT INTO user_social_identities VALUES ('kakao','321',%s)", (self.a,))
        users_repo.delete_social_account("kakao", "321", "previously-processed-event")
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 200)


class AppleWebhookTests(CommunityDatabaseCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        provider_tests.ProviderTests.setUpClass()

    def setUp(self):
        super().setUp()
        self.execute("INSERT INTO user_social_identities VALUES ('apple','apple-member',%s)", (self.a,))
        settings = patch.dict(os.environ, {"APPLE_CLIENT_IDS": "our-apple-app"})
        settings.start()
        self.addCleanup(settings.stop)
        keys = SimpleNamespace(get_signing_key_from_jwt=lambda token: SimpleNamespace(key=provider_tests.ProviderTests.public))
        key_patch = patch.object(social_login, "_keys", return_value=keys)
        key_patch.start()
        self.addCleanup(key_patch.stop)

    def webhook(self, **kwargs):
        return self.client.post("/v1/auth/apple/events", json={"payload": provider_tests.ProviderTests().apple_event_token(**kwargs)})

    def test_external_revocation_shares_anonymization_and_provider_scoped_receipts(self):
        post = self.post()
        posts_repo.create_comment(self.a, post, "keep reply", None)
        chat_repo.create_message(self.a, 10, "keep chat")
        self.execute("INSERT INTO user_avatars VALUES (%s,'avatars/apple','image/png',3)", (self.a,))
        self.execute("INSERT INTO user_social_identities VALUES ('kakao','apple-member',%s)", (self.b,))
        with patch.object(social_login, "unlink_apple") as unlink:
            response = self.webhook()
            self.assertEqual((response.status_code, response.content), (200, b""))
            unlink.assert_not_called()
        for table in ("posts", "post_comments", "fixture_chat_messages"):
            self.assertIsNone(self.execute(f"SELECT user_id FROM {table}")[0]["user_id"])
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 401)
        self.assertEqual(self.request("GET", "/v1/users/me", self.token_b).status_code, 200)
        self.assertEqual(self.execute("SELECT object_key FROM media_deletions"), [{"object_key": "avatars/apple"}])
        replacement = auth_repo.login_social("apple", "apple-member")["access_token"]
        self.assertEqual(self.webhook().status_code, 200)
        self.assertIsNotNone(auth_repo.session_user(replacement))
        # 다른 공급자의 같은 ID는 별개의 알림이에요.
        users_repo.delete_social_account("kakao", "apple-member", "event-one")
        self.assertEqual(self.request("GET", "/v1/users/me", self.token_b).status_code, 401)
        self.assertEqual({row["provider"] for row in self.execute("SELECT provider FROM social_webhook_receipts")}, {"apple", "kakao"})

    def test_email_preferences_and_invalid_messages_never_delete_members(self):
        for event_type in ("email-enabled", "email-disabled"):
            self.assertEqual(self.webhook(event_type=event_type).status_code, 200)
        self.assertEqual(self.webhook(aud="other-app").status_code, 401)
        self.assertEqual(self.client.post("/v1/auth/apple/events", json={"payload": "invalid"}).status_code, 401)
        self.assertEqual(self.client.post("/v1/auth/apple/events", json={}).status_code, 422)
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 200)
        self.assertEqual(self.execute("SELECT * FROM social_webhook_receipts"), [])

    def test_failed_deletion_rolls_back_receipt_and_account_deletion_can_be_retried(self):
        with patch.object(users_repo, "_delete_account_rows", side_effect=mysql.connector.Error("test database failure")):
            with self.assertRaises(mysql.connector.Error):
                self.webhook(event_type="account-deleted")
        self.assertEqual(self.execute("SELECT * FROM social_webhook_receipts"), [])
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 200)
        self.assertEqual(self.webhook(event_type="account-deleted").status_code, 200)
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 401)

    def test_concurrent_notifications_and_deleted_member_are_acknowledged(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: self.webhook().status_code, range(2)))
        self.assertEqual(results, [200, 200])
        self.assertEqual(len(self.execute("SELECT * FROM social_webhook_receipts")), 1)
        self.assertEqual(self.webhook(jti="later-event").status_code, 200)


if __name__ == "__main__":
    unittest.main()
