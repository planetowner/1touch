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
    def test_latest_model_keeps_method_and_timestamp_order_with_large_payloads(self):
        self.connection.execute('ALTER TABLE probability_models ADD COLUMN created_at TEXT')
        self.connection.create_function('JSON_UNQUOTE', 1, lambda value: value)
        records = [('a', 'league', '2026-09-20'), ('b', 'league', '2026-09-21'),
                   ('c', 'cup', '2026-09-22'), ('d', 'league', '2026-09-21')]
        for identifier, method, stamp in records:
            payload = json.dumps({'model_id': identifier, 'method': method, 'training': 'x' * 1000000})
            self.connection.execute('INSERT INTO probability_models VALUES (?,?,?)', (identifier, payload, stamp))
        def fetch(sql, params=()):
            cursor = self.connection.execute(sql.replace('%s', '?'), params)
            return [dict(zip([c[0] for c in cursor.description], row)) for row in cursor.fetchall()]
        with patch.object(loader, '_fetch', side_effect=fetch):
            self.assertEqual(loader.latest_model('league')['model_id'], 'd')
            self.assertEqual(loader.latest_model('cup')['model_id'], 'c')
            with self.assertRaisesRegex(ValueError, 'Train and store'):
                loader.latest_model('absent')

    def setUp(self):
        self.connection = sqlite3.connect(":memory:")
        self.addCleanup(self.connection.close)
        self.connection.executescript("""
            PRAGMA foreign_keys=ON;
            CREATE TABLE probability_models (model_id TEXT PRIMARY KEY,payload TEXT NOT NULL);
            CREATE TABLE probability_runs (
                run_id TEXT PRIMARY KEY,model_id TEXT NOT NULL REFERENCES probability_models(model_id),
                season_id INTEGER,as_of TEXT,payload TEXT NOT NULL);
            CREATE TABLE teams (team_id INTEGER PRIMARY KEY);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY);
            CREATE TABLE probability_team_results (run_id TEXT REFERENCES probability_runs(run_id),team_id INTEGER REFERENCES teams(team_id),next_fixture_id INTEGER REFERENCES fixtures(fixture_id),payload TEXT,PRIMARY KEY(run_id,team_id));
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
        from one_touch_loader.core.probability_storage import split_run
        self.assertEqual(json.loads(self.connection.execute("SELECT payload FROM probability_runs WHERE run_id=?", (first,)).fetchone()[0]), split_run(run)[0])

    def test_cannot_publish_run_without_model(self):
        with self.assertRaises(sqlite3.IntegrityError):
            loader.store_run({"model_id": "unknown", "season_id": 1, "as_of": "2026-09-17T00:00:00Z"})
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM probability_runs").fetchone()[0], 0)

    def test_display_changes_and_team_order_do_not_duplicate_forecast(self):
        loader.store_model({"model_id": "known"})
        self.connection.executemany("INSERT INTO teams VALUES (?)", [(1,), (2,)])
        self.connection.execute("INSERT INTO fixtures VALUES (10)")
        self.connection.commit()
        run = {"model_id": "known", "season_id": 1, "as_of": "2026-09-17T00:00:00Z",
               "teams": {"1": {"team_name": "Old", "elo": 2000, "cards": [{"old": True}],
                       "what_if": {"fixture": {"fixture_id": 10, "probabilities": [0.4, 0.3, 0.3]}, "scenarios": []}},
                         "2": {"team_name": "Other", "elo": 1900}}}
        first = loader.store_run(run)
        run["teams"]["1"].update(team_name="New", cards=[])
        run["teams"] = dict(reversed(list(run["teams"].items())))
        self.assertEqual(first, loader.store_run(run))
        payload = json.loads(self.connection.execute(
            "SELECT payload FROM probability_team_results WHERE team_id=1").fetchone()[0])
        self.assertNotIn("cards", payload)
        self.assertNotIn("team_name", payload)
        self.assertNotIn("fixture", payload["what_if"])
        self.assertEqual(self.connection.execute("SELECT COUNT(*) FROM probability_team_results").fetchone()[0], 2)

    def test_unknown_team_rolls_back_whole_run(self):
        loader.store_model({"model_id": "known"})
        with self.assertRaises(sqlite3.IntegrityError):
            loader.store_run({"model_id": "known", "season_id": 1, "as_of": "2026-09-17T00:00:00Z",
                              "teams": {"999": {"elo": 1900}}})
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
