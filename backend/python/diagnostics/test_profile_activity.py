"""내 활동 API의 실제 조회 SQL을 메모리 DB에서 실행해 권한과 페이지 결과를 확인해요."""
from datetime import datetime, timedelta
import sqlite3
import unittest
from unittest.mock import patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

# 테스트 수집과 실행 모두 운영 DB에 연결하지 않아요.
with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api import deps
    from one_touch_loader.api.repos import posts_repo, teams_repo, users_repo
    from one_touch_loader.api.routes import posts, users
    from one_touch_loader.api.services import content_visibility


class ProfileActivityTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:", check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.addCleanup(self.db.close)
        self.db.executescript("""
            CREATE TABLE users (user_id INTEGER PRIMARY KEY, username TEXT, first_name TEXT,
                last_name TEXT, favorite_team_id INTEGER, suspended_until TEXT);
            CREATE TABLE user_following_teams (user_id INTEGER, team_id INTEGER, position INTEGER);
            CREATE TABLE user_avatars (user_id INTEGER PRIMARY KEY);
            CREATE TABLE user_blocks (user_id INTEGER, blocked_user_id INTEGER);
            CREATE TABLE posts (post_id INTEGER PRIMARY KEY, team_id INTEGER, user_id INTEGER,
                category TEXT, title TEXT, body TEXT, created_at TEXT, edited_at TEXT, state TEXT);
            CREATE TABLE post_comments (comment_id INTEGER PRIMARY KEY, post_id INTEGER, user_id INTEGER,
                reply_to_id INTEGER, body TEXT, created_at TEXT, edited_at TEXT, state TEXT);
            CREATE TABLE post_likes (post_id INTEGER, user_id INTEGER);
            CREATE TABLE comment_likes (comment_id INTEGER, user_id INTEGER);
            CREATE TABLE post_attachments (attachment_id INTEGER, post_id INTEGER, position INTEGER,
                link_url TEXT, content_type TEXT, byte_size INTEGER);
            INSERT INTO users VALUES (1,'me','First','Last',10,NULL),
                (2,'friend','First','Last',10,NULL), (3,'blocked','First','Last',10,NULL);
            INSERT INTO user_following_teams VALUES (1,10,0),(1,20,1);
            INSERT INTO user_avatars VALUES (1),(2);
            INSERT INTO user_blocks VALUES (1,3);
        """)
        self.now = datetime(2026, 9, 29, 12)
        for post_id, team_id, author, state in (
            (10, 10, 1, "active"), (11, 20, 1, "active"), (12, 30, 1, "active"),
            (13, 10, 2, "active"), (14, 10, 3, "active"), (15, 20, None, "active"),
            (16, 10, 1, "deleted"), (17, 10, 1, "hidden"), (18, 10, 1, "draft"),
        ):
            self.db.execute("INSERT INTO posts VALUES (?,?,?,'general',?,?,?,NULL,?)",
                            (post_id, team_id, author, f"Title {post_id}", f"Body {post_id}",
                             self.now.isoformat(), state))
        for comment_id, post_id, author, state, reply_to in (
            (100, 13, 1, "active", None), (101, 13, 1, "active", 100),
            (102, 11, 1, "active", None), (103, 12, 1, "active", None),
            (104, 13, 1, "hidden", None), (105, 13, 1, "deleted", None),
            (106, 16, 1, "active", None), (107, 17, 1, "active", None),
            (108, 18, 1, "active", None), (109, 14, 1, "active", None),
            (110, 13, 2, "active", None), (111, 13, 3, "active", None),
            (112, 13, None, "active", None), (113, 15, 1, "active", None),
        ):
            self.db.execute("INSERT INTO post_comments VALUES (?,?,?,?,?,?,NULL,?)",
                            (comment_id, post_id, author, reply_to, f"Comment {comment_id}",
                             self.now.isoformat(), state))
        self.db.executescript("""
            INSERT INTO post_likes VALUES (11,1),(11,2),(13,1);
            INSERT INTO comment_likes VALUES (101,1),(101,2);
            INSERT INTO post_attachments VALUES (1,11,0,'https://example.com/',NULL,NULL),
                (2,11,1,NULL,'image/png',20);
        """)
        for module in (posts_repo, users_repo, teams_repo, content_visibility):
            if hasattr(module, "fetch_all_dict"):
                self.patch(module, "fetch_all_dict", side_effect=self.fetch_all)
            if hasattr(module, "fetch_one_dict"):
                self.patch(module, "fetch_one_dict", side_effect=self.fetch_one)
        self.session = self.patch(deps, "session_user", side_effect=self.session_user)
        app = FastAPI()
        app.include_router(users.router, prefix="/v1")
        app.include_router(posts.router, prefix="/v1")
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def patch(self, target, name, **kwargs):
        patcher = patch.object(target, name, **kwargs)
        mocked = patcher.start()
        self.addCleanup(patcher.stop)
        return mocked

    def fetch_all(self, sql, params=()):
        # 이 조회 SQL은 두 DB가 공유해요. 바인딩 표기와 DATETIME 반환만 맞춰요.
        rows = [dict(row) for row in self.db.execute(sql.replace("%s", "?"), params)]
        for row in rows:
            for field in ("created_at", "edited_at", "suspended_until"):
                if row.get(field) is not None:
                    row[field] = datetime.fromisoformat(row[field])
        return rows

    def fetch_one(self, sql, params=()):
        rows = self.fetch_all(sql, params)
        return rows[0] if rows else None

    def session_user(self, token):
        if token != "viewer-session":
            raise HTTPException(401, "Invalid session")
        return {"user_id": 1}

    def get(self, path, **params):
        return self.client.get(path, params=params, headers={"Authorization": "Bearer viewer-session"})

    def activity(self, kind, **params):
        response = self.get(f"/v1/users/me/{kind}", **params)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_posts_include_only_my_active_posts_in_readable_teams(self):
        result = self.activity("posts")
        self.assertEqual([row["post_id"] for row in result["items"]], [11, 10])
        self.assertEqual((result["limit"], result["offset"]), (50, 0))
        post = result["items"][0]
        self.assertEqual(post, self.get("/v1/posts/11").json())
        self.assertEqual((post["like_count"], post["comment_count"], post["liked"]), (2, 1, 1))
        self.assertEqual(post["avatar_url"], "/v1/users/1/avatar")
        self.assertFalse(post["author_deleted"])
        self.assertEqual(post["created_at"], "2026-09-29T12:00:00Z")
        self.assertIsNone(post["edited_at"])
        self.assertEqual([row["attachment_id"] for row in post["attachments"]], [1, 2])
        self.assertEqual(post["attachments"][1]["media_url"], "/v1/attachments/2/content")
        self.assertNotIn("has_avatar", post)

    def test_comments_include_replies_with_the_existing_post_and_comment_contracts(self):
        items = self.activity("comments")["items"]
        self.assertEqual([row["comment"]["comment_id"] for row in items], [113, 102, 101, 100])
        reply = items[2]
        self.assertEqual(reply["post"], self.get("/v1/posts/13").json())
        detail_comments = self.get("/v1/posts/13/comments").json()["items"]
        self.assertEqual(reply["comment"], next(row for row in detail_comments if row["comment_id"] == 101))
        self.assertEqual(reply["comment"]["reply_to_id"], 100)
        self.assertEqual((reply["comment"]["like_count"], reply["comment"]["liked"]), (2, 1))
        self.assertEqual(reply["post"]["comment_count"], 4)
        self.assertTrue(items[0]["post"]["author_deleted"])
        self.assertIsNone(items[0]["post"]["username"])
        self.assertNotIn("blocked", reply["comment"])

    def test_filtering_happens_before_pagination_and_empty_pages_are_valid(self):
        for kind, expected in (("posts", [11, 10]), ("comments", [113, 102, 101, 100])):
            for offset, item_id in enumerate(expected):
                with self.subTest(kind=kind, offset=offset):
                    result = self.activity(kind, limit=1, offset=offset)
                    self.assertEqual((result["limit"], result["offset"]), (1, offset))
                    self.assertEqual(len(result["items"]), 1)
                    item = result["items"][0]
                    self.assertEqual(item["post_id"] if kind == "posts" else item["comment"]["comment_id"], item_id)
            self.assertEqual(self.activity(kind, offset=len(expected))["items"], [])

    def test_creation_time_precedes_id_and_edits_do_not_reorder_activity(self):
        later = (self.now + timedelta(days=1)).isoformat()
        self.db.execute("UPDATE posts SET created_at=? WHERE post_id=10", (later,))
        self.db.execute("UPDATE post_comments SET created_at=? WHERE comment_id=100", (later,))
        self.db.execute("UPDATE posts SET edited_at=? WHERE post_id=11", (later,))
        self.db.execute("UPDATE post_comments SET edited_at=? WHERE comment_id=101", (later,))
        self.assertEqual(self.activity("posts")["items"][0]["post_id"], 10)
        self.assertEqual(self.activity("comments")["items"][0]["comment"]["comment_id"], 100)

    def test_unfollowing_removes_activity_without_changing_favorite_access(self):
        self.db.execute("DELETE FROM user_following_teams WHERE user_id=1")
        self.assertEqual([row["post_id"] for row in self.activity("posts")["items"]], [10])
        self.assertEqual([row["comment"]["comment_id"] for row in self.activity("comments")["items"]], [101, 100])

    def test_changing_favorite_and_followed_teams_changes_activity_scope(self):
        self.db.execute("UPDATE users SET favorite_team_id=30 WHERE user_id=1")
        self.db.execute("DELETE FROM user_following_teams WHERE user_id=1")
        self.assertEqual([row["post_id"] for row in self.activity("posts")["items"]], [12])
        self.assertEqual([row["comment"]["comment_id"] for row in self.activity("comments")["items"]], [103])

    def test_session_owns_both_lists_even_when_another_user_id_is_supplied(self):
        for kind in ("posts", "comments"):
            with self.subTest(kind=kind):
                response = self.get(f"/v1/users/me/{kind}", user_id=2, author_id=2)
                self.assertEqual(response.status_code, 200, response.text)
                items = response.json()["items"]
                self.assertTrue(items)
                self.assertTrue(all((row if kind == "posts" else row["comment"])["user_id"] == 1 for row in items))

    def test_both_endpoints_require_a_valid_bearer_session(self):
        for kind in ("posts", "comments"):
            for headers in ({}, {"X-User-Id": "1"}, {"Authorization": "Bearer invalid"}):
                with self.subTest(kind=kind, headers=headers):
                    response = self.client.get(f"/v1/users/me/{kind}", headers=headers)
                    self.assertEqual(response.status_code, 401)

    def test_pagination_bounds_are_validated(self):
        for kind in ("posts", "comments"):
            for params in ({"limit": 0}, {"limit": 101}, {"limit": "invalid"}, {"offset": -1}):
                with self.subTest(kind=kind, params=params):
                    self.assertEqual(self.get(f"/v1/users/me/{kind}", **params).status_code, 422)
            self.assertEqual(self.get(f"/v1/users/me/{kind}", limit=100).status_code, 200)

    def test_profile_suspension_and_missing_favorite_keep_existing_restrictions(self):
        cases = (("username", None), ("favorite_team_id", None),
                 ("suspended_until", (datetime.now() + timedelta(days=1)).isoformat()))
        for field, value in cases:
            previous = self.db.execute(f"SELECT {field} FROM users WHERE user_id=1").fetchone()[0]
            self.db.execute(f"UPDATE users SET {field}=? WHERE user_id=1", (value,))
            for kind in ("posts", "comments"):
                with self.subTest(field=field, kind=kind):
                    self.assertEqual(self.get(f"/v1/users/me/{kind}").status_code, 403)
            self.db.execute(f"UPDATE users SET {field}=? WHERE user_id=1", (previous,))

    def test_existing_detail_keeps_deleted_and_blocked_reply_placeholders(self):
        comments = {row["comment_id"]: row for row in self.get("/v1/posts/13/comments").json()["items"]}
        for comment_id, state in ((104, "hidden"), (105, "deleted"), (111, "blocked")):
            with self.subTest(comment_id=comment_id):
                self.assertEqual(comments[comment_id]["state"], state)
                self.assertEqual(comments[comment_id]["body"], "")
                self.assertIsNone(comments[comment_id]["user_id"])
        self.assertEqual(comments[101]["reply_to_id"], 100)


if __name__ == "__main__":
    unittest.main()
