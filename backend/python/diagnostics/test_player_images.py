"""실제 사진·운영 DB·R2를 바꾸지 않고 교체와 보존 규칙을 확인해요."""
from contextlib import contextmanager
import hashlib
import io
import json
from pathlib import Path
import sqlite3
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import Mock, patch

from botocore.exceptions import ClientError
from botocore.response import StreamingBody
from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from diagnostics import import_player_images as importer
    from diagnostics.test_fixture_details import _SqliteCursor
    from one_touch_loader.api.routes.players import router
    from one_touch_loader.api.services import media_storage
    from one_touch_loader.core.player_images import IMAGE_CACHE_CONTROL, image_url
    from one_touch_loader.loaders import players_loader


class ImagePlanTests(unittest.TestCase):
    def test_external_id_matches_even_when_filename_and_database_names_differ(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            image = root / "6,403_Manuel_Iori.png"
            Image.new("RGBA", (150, 150), (10, 20, 30, 0)).save(image)
            duplicate = root / "copy"
            duplicate.mkdir()
            (duplicate / image.name).write_bytes(image.read_bytes())
            (root / "__MACOSX").mkdir()
            (root / "__MACOSX/._image.png").write_bytes(b"not an image")
            scanned = importer.scan_images([root])
            self.assertEqual(len(scanned), 1)
            plan = importer.build_plan(scanned, [
                {"player_id": 100, "sportmonks_id": "6403", "display_name": "Marko Dmitrovic", "image_path": "old"},
                {"player_id": 6403, "sportmonks_id": "20", "display_name": "Other player", "image_path": "other"},
            ], "https://api.example.test")
            self.assertEqual(plan["matched"][0]["player_id"], 100)
            self.assertEqual(plan["summary"]["db_players_without_file"], 1)

    def test_conflicting_same_id_images_and_opaque_images_are_rejected(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            for name, color in (("1_A.png", (1, 2, 3, 0)), ("1_B.png", (4, 5, 6, 0))):
                Image.new("RGBA", (150, 150), color).save(root / name)
            with self.assertRaisesRegex(ValueError, "Different images"):
                importer.scan_images([root])
        with TemporaryDirectory() as folder:
            Image.new("RGB", (150, 150)).save(Path(folder) / "2_Opaque.png")
            with self.assertRaisesRegex(ValueError, "transparent"):
                importer.scan_images([folder])

    def test_unknown_ids_are_not_inserted_and_identical_placeholder_uploads_are_shared(self):
        images = {pid: {"sportmonks_id": pid, "sha256": "a" * 64, "byte_size": 123, "path": str(pid)}
                  for pid in (1, 2, 3)}
        players = [{"player_id": pid, "sportmonks_id": str(pid), "display_name": "P", "image_path": None}
                   for pid in (1, 2)]
        plan = importer.build_plan(images, players, "https://api.example.test")
        self.assertEqual(plan["summary"]["unique_uploads"], 1)
        self.assertEqual(plan["summary"]["upload_bytes"], 123)
        self.assertEqual(plan["unmatched"][0]["sportmonks_id"], 3)
        self.assertEqual(plan["matched"][0]["image_path"], plan["matched"][1]["image_path"])


class ImageResponseTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(router, prefix="/v1")
        self.client = TestClient(app)
        self.digest = "a" * 64
        self.url = f"/v1/player-images/{self.digest}.png"

    def test_player_image_is_public_cached_and_only_reads_its_own_prefix(self):
        body = StreamingBody(io.BytesIO(b"png-bytes"), 9)
        with patch.object(media_storage, "r2_client") as client, \
                patch.object(media_storage, "required_setting", return_value="private-bucket"):
            client.return_value.get_object.return_value = {"Body": body}
            response = self.client.get(self.url)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.content, b"png-bytes")
            self.assertEqual(response.headers["content-type"], "image/png")
            self.assertEqual(response.headers["cache-control"], IMAGE_CACHE_CONTROL)
            self.assertTrue(body._raw_stream.closed)
            client.return_value.get_object.assert_called_once_with(
                Bucket="private-bucket", Key=f"player-images/{self.digest}.png")

    def test_invalid_digest_does_not_access_storage(self):
        with patch.object(media_storage, "r2_client") as client:
            self.assertEqual(self.client.get("/v1/player-images/avatars.png").status_code, 422)
            client.assert_not_called()

    def test_missing_image_is_404_and_storage_failure_is_502(self):
        for code, status in (("NoSuchKey", 404), ("AccessDenied", 502)):
            with self.subTest(code=code), patch.object(media_storage, "r2_client") as client, \
                    patch.object(media_storage, "required_setting", return_value="bucket"):
                client.return_value.get_object.side_effect = ClientError({"Error": {"Code": code}}, "GetObject")
                self.assertEqual(self.client.get(self.url).status_code, status)

    def test_member_attachments_keep_their_private_range_response(self):
        body = StreamingBody(io.BytesIO(b"abc"), 3)
        with patch.object(media_storage, "object_operation", return_value={
                "Body": body, "ContentLength": 3, "ContentRange": "bytes 0-2/10"}):
            response = media_storage.private_content(
                {"object_key": "avatars/private", "byte_size": 10, "content_type": "image/png"}, "bytes=0-2")
            self.assertEqual(response.status_code, 206)
            self.assertEqual(response.headers["cache-control"], "private, no-store")
        body.close()


class UploadTests(unittest.TestCase):
    def test_upload_is_idempotent_and_changed_sources_are_not_uploaded(self):
        with TemporaryDirectory() as folder:
            path = Path(folder) / "image.png"
            path.write_bytes(b"image")
            digest = hashlib.sha256(b"image").hexdigest()
            item = {"path": str(path), "sha256": digest}
            client = Mock()
            client.head_object.side_effect = ClientError({"Error": {"Code": "404"}}, "HeadObject")
            self.assertTrue(importer.upload_image(client, "bucket", item))
            self.assertEqual(client.put_object.call_args.kwargs["Body"], b"image")
            client.reset_mock()
            client.head_object.side_effect = None
            client.head_object.return_value = {"ContentLength": 5, "ContentType": "image/png", "Metadata": {"sha256": digest}}
            self.assertFalse(importer.upload_image(client, "bucket", item))
            client.put_object.assert_not_called()
            path.write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "changed after inspection"):
                importer.upload_image(client, "bucket", item)

    def test_upload_or_public_verification_failure_does_not_start_database_transaction(self):
        plan = {"matched": [{"sha256": "a" * 64}]}
        for failing in ("upload_image", "verify_public_image"):
            transaction = Mock()
            with self.subTest(failing=failing), TemporaryDirectory() as folder, \
                    patch.object(importer, "upload_image", return_value=True), \
                    patch.object(importer, "verify_public_image"), \
                    patch.object(importer, failing, side_effect=RuntimeError("failed")):
                with self.assertRaisesRegex(RuntimeError, "failed"):
                    importer.apply_plan(plan, Path(folder), client=Mock(), bucket="bucket", transaction=transaction)
                transaction.assert_not_called()


