"""실제 조회·저장 SQL과 소켓으로 네 언어의 콘텐츠가 섞이지 않는지 확인해요."""
from contextlib import ExitStack
from datetime import datetime
import sqlite3
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from diagnostics.test_notifications import SqliteConnection

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.core import db
    from one_touch_loader.api.repos import posts_repo, chat_repo
    from one_touch_loader.api.routes import posts, chat


LANGUAGES = ("ko", "en", "zh", "ja")


class LanguageRepositoryTests(unittest.TestCase):
    def setUp(self):
        self.raw = sqlite3.connect(":memory:", check_same_thread=False)
        self.addCleanup(self.raw.close)
        self.raw.executescript("""
            CREATE TABLE users (user_id INTEGER PRIMARY KEY, username TEXT, display_name TEXT,
                favorite_team_id INTEGER, suspended_until TEXT);
            INSERT INTO users VALUES (1,'home','Home',6,NULL),(2,'away','Away',14,NULL);
            CREATE TABLE user_blocks (user_id INTEGER, blocked_user_id INTEGER);
            CREATE TABLE user_avatars (user_id INTEGER);
            CREATE TABLE posts (post_id INTEGER PRIMARY KEY, team_id INTEGER, language TEXT NOT NULL,
                user_id INTEGER, category TEXT, title TEXT, body TEXT, created_at TEXT,
                state TEXT, edited_at TEXT);
            CREATE TABLE post_likes (post_id INTEGER, user_id INTEGER);
            CREATE TABLE post_comments (comment_id INTEGER, post_id INTEGER, user_id INTEGER, state TEXT);
            CREATE TABLE post_attachments (attachment_id INTEGER, post_id INTEGER, position INTEGER,
                object_key TEXT, link_url TEXT, content_type TEXT, byte_size INTEGER);
            CREATE TABLE fixture_chat_messages (message_id INTEGER PRIMARY KEY, fixture_id INTEGER,
                language TEXT NOT NULL, user_id INTEGER, body TEXT, created_at TEXT, state TEXT DEFAULT 'active');
            CREATE TABLE fixture_chat_aliases (fixture_id INTEGER, user_id INTEGER, nickname_en TEXT, nickname_ko TEXT);
            INSERT INTO fixture_chat_aliases VALUES (42,1,'Home_AAAA','홈_AAAA'),(42,2,'Away_BBBB','원정_BBBB'),
                (43,1,'Home_AAAA','홈_AAAA');
        """)
        self.raw.commit()
        conn = SqliteConnection(self.raw)
        self.enterContext(patch.object(db, "_pool", SimpleNamespace(get_connection=lambda: conn)))
        self.enterContext(patch.object(posts_repo, "list_following_team_ids", return_value=[6, 14]))
        self.enterContext(patch.object(posts_repo, "reward_publication"))
        self.enterContext(patch.object(chat_repo, "live_fixture_teams", return_value=(6, 14)))
        self.now = datetime(2026, 10, 6, 12)
        for repo in (posts_repo, chat_repo):
            self.enterContext(patch.object(repo, "utc_now", return_value=self.now))

    def create_post(self, language, *, user=1, draft=False):
        return posts_repo.create_post(user, 6 if user == 1 else 14, "general", language, "Body", [],
                                      language=language, draft=draft)

    def feed(self, language, *, sort=posts_repo.PostSort.newest, limit=50, offset=0):
        return posts_repo.list_posts(1, 6, None, sort, posts_repo.PostPeriod.all_time,
                                     limit, offset, language=language)

    def test_each_language_has_its_own_team_feed_and_pagination(self):
        ids = {language: [self.create_post(language) for _ in range(2)] for language in LANGUAGES}
        self.create_post("ko", user=2)
        for language in LANGUAGES:
            for sort in (posts_repo.PostSort.newest, posts_repo.PostSort.popular):
                with self.subTest(language=language, sort=sort):
                    self.assertEqual([p["post_id"] for p in self.feed(language, sort=sort)], ids[language][::-1])
                    self.assertEqual([p["post_id"] for p in self.feed(language, sort=sort, limit=1, offset=1)], ids[language][:1])
                    self.assertTrue(all(p["language"] == language for p in self.feed(language, sort=sort)))

    def test_editing_and_publishing_drafts_preserve_the_original_language(self):
        post_id = self.create_post("ja", draft=True)
        self.assertEqual(self.feed("ja"), [])
        posts_repo.update_post(1, post_id, "general", "Updated", "Body", [], draft=True)
        posts_repo.publish_draft(1, post_id)
        posts_repo.update_post(1, post_id, "general", "Edited", "Body", [])
        self.assertEqual(self.feed("ko"), [])
        self.assertEqual([p["post_id"] for p in self.feed("ja")], [post_id])
        self.assertEqual(posts_repo.get_post(1, post_id)["language"], "ja")

    def test_chat_storage_history_cursors_and_blocking_stay_in_the_room(self):
        ids = {}
        for language in LANGUAGES:
            ids[language] = [chat_repo.create_message(1, 42, f"{language}-{i}", language=language)["message_id"]
                             for i in range(3)]
        chat_repo.create_message(1, 43, "Other match", language="ko")
        chat_repo.create_message(2, 42, "Blocked author", language="ko")
        self.raw.execute("INSERT INTO user_blocks VALUES (1,2)")
        self.raw.commit()
        for language in LANGUAGES:
            with self.subTest(language=language):
                history = chat_repo.history(1, 42, None, None, 50, language=language)
                self.assertEqual([m["message_id"] for m in history], ids[language])
                newer = chat_repo.history(1, 42, None, ids[language][0], 50, language=language)
                older = chat_repo.history(1, 42, ids[language][-1], None, 50, language=language)
                self.assertEqual([m["message_id"] for m in newer], ids[language][1:])
                self.assertEqual([m["message_id"] for m in older], ids[language][:-1])


class LanguageApiTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.state.chat_hub = chat.ChatHub()
        app.include_router(posts.router, prefix="/v1")
        app.include_router(chat.router, prefix="/v1")
        app.dependency_overrides[posts.get_user_id] = lambda: 1
        self.app = app
        self.client = self.enterContext(TestClient(app))

    def test_all_four_languages_reach_reads_and_new_posts_and_drafts(self):
        with patch.object(posts_repo, "list_posts", return_value=[]) as feed, \
                patch.object(posts_repo, "create_post", return_value=1) as create, \
                patch.object(posts_repo, "get_draft", return_value={"post_id": 1}), \
                patch.object(chat_repo, "history", return_value=[]) as history:
            for language in LANGUAGES:
                with self.subTest(language=language):
                    response = self.client.get("/v1/posts", params={"team_id": 6, "language": language})
                    self.assertEqual(response.status_code, 200)
                    self.assertEqual(feed.call_args.kwargs["language"], language)
                    self.assertEqual(self.client.get(f"/v1/fixtures/42/chat/messages?language={language}").status_code, 200)
                    self.assertEqual(history.call_args.kwargs["language"], language)
                    for path in ("posts", "post-drafts"):
                        response = self.client.post(f"/v1/{path}", json={
                            "team_id": 6, "language": language, "title": "Title", "body": "Body"})
                        self.assertEqual(response.status_code, 201)
                        self.assertEqual(create.call_args.kwargs["language"], language)

    def test_missing_and_unsupported_languages_are_rejected(self):
        for language in (None, "fr", "zh-CN", ""):
            with self.subTest(language=language):
                query = {} if language is None else {"language": language}
                self.assertEqual(self.client.get("/v1/posts", params={"team_id": 6, **query}).status_code, 422)
                self.assertEqual(self.client.get("/v1/fixtures/42/chat/messages", params=query).status_code, 422)
                for path in ("posts", "post-drafts"):
                    self.assertEqual(self.client.post(f"/v1/{path}", json={
                        "team_id": 6, "title": "Title", **query}).status_code, 422)
                with self.assertRaises(WebSocketDisconnect):
                    with self.client.websocket_connect("/v1/fixtures/42/chat", params=query):
                        pass

    def test_broadcast_reaches_both_fans_only_in_the_same_language_and_match(self):
        from diagnostics.test_chat_aliases import stored_message

        def save(user_id, fixture_id, text, *, language):
            return stored_message(user_id=user_id, fixture_id=fixture_id, text=text)

        with patch.object(chat, "_authorized", side_effect=lambda token, _: {"user_id": 1 if token[0] == "a" else 2}), \
                patch.object(chat.auth_repo, "rate_limit"), patch.object(chat, "is_blocked", return_value=False), \
                patch.object(chat_repo, "create_message", side_effect=save) as create, ExitStack() as stack:
            rooms = {}
            for fixture_id, language in [(42, language) for language in LANGUAGES] + [(43, "ko")]:
                peers = []
                for token in ("a", "b"):
                    socket = stack.enter_context(self.client.websocket_connect(
                        f"/v1/fixtures/{fixture_id}/chat?language={language}"))
                    socket.send_json({"token": token * 40})
                    self.assertEqual(socket.receive_json(), {"type": "ready", "fixture_id": fixture_id, "language": language})
                    peers.append(socket)
                rooms[(fixture_id, language)] = peers
            # 다른 방에서 온 메시지가 대기열에 있다면 각 방의 첫 수신부터 일치하지 않아요.
            for round_number in range(2):
                for (fixture_id, language), peers in rooms.items():
                    text = f"{fixture_id}-{language}-{round_number}"
                    peers[0].send_json({"text": text})
                    for peer in peers:
                        self.assertEqual(peer.receive_json()["text"], text)
                    self.assertEqual(create.call_args.kwargs["language"], language)
        self.assertEqual(self.app.state.chat_hub.rooms, {})


if __name__ == "__main__":
    unittest.main()
