"""운영 저장소를 사용하지 않고 사진 크기·재사용·접근 권한을 확인해요."""
from datetime import datetime
from io import BytesIO
import unittest
from unittest.mock import patch

from botocore.response import StreamingBody
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from PIL import Image

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.repos import posts_repo
    from one_touch_loader.api.routes import attachments
    from one_touch_loader.api.services import media_storage


class PostImagePreviewTests(unittest.TestCase):
    def setUp(self):
        media_storage._post_preview_bytes.cache_clear()
        self.addCleanup(media_storage._post_preview_bytes.cache_clear)
        app = FastAPI()
        app.include_router(attachments.router, prefix="/v1")
        app.dependency_overrides[get_user_id] = lambda: 1
        self.app = app
        self.client = self.enterContext(TestClient(app))
        self.item = {"attachment_id": 9, "post_id": 9, "post_state": "active",
                     "user_id": 2, "object_key": "posts/test-image", "byte_size": 10,
                     "content_type": "image/jpeg", "created_at": datetime(2026, 10, 6)}
        self.enterContext(patch.object(attachments, "fetch_one_dict", return_value=self.item))
        self.access = self.enterContext(patch.object(attachments, "get_post"))
        self.storage = self.enterContext(patch.object(media_storage, "object_operation"))

    def image_source(self, mode="RGB", size=(4000, 3000), orientation=None):
        source = BytesIO()
        image = Image.new(mode, size, (20, 80, 140, 100) if mode == "RGBA" else (20, 80, 140))
        exif = Image.Exif()
        if orientation is not None:
            exif[274] = orientation
        image.save(source, format="PNG" if mode == "RGBA" else "JPEG", exif=exif)
        body = StreamingBody(BytesIO(source.getvalue()), len(source.getvalue()))
        self.storage.return_value = {"Body": body, "ContentLength": len(source.getvalue())}
        return body

    def test_existing_original_is_reduced_once_without_writing_storage(self):
        source = self.image_source()
        first = self.client.get("/v1/attachments/9/preview")
        second = self.client.get("/v1/attachments/9/preview")
        self.assertEqual(first.status_code, 200)
        self.assertEqual(first.content, second.content)
        self.assertEqual(first.headers["content-type"], "image/webp")
        self.assertEqual(first.headers["cache-control"], "private, no-store")
        self.assertEqual(Image.open(BytesIO(first.content)).size, (1280, 960))
        self.storage.assert_called_once_with("get_object", Key="posts/test-image")
        self.assertTrue(source._raw_stream.closed)
        self.assertEqual(self.access.call_count, 2)

    def test_cached_preview_still_checks_post_access(self):
        self.image_source()
        self.assertEqual(self.client.get("/v1/attachments/9/preview").status_code, 200)
        for status in (403, 404):
            self.access.side_effect = HTTPException(status, "Not accessible")
            self.assertEqual(self.client.get("/v1/attachments/9/preview").status_code, status)
        self.storage.assert_called_once()

    def test_preview_requires_login(self):
        self.app.dependency_overrides.clear()
        self.assertEqual(self.client.get("/v1/attachments/9/preview").status_code, 401)
        self.storage.assert_not_called()

    def test_draft_uses_draft_access_and_other_users_unpublished_files_are_denied(self):
        self.item["post_state"] = "draft"
        with patch.object(attachments, "get_draft", side_effect=HTTPException(403, "Private draft")) as draft:
            self.assertEqual(self.client.get("/v1/attachments/9/preview").status_code, 403)
            draft.assert_called_once_with(1, 9)
        self.item["post_id"] = None
        self.assertEqual(self.client.get("/v1/attachments/9/preview").status_code, 403)
        self.storage.assert_not_called()

    def test_video_does_not_enter_image_decoder_and_original_keeps_range_support(self):
        self.item["content_type"] = "video/mp4"
        self.assertEqual(self.client.get("/v1/attachments/9/preview").status_code, 415)
        self.storage.assert_not_called()
        body = StreamingBody(BytesIO(b"abc"), 3)
        self.storage.return_value = {"Body": body, "ContentLength": 3, "ContentRange": "bytes 0-2/10"}
        response = self.client.get("/v1/attachments/9/content", headers={"Range": "bytes=0-2"})
        self.assertEqual(response.status_code, 206)
        self.assertEqual(response.content, b"abc")
        self.storage.assert_called_once_with("get_object", Key="posts/test-image", Range="bytes=0-2")

    def test_preview_preserves_orientation_and_transparency_without_upscaling(self):
        for mode, orientation, expected in (("RGB", 6, (30, 40)), ("RGBA", None, (40, 30))):
            with self.subTest(mode=mode):
                media_storage._post_preview_bytes.cache_clear()
                self.image_source(mode, (40, 30), orientation)
                response = self.client.get("/v1/attachments/9/preview")
                self.assertEqual(response.status_code, 200)
                image = Image.open(BytesIO(response.content))
                self.assertEqual(image.size, expected)
                if mode == "RGBA":
                    self.assertEqual(image.getpixel((0, 0))[3], 100)

    def test_post_contract_exposes_previews_only_for_images(self):
        rows = [{"attachment_id": index, "link_url": link, "content_type": content_type}
                for index, (link, content_type) in enumerate(
                    ((None, "image/jpeg"), (None, "video/mp4"), ("https://example.test", None)), 1)]
        with patch.object(posts_repo, "fetch_all_dict", return_value=rows):
            result = posts_repo.attachments_for_post(9)
        self.assertEqual(result[0]["preview_url"], "/v1/attachments/1/preview")
        self.assertEqual(result[0]["media_url"], "/v1/attachments/1/content")
        self.assertIsNone(result[1]["preview_url"])
        self.assertIsNone(result[2]["preview_url"])


if __name__ == "__main__":
    unittest.main()
