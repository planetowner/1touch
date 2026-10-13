"""운영 DB·사진을 바꾸지 않고 썸네일과 변경 확인 응답을 검사해요."""
from io import BytesIO
import unittest
from unittest.mock import patch

from botocore.response import StreamingBody
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from PIL import Image

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api.deps import get_user_id
    from one_touch_loader.api.routes import avatars
    from one_touch_loader.api.services import media_storage


class AvatarThumbnailTests(unittest.TestCase):
    def setUp(self):
        media_storage._image_preview_bytes.cache_clear()
        self.addCleanup(media_storage._image_preview_bytes.cache_clear)
        app = FastAPI()
        app.include_router(avatars.router, prefix="/v1")
        app.dependency_overrides[get_user_id] = lambda: 1
        self.app = app
        self.client = self.enterContext(TestClient(app))
        self.item = {"object_key": "avatars/first", "byte_size": 10, "content_type": "image/jpeg"}
        self.query = self.enterContext(patch.object(avatars, "fetch_one_dict", return_value=self.item))
        self.storage = self.enterContext(patch.object(media_storage, "object_operation"))
        self.url = "/v1/users/1/avatar?thumbnail=true"

    def image_source(self, mode="RGB", size=(1080, 1080), orientation=None):
        output = BytesIO()
        image = Image.new(mode, size, (20, 80, 140, 100) if mode == "RGBA" else (20, 80, 140))
        exif = Image.Exif()
        if orientation is not None:
            exif[274] = orientation
        image.save(output, format="PNG" if mode == "RGBA" else "JPEG", exif=exif)
        data = output.getvalue()
        body = StreamingBody(BytesIO(data), len(data))
        self.storage.return_value = {"Body": body, "ContentLength": len(data)}
        return data, body

    def test_thumbnail_reuses_shared_resize_without_writing_storage(self):
        original, body = self.image_source()
        first = self.client.get(self.url)
        second = self.client.get(self.url)
        self.assertEqual(first.status_code, 200)
        self.assertEqual(first.content, second.content)
        self.assertEqual(Image.open(BytesIO(first.content)).size, (384, 384))
        self.assertLess(len(first.content), len(original))
        self.assertEqual(first.headers["content-type"], "image/webp")
        self.assertEqual(first.headers["cache-control"], "private, no-cache")
        self.assertEqual(first.headers["vary"], "Authorization")
        self.storage.assert_called_once_with("get_object", Key="avatars/first")
        self.assertTrue(body._raw_stream.closed)
        self.assertEqual(self.query.call_count, 2)

    def test_unchanged_photo_returns_304_without_reading_r2_even_after_cache_clear(self):
        self.image_source()
        first = self.client.get(self.url)
        media_storage._image_preview_bytes.cache_clear()
        second = self.client.get(self.url, headers={"If-None-Match": first.headers["etag"]})
        self.assertEqual(second.status_code, 304)
        self.assertEqual(second.content, b"")
        self.storage.assert_called_once()

    def test_replaced_and_deleted_photos_do_not_validate_old_thumbnail(self):
        self.image_source()
        etag = self.client.get(self.url).headers["etag"]
        self.item["object_key"] = "avatars/replaced"
        self.image_source(size=(80, 80))
        updated = self.client.get(self.url, headers={"If-None-Match": etag})
        self.assertEqual(updated.status_code, 200)
        self.assertNotEqual(updated.headers["etag"], etag)
        self.assertEqual(Image.open(BytesIO(updated.content)).size, (80, 80))
        self.query.return_value = None
        self.assertEqual(self.client.get(self.url, headers={"If-None-Match": etag}).status_code, 404)

    def test_access_is_checked_before_cached_or_conditional_response(self):
        self.image_source()
        etag = self.client.get(self.url).headers["etag"]
        with patch.object(avatars, "get_user", return_value={"favorite_team_id": 83}), \
                patch.object(avatars, "require_profile"), \
                patch.object(avatars, "require_visible_author", side_effect=HTTPException(403, "Blocked")):
            response = self.client.get("/v1/users/2/avatar?thumbnail=true", headers={"If-None-Match": etag})
            self.assertEqual(response.status_code, 403)
        self.app.dependency_overrides.clear()
        self.assertEqual(self.client.get(self.url, headers={"If-None-Match": etag}).status_code, 401)
        self.storage.assert_called_once()

    def test_original_response_remains_unchanged(self):
        original, _ = self.image_source()
        response = self.client.get("/v1/users/1/avatar")
        self.assertEqual(response.content, original)
        self.assertEqual(response.headers["cache-control"], "private, no-store")

    def test_orientation_transparency_and_small_images_are_preserved(self):
        for mode, orientation, expected in (("RGB", 6, (30, 40)), ("RGBA", None, (40, 30))):
            with self.subTest(mode=mode):
                media_storage._image_preview_bytes.cache_clear()
                self.image_source(mode, (40, 30), orientation)
                response = self.client.get(self.url)
                image = Image.open(BytesIO(response.content))
                self.assertEqual(image.size, expected)
                if mode == "RGBA":
                    self.assertEqual(image.getpixel((0, 0))[3], 100)


if __name__ == "__main__":
    unittest.main()