class ImageDatabaseTests(unittest.TestCase):
    def setUp(self):
        self.sql = sqlite3.connect(":memory:")
        self.addCleanup(self.sql.close)
        self.sql.executescript("""CREATE TABLE players (
            player_id INTEGER PRIMARY KEY,display_name TEXT,full_name TEXT,position_id INTEGER,
            nationality_id INTEGER,date_of_birth TEXT,height_cm INTEGER,weight_kg INTEGER,image_path TEXT,
            image_is_custom INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE player_external_ids(player_id INTEGER,provider TEXT,external_player_id TEXT,
            PRIMARY KEY(player_id,provider));""")

    def test_provider_refresh_preserves_custom_image_but_updates_normal_images_and_profiles(self):
        rows = [(pid, "Before", "Before", 24, 1, None, 180, 75, f"old-{pid}") for pid in (1, 2)]
        with _SqliteCursor(self.sql) as cursor:
            players_loader._write_player_rows(cursor, rows, update_existing=False)
            self.sql.execute("UPDATE players SET image_is_custom=1 WHERE player_id=1")
            updated = [(pid, "After", "After", 24, 1, None, 181, 76, f"provider-{pid}") for pid in (1, 2, 3)]
            players_loader._write_player_rows(cursor, updated, update_existing=True)
        self.assertEqual(self.sql.execute("SELECT player_id,display_name,image_path,image_is_custom FROM players ORDER BY player_id").fetchall(),
                         [(1, "After", "old-1", 1), (2, "After", "provider-2", 0), (3, "After", "provider-3", 0)])

    def test_import_backs_up_current_values_and_only_changes_matched_image_columns(self):
        class Cursor(_SqliteCursor):
            def execute(self, sql, params=()):
                return super().execute(sql.replace(" FOR UPDATE", ""), params)

            def fetchall(self):
                keys = [column[0] for column in self.cursor.description]
                return [dict(zip(keys, row)) for row in super().fetchall()]

        connection = Mock()
        connection.cursor.side_effect = lambda **kwargs: Cursor(self.sql)
        self.sql.execute("INSERT INTO players(player_id,display_name,image_path) VALUES(1,'Name','old')")
        self.sql.execute("INSERT INTO players(player_id,display_name,image_path) VALUES(2,'Untouched','keep')")
        self.sql.execute("INSERT INTO player_external_ids VALUES(1,'sportmonks','101')")
        items = [{"player_id": 1, "sportmonks_id": 101, "image_path": image_url("https://api.test", "a" * 64)}]
        with TemporaryDirectory() as folder:
            backup = Path(folder) / "before.json"
            importer.update_image_rows(connection, items, backup)
            self.assertEqual(json.loads(backup.read_text())[0]["image_path"], "old")
        self.assertEqual(self.sql.execute("SELECT display_name,image_path,image_is_custom FROM players ORDER BY player_id").fetchall(),
                         [("Name", items[0]["image_path"], 1), ("Untouched", "keep", 0)])

    def test_database_failure_rolls_back_image_changes(self):
        self.sql.execute("INSERT INTO players(player_id,image_path) VALUES(1,'old')")
        self.sql.commit()

        @contextmanager
        def transaction():
            with self.sql:
                yield self.sql

        def fail_update(connection, items, backup):
            connection.execute("UPDATE players SET image_path='new',image_is_custom=1 WHERE player_id=1")
            raise RuntimeError("update failed")

        with TemporaryDirectory() as folder, patch.object(importer, "upload_image", return_value=True), \
                patch.object(importer, "verify_public_image"), patch.object(importer, "update_image_rows", side_effect=fail_update):
            with self.assertRaisesRegex(RuntimeError, "update failed"):
                importer.apply_plan({"matched": [{"sha256": "a" * 64}]}, Path(folder),
                                    client=Mock(), bucket="bucket", transaction=transaction)
        self.assertEqual(self.sql.execute("SELECT image_path,image_is_custom FROM players").fetchone(), ("old", 0))


if __name__ == "__main__":
    unittest.main()
