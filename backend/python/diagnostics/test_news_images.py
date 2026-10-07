"""운영 DB·R2를 바꾸지 않고 썸네일 준비와 공개 응답을 확인해요."""
from datetime import datetime, timedelta, timezone
from contextlib import redirect_stdout
import hashlib
import io
import sqlite3
import unittest
from unittest.mock import MagicMock, Mock, patch

from botocore.exceptions import ClientError
from botocore.response import StreamingBody
from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image
import requests

from one_touch_loader.core.public_images import IMAGE_CACHE_CONTROL, NEWS_IMAGE
from one_touch_loader.loaders import news_images, news_loader

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api import db
    from one_touch_loader.api.repos import news_repo
    from one_touch_loader.api.routes import teams
    from one_touch_loader.api.services import media_storage
    from one_touch_loader.core import db as core_db
    from diagnostics.test_fixture_details import _SqliteCursor
    from diagnostics import migrate_news

NOW = datetime(2026, 10, 2, tzinfo=timezone.utc)


def article(number, **changes):
    return {"article_id": number, "team_id": 37, "language": "ko", "source": f"매체 {number}",
            "title": f"기사 {number}", "url": f"https://example.test/articles/{number}",
            "image_url": f"https://example.test/images/{number}.jpg", "thumbnail_digest": None,
            "published_at": NOW - timedelta(hours=number), **changes}


def source_image():
    buffer = io.BytesIO()
    Image.new("RGB", (1200, 800), "blue").save(buffer, "JPEG")
    return buffer.getvalue()


class NewsThumbnailTests(unittest.TestCase):
    def test_thumbnail_is_card_sized_webp_and_has_no_exif(self):
        data = news_images.make_news_thumbnail(source_image())
        with Image.open(io.BytesIO(data)) as image:
            self.assertEqual(image.format, "WEBP")
            self.assertEqual(image.size, (357, 204))
            self.assertEqual(dict(image.getexif()), {})
        self.assertLess(len(data), len(source_image()))
        with self.assertRaises(OSError):
            news_images.make_news_thumbnail(b"<html>not an image</html>")

    def test_targets_match_api_selection_and_deduplicate_across_teams(self):
        rows = [article(i) for i in range(1, 6)]
        rows += [article(1, team_id=83), article(6, team_id=83, thumbnail_digest="a" * 64),
                 article(7, team_id=83, image_url=None), article(8, language="en"),
                 article(9, published_at=NOW - timedelta(days=15)),
                 article(10, published_at=NOW + timedelta(days=1))]
        targets = news_images.thumbnail_targets(rows, NOW)
        self.assertEqual(targets, {article(i)["image_url"]: {i} for i in (1, 2, 3, 8)})

    def test_targets_skip_other_articles_from_selected_sources(self):
        rows = [article(i, source=source)
                for i, source in enumerate(('A', 'A', 'B', 'B', 'C', 'D'), start=1)]
        targets = news_images.thumbnail_targets(rows, NOW)
        self.assertEqual(targets, {article(i)['image_url']: {i} for i in (1, 3, 5)})

    def test_upload_precedes_db_update_and_completed_images_skip_network(self):
        row = article(1)
        session = MagicMock()
        session.get.return_value.__enter__.return_value.content = source_image()
        client = Mock()
        client.head_object.side_effect = ClientError({"Error": {"Code": "404"}}, "HeadObject")
        digest = hashlib.sha256(news_images.make_news_thumbnail(source_image())).hexdigest()

        def saved(sql, params):
            client.put_object.assert_called_once()
            self.assertIn("AND image_url=%s AND thumbnail_digest IS NULL", sql)
            self.assertEqual(params, (digest, 1, row["image_url"]))
            return 1

        with patch.object(news_repo, "news_candidates", return_value=[row]), \
                patch.object(media_storage, "r2_client", return_value=client), \
                patch("one_touch_loader.api.services.auth_security.required_setting", return_value="bucket"), \
                patch.object(db, "execute", side_effect=saved):
            report = news_images.refresh_news_images(session, NOW)
        self.assertEqual(report, {"prepared": 1, "errors": []})
        self.assertEqual(client.put_object.call_args.kwargs["Key"], NEWS_IMAGE.object_key(digest))
        self.assertEqual(client.put_object.call_args.kwargs["ContentType"], "image/webp")
        session.reset_mock()
        with patch.object(news_repo, "news_candidates", return_value=[{**row, "thumbnail_digest": digest}]), \
                patch.object(media_storage, "r2_client") as r2, patch.object(db, "execute") as execute:
            self.assertEqual(news_images.refresh_news_images(session, NOW), {"prepared": 0, "errors": []})
            session.get.assert_not_called()
            r2.assert_not_called()
            execute.assert_not_called()

    def test_download_decode_and_upload_failure_do_not_publish_missing_images(self):
        for failure in ("download", "decode", "upload"):
            with self.subTest(failure=failure):
                session = MagicMock()
                session.get.return_value.__enter__.return_value.content = (
                    b"bad" if failure == "decode" else source_image())
                if failure == "download":
                    session.get.side_effect = requests.Timeout()
                with patch.object(news_repo, "news_candidates", return_value=[article(1)]), \
                        patch.object(media_storage, "r2_client"), \
                        patch("one_touch_loader.api.services.auth_security.required_setting", return_value="bucket"), \
                        patch.object(news_images, "upload_public_image",
                                     side_effect=ClientError({"Error": {"Code": "AccessDenied"}}, "PutObject")), \
                        patch.object(db, "execute") as execute:
                    report = news_images.refresh_news_images(session, NOW)
                execute.assert_not_called()
                self.assertEqual(report["prepared"], 0)
                self.assertEqual(report["errors"][0]["article_ids"], [1])

    def test_changed_original_clears_digest_but_unchanged_or_missing_original_preserves_it(self):
        transaction = MagicMock()
        cursor = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
        saved = {**article(1), "url_hash": "b" * 64, "team_ids": []}
        with patch.object(core_db, "transaction", transaction):
            news_loader.save_articles({"key": "source", "language": "ko"}, [saved], NOW, None)
        sql, params = cursor.execute.call_args_list[0].args
        # 기존 진단의 MySQL→SQLite 변환을 써서 실제 갱신 결과를 확인해요.
        sql = _SqliteCursor._sql(sql).replace("article_id=LAST_INSERT_ID(article_id),", "").replace("<=>", "IS")
        with sqlite3.connect(":memory:") as connection:
            connection.execute("""CREATE TABLE news_articles (
                article_id INTEGER PRIMARY KEY,source_key TEXT,language TEXT,title TEXT,url TEXT,
                url_hash TEXT UNIQUE,image_url TEXT,thumbnail_digest TEXT,published_at TEXT,collected_at TEXT)""")
            for original, expected in ((saved["image_url"], "a" * 64), (None, "a" * 64),
                                       ("https://example.test/changed.jpg", None)):
                connection.execute("DELETE FROM news_articles")
                connection.execute("INSERT INTO news_articles(url_hash,image_url,thumbnail_digest) VALUES(?,?,?)",
                                   (saved["url_hash"], saved["image_url"], "a" * 64))
                values = list(params)
                values[5] = original
                connection.execute(sql, values)
                self.assertEqual(connection.execute("SELECT image_url,thumbnail_digest FROM news_articles").fetchone(),
                                 (original or saved["image_url"], expected))


class NewsImageApiTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(teams.router, prefix="/v1")
        self.app = app
        self.client = TestClient(app, base_url="https://api.example.test")

    def test_public_image_uses_only_news_prefix_with_immutable_cache(self):
        digest = "a" * 64
        body = StreamingBody(io.BytesIO(b"webp"), 4)
        with patch.object(media_storage, "r2_client") as client, \
                patch.object(media_storage, "required_setting", return_value="bucket"):
            client.return_value.get_object.return_value = {"Body": body}
            response = self.client.get(f"/v1/news-images/{digest}.webp")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.content, b"webp")
            self.assertEqual(response.headers["content-type"], "image/webp")
            self.assertEqual(response.headers["cache-control"], IMAGE_CACHE_CONTROL)
            self.assertEqual(response.headers["etag"], f'"{digest}"')
            client.return_value.get_object.assert_called_once_with(Bucket="bucket", Key=f"news-images/{digest}.webp")
        self.assertTrue(body._raw_stream.closed)
        with patch.object(media_storage, "r2_client") as client:
            self.assertEqual(self.client.get("/v1/news-images/avatars.webp").status_code, 422)
            client.assert_not_called()

    def test_news_api_prefers_prepared_image_and_preserves_original_when_not_ready(self):
        self.app.dependency_overrides[teams.get_user_id] = lambda: 1
        rows = [article(1, thumbnail_digest="a" * 64), article(2), article(3, image_url=None)]
        with patch.object(teams, "get_team", return_value={"team_id": 37}), \
                patch.object(teams, "get_team_news", return_value={"team_id": 37, "language": "ko", "items": rows}):
            response = self.client.get("/v1/teams/37/news?language=ko")
        self.assertEqual(response.status_code, 200)
        images = [item["image_url"] for item in response.json()["items"]]
        self.assertEqual(images, [NEWS_IMAGE.url("https://api.example.test", "a" * 64), article(2)["image_url"], None])
        self.assertNotIn("thumbnail_digest", response.json()["items"][0])


class NewsMigrationTests(unittest.TestCase):
    def test_default_migration_only_inspects_schema(self):
        with patch("sys.argv", ["migrate_news"]), redirect_stdout(io.StringIO()), \
                patch.object(core_db, "fetch_all", return_value=[]) as read, \
                patch.object(core_db, "transaction") as write:
            migrate_news.main()
        self.assertEqual(read.call_count, 3)
        write.assert_not_called()

    def test_apply_adds_column_only_when_missing(self):
        for installed in (False, True):
            with self.subTest(installed=installed), patch("sys.argv", ["migrate_news", "--apply"]), \
                    redirect_stdout(io.StringIO()), \
                    patch.object(core_db, "fetch_all", return_value=[("thumbnail_digest",)] if installed else []), \
                    patch.object(core_db, "transaction") as transaction:
                migrate_news.main()
            cursor = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
            alters = [call.args[0] for call in cursor.execute.call_args_list if "ALTER TABLE" in call.args[0]]
            self.assertEqual(len(alters), 0 if installed else 1)


if __name__ == "__main__":
    unittest.main()
