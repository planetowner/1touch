"""초안 공개 범위, 7일 경계, 게시·탈퇴·파일 정리를 격리 MySQL에서 확인해요."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
from threading import Barrier
from unittest.mock import patch

from diagnostics.test_user_community import CommunityDatabaseCase
from diagnostics.verify_post_drafts import verify_schema
from one_touch_loader.api.repos import posts_repo
from one_touch_loader.api.routes import attachments
from one_touch_loader.loaders import community_maintenance
from one_touch_loader.api.services.community_periods import utc_now
from fastapi import HTTPException


class DraftTests(CommunityDatabaseCase):
    def draft(self, **changes):
        body = {"team_id": 6, "title": "Draft", "body": "Unpublished", **changes}
        response = self.request("POST", "/v1/post-drafts", json=body)
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()

    def link(self):
        return self.request("POST", "/v1/attachments/link", json={"url": "https://example.com/"}).json()["attachment_id"]

    def media(self, key):
        return self.execute("""INSERT INTO post_attachments (user_id,object_key,content_type,byte_size,created_at)
            VALUES (%s,%s,'image/png',3,%s)""", (self.a, key, utc_now()))

    def test_draft_is_private_and_cannot_receive_community_interactions(self):
        draft = self.draft(title="", attachment_ids=[self.link()])
        post_id = draft["post_id"]
        # 같은 최애팀의 다른 회원에게도 초안은 공개하지 않아요.
        _, token = self.user("same_team", 6)
        for member_token in (self.token_a, token):
            for method, suffix, body in (("GET", "", None), ("GET", "/comments", None),
                                         ("PUT", "/like", None), ("POST", "/comments", {"body": "reply"}),
                                         ("POST", "/report", {"reason": "test"})):
                self.assertEqual(self.request(method, f"/v1/posts/{post_id}{suffix}", member_token, json=body).status_code, 404)
        for sort in ("newest", "popular", "best"):
            self.assertEqual(self.request("GET", f"/v1/posts?team_id=6&sort={sort}").json()["items"], [])
        self.assertEqual(self.request("GET", "/v1/post-drafts", token).json()["items"], [])
        self.assertEqual(self.request("GET", f"/v1/post-drafts/{post_id}", token).status_code, 404)
        self.assertEqual(self.request("POST", f"/v1/post-drafts/{post_id}/publish").status_code, 400)
        self.assertEqual(self.request("GET", f"/v1/post-drafts/{post_id}").json()["title"], "")
        self.assertEqual(len(self.request("GET", "/v1/post-drafts").json()["items"]), 1)

    def test_save_refreshes_seven_days_and_preserves_attachment_order(self):
        ids = [self.link(), self.link()]
        draft = self.draft(attachment_ids=ids)
        post_id = draft["post_id"]
        now = utc_now()
        self.execute("UPDATE posts SET edited_at=%s WHERE post_id=%s", (now - timedelta(days=6), post_id))
        self.execute("UPDATE post_attachments SET created_at=%s", (now - timedelta(days=9),))
        with patch.object(posts_repo, "utc_now", return_value=now):
            response = self.request("PUT", f"/v1/post-drafts/{post_id}", json={"title": "Revised", "body": "Resume", "attachment_ids": ids[::-1]})
        self.assertEqual(response.status_code, 200, response.text)
        row = response.json()
        self.assertEqual(row["created_at"], draft["created_at"])
        self.assertEqual(datetime.fromisoformat(row["expires_at"].replace("Z", "+00:00")).replace(tzinfo=None), now + timedelta(days=7))
        self.assertEqual([item["attachment_id"] for item in row["attachments"]], ids[::-1])
        self.assertEqual(community_maintenance.maintain_community(check=True)["unused_attachments"], 0)

    def test_expired_draft_is_unavailable_even_before_cleanup(self):
        attachment_id = self.media("posts/expired-draft")
        post_id = self.draft(attachment_ids=[attachment_id])["post_id"]
        now = utc_now()
        self.execute("UPDATE posts SET edited_at=%s WHERE post_id=%s", (now - timedelta(days=7), post_id))
        with patch.object(posts_repo, "utc_now", return_value=now), patch.object(attachments, "private_content") as storage:
            for method, url, body in (("GET", f"/v1/post-drafts/{post_id}", None),
                                      ("PUT", f"/v1/post-drafts/{post_id}", {"title": "Late"}),
                                      ("POST", f"/v1/post-drafts/{post_id}/publish", None),
                                      ("GET", f"/v1/attachments/{attachment_id}/content", None)):
                self.assertEqual(self.request(method, url, json=body).status_code, 404)
            self.assertEqual(self.request("GET", "/v1/post-drafts").json()["items"], [])
            storage.assert_not_called()
        self.assertEqual(len(self.execute("SELECT * FROM posts")), 1)

    def test_unused_file_expires_at_seven_days_for_reading_and_attaching(self):
        item = self.media("posts/unused")
        now = utc_now()
        self.execute("UPDATE post_attachments SET created_at=%s", (now - timedelta(days=7),))
        with patch.object(posts_repo, "utc_now", return_value=now), patch.object(attachments, "utc_now", return_value=now):
            self.assertEqual(self.request("GET", f"/v1/attachments/{item}/content").status_code, 404)
            for url in ("/v1/posts", "/v1/post-drafts"):
                self.assertEqual(self.request("POST", url, json={"team_id": 6, "title": "Late", "attachment_ids": [item]}).status_code, 400)
        self.assertEqual(self.execute("SELECT * FROM posts"), [])

    def test_publishing_reuses_post_and_attachment_ids_and_sets_publication_time(self):
        attachment_id = self.link()
        post_id = self.draft(attachment_ids=[attachment_id])["post_id"]
        now = utc_now()
        self.execute("UPDATE posts SET created_at=%s,edited_at=%s WHERE post_id=%s", (now - timedelta(days=6), now - timedelta(days=1), post_id))
        with patch.object(posts_repo, "utc_now", return_value=now):
            response = self.request("POST", f"/v1/post-drafts/{post_id}/publish")
        self.assertEqual(response.json(), {"post_id": post_id})
        row = self.execute("SELECT * FROM posts WHERE post_id=%s", (post_id,))[0]
        self.assertEqual((row["state"], row["created_at"], row["edited_at"]), ("active", now, None))
        self.assertEqual(self.request("GET", f"/v1/posts/{post_id}").json()["attachments"][0]["attachment_id"], attachment_id)
        self.assertEqual(self.request("GET", "/v1/post-drafts").json()["items"], [])
        self.assertEqual(self.request("POST", f"/v1/post-drafts/{post_id}/publish").status_code, 404)

    def test_foreign_draft_and_attached_files_cannot_be_taken(self):
        attachment_id = self.media("posts/private")
        post_id = self.draft(attachment_ids=[attachment_id])["post_id"]
        _, token = self.user("same_team", 6)
        for method, url, body in (("PUT", f"/v1/post-drafts/{post_id}", {"title": "Take"}),
                                  ("POST", f"/v1/post-drafts/{post_id}/publish", None),
                                  ("DELETE", f"/v1/post-drafts/{post_id}", None),
                                  ("GET", f"/v1/attachments/{attachment_id}/content", None)):
            self.assertEqual(self.request(method, url, token, json=body).status_code, 404)
        # 내 첨부여도 다른 초안과 동시에 공유하지 않아요.
        response = self.request("POST", "/v1/post-drafts", json={"team_id": 6, "attachment_ids": [attachment_id]})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(len(self.execute("SELECT * FROM posts")), 1)

    def test_changed_home_team_prevents_saving_and_publishing_old_team_draft(self):
        item = self.draft()["post_id"]
        self.execute("UPDATE users SET favorite_team_id=14 WHERE user_id=%s", (self.a,))
        self.assertEqual(self.request("PUT", f"/v1/post-drafts/{item}", json={"title": "Old team"}).status_code, 403)
        self.assertEqual(self.request("POST", f"/v1/post-drafts/{item}/publish").status_code, 403)
        self.assertEqual(self.request("GET", f"/v1/post-drafts/{item}").status_code, 200)
        self.assertEqual(self.request("DELETE", f"/v1/post-drafts/{item}").status_code, 200)

    def test_cleanup_preserves_published_files_current_avatars_and_recent_saved_drafts(self):
        old_file = self.media("posts/old-draft")
        old = self.draft(attachment_ids=[old_file])["post_id"]
        fresh_file = self.media("posts/fresh-draft")
        fresh = self.draft(attachment_ids=[fresh_file])["post_id"]
        published_file = self.media("posts/published")
        published = self.post(attachment_ids=[published_file])
        unused = self.media("posts/unused")
        self.execute("INSERT INTO user_avatars VALUES (%s,'avatars/current','image/png',3)", (self.a,))
        now = utc_now()
        self.execute("UPDATE post_attachments SET created_at=%s", (now - timedelta(days=9),))
        self.execute("UPDATE posts SET edited_at=%s WHERE post_id IN (%s,%s)", (now - timedelta(days=7), old, published))
        with patch.object(community_maintenance, "utc_now", return_value=now), patch.object(community_maintenance, "object_operation") as storage:
            preview = community_maintenance.maintain_community(check=True)
            self.assertEqual((preview["draft_posts"], preview["unused_attachments"]), (1, 1))
            storage.assert_not_called()
            self.assertEqual(len(self.execute("SELECT * FROM posts")), 3)
            result = community_maintenance.maintain_community(check=False)
            self.assertEqual((result["draft_posts"], result["unused_attachments"], result["deleted_files"]), (1, 1, 2))
            self.assertEqual({call.kwargs["Key"] for call in storage.call_args_list}, {"posts/old-draft", "posts/unused"})
        self.assertEqual({row["post_id"] for row in self.execute("SELECT post_id FROM posts")}, {fresh, published})
        self.assertEqual({row["attachment_id"] for row in self.execute("SELECT attachment_id FROM post_attachments")}, {fresh_file, published_file})
        self.assertEqual(len(self.execute("SELECT * FROM user_avatars")), 1)

    def test_delete_and_account_deletion_queue_draft_files_without_preserving_private_text(self):
        manual = self.draft(attachment_ids=[self.media("posts/manual")])["post_id"]
        self.assertEqual(self.request("DELETE", f"/v1/post-drafts/{manual}").status_code, 200)
        self.draft(attachment_ids=[self.media("posts/account")])
        published = self.post(attachment_ids=[self.media("posts/keep")])
        self.assertEqual(self.request("DELETE", "/v1/users/me").status_code, 200)
        self.assertEqual(self.execute("SELECT post_id,user_id,state FROM posts"), [{"post_id": published, "user_id": None, "state": "active"}])
        self.assertEqual({row["object_key"] for row in self.execute("SELECT * FROM media_deletions")}, {"posts/manual", "posts/account"})

    def test_two_publications_create_only_one_active_post(self):
        post_id = self.draft()["post_id"]
        barrier = Barrier(2)
        def publish():
            barrier.wait()
            try:
                return posts_repo.publish_draft(self.a, post_id)
            except HTTPException as exc:
                return exc.status_code
        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: publish(), range(2)))
        self.assertCountEqual(results, [post_id, 404])
        self.assertEqual(self.execute("SELECT post_id,state FROM posts"), [{"post_id": post_id, "state": "active"}])


class DraftMigrationTests(CommunityDatabaseCase):
    post_drafts_schema = False

    def test_additive_migration_preserves_posts_comments_attachments_and_avatars(self):
        post = self.post()
        self.execute("INSERT INTO post_comments (post_id,user_id,body,created_at) VALUES (%s,%s,'Reply',%s)", (post, self.a, utc_now()))
        self.execute("INSERT INTO post_attachments (user_id,post_id,position,link_url,created_at) VALUES (%s,%s,0,'https://example.com/',%s)", (self.a, post, utc_now()))
        self.execute("INSERT INTO user_avatars VALUES (%s,'avatars/keep','image/png',3)", (self.a,))
        tables = ("posts", "post_comments", "post_attachments", "user_avatars", "users")
        before = {table: self.execute(f"SELECT * FROM {table}") for table in tables}
        verify_schema(before=True)
        self.apply_post_drafts_schema()
        verify_schema(before=False)
        self.assertEqual({table: self.execute(f"SELECT * FROM {table}") for table in tables}, before)
