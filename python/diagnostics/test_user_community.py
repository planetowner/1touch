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

# 테스트 수집만 해도 운영 DB 풀이 열리지 않게 해요.
with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.core import db
    from one_touch_loader.api.main import create_app
    from one_touch_loader.api.repos import auth_repo, posts_repo, teams_repo, users_repo, chat_repo
    from one_touch_loader.api.services import auth_security, media_storage, social_login
    from one_touch_loader.api.services.community_periods import PostPeriod, period_bounds, utc_now
    from one_touch_loader.api.schemas.users import PasswordLoginBody, RegisterEmailBody, ResetPasswordBody
    from diagnostics.verify_user_community import verify_schema


class PasswordContractTests(unittest.TestCase):
    profile = {"username": "member", "first_name": "First", "last_name": "Last", "timezone": "UTC"}
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
class MySQLCommunityTests(unittest.TestCase):
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

    def user(self, username, favorite=None):
        user_id = self.execute("INSERT INTO users (username,first_name,last_name,timezone,created_at) VALUES (%s,'First','Last','UTC',%s)", (username, utc_now()))
        if favorite:
            teams_repo.set_following_and_favorite(user_id, [favorite], favorite)
        with db.transaction() as conn, conn.cursor(dictionary=True) as cur:
            token = auth_repo._create_session(cur, user_id)["access_token"]
        return user_id, token

    def request(self, method, url, token=None, **kwargs):
        return self.client.request(method, url, headers={"Authorization": f"Bearer {token or self.token_a}"}, **kwargs)

    def post(self, user_id=None, team_id=6, **kwargs):
        return posts_repo.create_post(user_id or self.a, team_id, "general", "Title", "Body", kwargs.get("attachment_ids", []))

    def test_schema_after_matches_minimal_contract(self):
        report = verify_schema(before=False)
        self.assertEqual(report["tables"]["users"], 3)

    def test_untrusted_user_header_and_expired_session_are_rejected(self):
        self.assertEqual(self.client.get("/v1/users/me", headers={"X-User-Id": str(self.a)}).status_code, 401)
        self.execute("UPDATE user_sessions SET expires_at=%s", (utc_now() - timedelta(seconds=1),))
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 401)

    def test_logout_invalidates_the_token(self):
        self.assertEqual(self.request("POST", "/v1/auth/logout").status_code, 200)
        self.assertEqual(self.request("GET", "/v1/users/me").status_code, 401)

    def test_provider_buttons_follow_country_rule(self):
        self.assertIn("kakao", self.client.get("/v1/auth/providers?country_code=KR").json()["providers"])
        self.assertNotIn("kakao", self.client.get("/v1/auth/providers?country_code=US").json()["providers"])

    def test_signup_code_is_consumed_and_password_is_hashed(self):
        with patch.object(auth_repo, "send_verification_code") as send:
            challenge = auth_repo.request_email_code("new@example.com", "signup")["challenge_id"]
        code = send.call_args.args[1]
        self.assertRegex(code, r"^\d{6}$")
        profile = {"username": "new", "first_name": "First", "last_name": "Last", "timezone": "Asia/Seoul"}
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
            "username": "newmember", "first_name": "F", "last_name": "L", "timezone": "UTC"})
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
            "username": "renamed", "first_name": "F", "last_name": "L", "timezone": "UTC"})
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
        profile = {"username": "new", "first_name": "F", "last_name": "L", "timezone": "UTC"}
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
        self.execute("UPDATE posts SET created_at=%s WHERE post_id=%s", (datetime(2026, 9, 9, 16), first))
        self.execute("UPDATE posts SET created_at=%s WHERE post_id=%s", (datetime(2026, 9, 10, 1), second))
        posts_repo.set_like(self.a, "post", first, True)
        self.execute("UPDATE users SET timezone='Asia/Seoul' WHERE user_id=%s", (self.a,))
        with patch.object(posts_repo, "utc_now", return_value=datetime(2026, 9, 10, 2)):
            items = self.request("GET", "/v1/posts?team_id=6&sort=popular&period=today").json()["items"]
        self.assertEqual([x["post_id"] for x in items], [first, second])

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
        with patch("one_touch_loader.api.routes.attachments.object_operation") as storage:
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
        with patch("one_touch_loader.api.routes.attachments.object_operation") as storage:
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
        with patch("one_touch_loader.api.routes.attachments.object_operation", side_effect=HTTPException(502, "R2 unavailable")):
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


if __name__ == "__main__":
    unittest.main()
