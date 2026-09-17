from __future__ import annotations

from contextlib import contextmanager
from datetime import date
import io
import json
from pathlib import Path
import re
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.core import db
    from one_touch_loader.loaders import probability_loader as loader


class Cursor:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def execute(self, sql, params):
        # 값·키·중복 처리의 실제 저장 동작을 격리 DB에서 확인해요.
        sql = re.sub(r"ON DUPLICATE KEY UPDATE .*", "ON CONFLICT DO NOTHING", sql, flags=re.S)
        return self.connection.execute(sql.replace("%s", "?"), params)


class Connection:
    def __init__(self, connection):
        self.connection = connection

    def cursor(self):
        return Cursor(self.connection)


class ProbabilityStorageTests(unittest.TestCase):
    def setUp(self):
        self.connection = sqlite3.connect(":memory:")
        self.addCleanup(self.connection.close)
        self.connection.executescript("""
            PRAGMA foreign_keys=ON;
            CREATE TABLE probability_models (model_id TEXT PRIMARY KEY,payload TEXT NOT NULL);
            CREATE TABLE probability_runs (
                run_id TEXT PRIMARY KEY,model_id TEXT NOT NULL REFERENCES probability_models(model_id),
                season_id INTEGER,as_of TEXT,payload TEXT NOT NULL);
        """)
        @contextmanager
        def transaction():
            try:
                yield Connection(self.connection)
                self.connection.commit()
            except Exception:
                self.connection.rollback()
                raise
        p = patch.object(db, "transaction", side_effect=transaction)
        self.transaction = p.start()
        self.addCleanup(p.stop)

    def test_repeat_is_idempotent_and_changed_run_preserves_original(self):
        model = {"model_id": "a" * 64, "method": "example"}
        loader.store_model(model)
        loader.store_model(model)
        run = {"model_id": model["model_id"], "as_of": "2026-09-17T00:00:00Z", "season_id": 1, "teams": {}}
        first = loader.store_run(run)
        self.assertEqual(first, loader.store_run(run))
        second = loader.store_run(dict(run, simulations=100000))
        self.assertNotEqual(first, second)
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM probability_models").fetchone()[0], 1)
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM probability_runs").fetchone()[0], 2)
        self.assertEqual(json.loads(self.connection.execute("SELECT payload FROM probability_runs WHERE run_id=?", (first,)).fetchone()[0]), run)

    def test_cannot_publish_run_without_model(self):
        with self.assertRaises(sqlite3.IntegrityError):
            loader.store_run({"model_id": "unknown", "season_id": 1, "as_of": "2026-09-17T00:00:00Z"})
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM probability_runs").fetchone()[0], 0)

    def test_daily_and_current_runs_roll_back_together(self):
        loader.store_model({"model_id": "known"})
        with self.assertRaises(sqlite3.IntegrityError):
            loader.store_runs([
                {"model_id": "known", "season_id": 1, "as_of": "2026-09-17T00:00:00Z"},
                {"model_id": "missing", "season_id": 1, "as_of": "2026-09-17T13:00:00Z"},
            ])
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM probability_runs").fetchone()[0], 0)

    def test_conflicting_mapping_is_rejected_before_source_read(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "mapping.json"
            path.write_text('{"Barcelona": 2}', encoding="utf-8")
            with patch.object(loader, "_fetch", side_effect=[[{"team_id": 1}, {"team_id": 2}],
                                                           [{"external_team_id": "Barcelona", "team_id": 1}]]), \
                 patch.object(loader, "ClubEloClient") as source:
                with self.assertRaisesRegex(ValueError, "conflicts"):
                    loader.sync_elo(path, cache_dir=None, apply=False)
                source.assert_not_called()
                self.transaction.assert_not_called()

    def test_check_parses_source_without_writing_database(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "mapping.json"
            path.write_text('{"Barcelona": 1}', encoding="utf-8")
            history = {"datasets": {"data": [{"Date": "2026-09-01", "Elo": 2000, "segment_id": 0}]}}
            with patch.object(loader, "_fetch", side_effect=[[{"team_id": 1}], []]), \
                 patch.object(loader, "ClubEloClient") as source, patch("sys.stdout", new=io.StringIO()):
                source.return_value.get_html.return_value = "<script>var vegaJson = " + json.dumps(history) + ";</script>"
                result = loader.sync_elo(path, cache_dir=None, apply=False)
                self.assertEqual(result, {"teams": 1, "ratings": 1, "applied": False})
                self.transaction.assert_not_called()


if __name__ == "__main__":
    unittest.main()
