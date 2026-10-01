"""운영 DB·R2에 연결하지 않고 공유 공개 범위와 HTML·앱 연결 계약을 확인해요."""
from io import BytesIO
import os
from pathlib import Path
import plistlib
import sqlite3
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

from botocore.response import StreamingBody
from bs4 import BeautifulSoup
from fastapi.testclient import TestClient

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api.main import create_app
    from one_touch_loader.api.repos import community_share_repo
    from one_touch_loader.api.services import media_storage


class CommunityShareTests(unittest.TestCase):
    def setUp(self):
        # 공개 여부·글과 첨부의 관계는 SQL을 실제 실행해 확인해요. 데이터는 메모리에만 있어요.
        self.db = sqlite3.connect(":memory:", check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.addCleanup(self.db.close)
        self.db.executescript("""
            CREATE TABLE posts (post_id INTEGER PRIMARY KEY, title TEXT, body TEXT, state TEXT);
            CREATE TABLE post_attachments (attachment_id INTEGER PRIMARY KEY, post_id INTEGER,
                position INTEGER, object_key TEXT, content_type TEXT, byte_size INTEGER);
            INSERT INTO posts VALUES
                (1, '경기 이야기', '첫 번째 줄\n두 번째 줄', 'active'),
                (2, '숨긴 제목', '숨긴 본문', 'hidden'),
                (3, '초안 제목', '초안 본문', 'draft'),
                (4, '삭제 제목', '삭제 본문', 'deleted'),
                (5, '다른 글', '다른 글 본문', 'active');
            INSERT INTO post_attachments VALUES
                (101, 1, 0, 'posts/video', 'video/mp4', 5),
                (102, 1, 2, 'posts/second', 'image/png', 5),
                (103, 1, 1, 'posts/first', 'image/webp', 5),
                (104, 1, 3, NULL, NULL, NULL),
                (201, 2, 0, 'posts/hidden', 'image/png', 5),
                (301, 3, 0, 'posts/draft', 'image/png', 5),
                (401, 4, 0, 'posts/deleted', 'image/png', 5),
                (501, 5, 0, 'posts/foreign', 'image/png', 5),
                (601, NULL, NULL, 'posts/unpublished', 'image/png', 5);
        """)
        self.enterContext(patch.object(community_share_repo, "fetch_all_dict", side_effect=self.fetch_all))
        self.enterContext(patch.object(community_share_repo, "fetch_one_dict", side_effect=self.fetch_one))
        self.storage = self.enterContext(patch.object(media_storage, "object_operation"))
        self.client = self.enterContext(TestClient(create_app()))

    def fetch_all(self, sql, params):
        return [dict(row) for row in self.db.execute(sql.replace("%s", "?"), params)]

    def fetch_one(self, sql, params):
        rows = self.fetch_all(sql, params)
        return rows[0] if rows else None

    def test_public_page_has_full_body_ordered_images_and_matching_preview(self):
        response = self.client.get("/community/1")
        self.assertEqual(response.status_code, 200)
        self.assertIn("text/html", response.headers["content-type"])
        self.assertEqual(response.headers["cache-control"], "no-store")
        page = BeautifulSoup(response.text, "html.parser")
        self.assertEqual(page.h1.text, "경기 이야기")
        self.assertEqual(page.select_one(".post-body").text, "첫 번째 줄\n두 번째 줄")
        self.assertEqual(page.find("meta", property="og:description")["content"], "첫 번째 줄 두 번째 줄")
        self.assertEqual(page.find("meta", property="og:title")["content"], page.h1.text)
        images = [image["src"] for image in page.select(".post-images img")]
        self.assertEqual(images, [f"https://1touch.football/community/1/images/{i}" for i in (103, 102)])
        self.assertEqual(page.find("meta", property="og:image")["content"], images[0])
        self.assertEqual(page.find("link", rel="canonical")["href"], "https://1touch.football/community/1")
        self.assertIsNone(page.find("video"))
        self.assertNotIn("posts/first", response.text)
        self.assertNotIn("posts/second", response.text)
        self.storage.assert_not_called()

    def test_text_and_metadata_escape_user_html_without_truncating_body(self):
        title = '\"><script>alert("title")</script> & 제목'
        body = '<img src=x onerror="alert(1)">\n' + "긴 본문 " * 400
        self.db.execute("UPDATE posts SET title=?,body=? WHERE post_id=1", (title, body))
        response = self.client.get("/community/1", headers={"Host": "untrusted.example"})
        page = BeautifulSoup(response.text, "html.parser")
        self.assertEqual(page.h1.text, title)
        self.assertEqual(page.select_one(".post-body").text, body)
        self.assertEqual(page.find("meta", property="og:title")["content"], title)
        self.assertEqual(len(page.find("meta", property="og:description")["content"]), 160)
        self.assertIsNone(page.find("script"))
        self.assertIsNone(page.select_one(".post-body img"))
        self.assertNotIn("untrusted.example", response.text)

    def test_text_only_post_uses_existing_logo_for_preview(self):
        self.db.execute("DELETE FROM post_attachments WHERE post_id=1")
        page = BeautifulSoup(self.client.get("/community/1").text, "html.parser")
        self.assertEqual(page.select(".post-images img"), [])
        self.assertEqual(page.find("meta", property="og:image")["content"],
                         "https://1touch.football/assets/1touch-wordmark.jpg")

    def test_hidden_draft_deleted_and_missing_posts_never_expose_content_or_images(self):
        for post_id, attachment_id in ((2, 201), (3, 301), (4, 401), (99, 601), (0, 601)):
            with self.subTest(post_id=post_id):
                response = self.client.get(f"/community/{post_id}")
                self.assertEqual(response.status_code, 404)
                page = BeautifulSoup(response.text, "html.parser")
                self.assertEqual(page.h1.text, "게시글을 찾을 수 없어요")
                self.assertEqual(page.select(".post-images img"), [])
                self.assertEqual(self.client.get(f"/community/{post_id}/images/{attachment_id}").status_code, 404)
        self.storage.assert_not_called()

    def test_image_stream_uses_existing_private_storage_and_rechecks_post_state(self):
        content = b"image"
        raw = BytesIO(content)
        stream = StreamingBody(raw, len(content))
        self.storage.return_value = {"Body": stream, "ContentLength": len(content)}
        response = self.client.get("/community/1/images/102")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.content, content)
        self.assertEqual(response.headers["content-type"], "image/png")
        self.assertEqual(response.headers["cache-control"], "private, no-store")
        self.assertTrue(raw.closed)
        self.storage.assert_called_once_with("get_object", Key="posts/second")
        self.db.execute("UPDATE posts SET state='hidden' WHERE post_id=1")
        self.assertEqual(self.client.get("/community/1/images/102").status_code, 404)
        self.assertEqual(self.storage.call_count, 1)

    def test_foreign_unpublished_video_link_and_missing_attachments_are_not_public_images(self):
        for attachment_id in (101, 104, 201, 301, 401, 501, 601, 999):
            with self.subTest(attachment_id=attachment_id):
                self.assertEqual(self.client.get(f"/community/1/images/{attachment_id}").status_code, 404)
        self.storage.assert_not_called()

    def test_private_posts_comments_likes_and_attachments_still_require_login(self):
        for method, path in (("GET", "/v1/posts/1"), ("GET", "/v1/posts/1/comments"),
                             ("PUT", "/v1/posts/1/like"), ("GET", "/v1/attachments/102/content")):
            with self.subTest(path=path):
                self.assertEqual(self.client.request(method, path).status_code, 401)

    def test_android_association_requires_real_config_and_supports_certificate_rotation(self):
        first, second = ":".join(["AB"] * 32), ":".join(["CD"] * 32)
        with patch.dict(os.environ, {"ANDROID_APP_LINK_SHA256_FINGERPRINTS": f" {first.lower()}, {second} "}):
            response = self.client.get("/.well-known/assetlinks.json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), [{
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {"namespace": "android_app", "package_name": "com.onetouch.football",
                       "sha256_cert_fingerprints": [first, second]},
        }])
        for value in ("", "SET_ME", "AB:CD", first + ","):
            with self.subTest(value=value), patch.dict(os.environ, {"ANDROID_APP_LINK_SHA256_FINGERPRINTS": value}):
                self.assertEqual(self.client.get("/.well-known/assetlinks.json").status_code, 503)

    def test_ios_association_and_native_hosts_match_the_public_share_domain(self):
        app_id = "TESTTEAM12.com.onetouch.football"
        with patch.dict(os.environ, {"IOS_APP_LINK_APP_ID": app_id}):
            response = self.client.get("/.well-known/apple-app-site-association")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["content-type"], "application/json")
        details = response.json()["applinks"]["details"]
        self.assertEqual(details, [{
            "appIDs": [app_id],
            "components": [{"/": "/community/*/*", "exclude": True}, {"/": "/community/*"}],
        }])
        frontend = Path(__file__).resolve().parents[3] / "frontend"
        entitlements = plistlib.loads((frontend / "ios/Runner/Runner.entitlements").read_bytes())
        self.assertEqual(entitlements["com.apple.developer.associated-domains"], ["applinks:1touch.football"])
        manifest = ET.parse(frontend / "android/app/src/main/AndroidManifest.xml")
        android = "{http://schemas.android.com/apk/res/android}"
        links = [node for node in manifest.iter("intent-filter") if node.get(android + "autoVerify") == "true"]
        self.assertEqual(len(links), 1)
        self.assertEqual(links[0].find("data").attrib, {
            android + "scheme": "https", android + "host": "1touch.football", android + "pathPrefix": "/community/",
        })
        with patch.dict(os.environ, {"IOS_APP_LINK_APP_ID": ""}):
            self.assertEqual(self.client.get("/.well-known/apple-app-site-association").status_code, 503)


if __name__ == "__main__":
    unittest.main()
