from __future__ import annotations

import io
import tempfile
import unittest
from contextlib import ExitStack, redirect_stdout
from pathlib import Path
from unittest.mock import MagicMock, patch

from diagnostics import run_minimal_migration as runner


class MigrationRunnerTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(redirect_stdout(io.StringIO()))
        self.root = Path(self.stack.enter_context(tempfile.TemporaryDirectory()))
        self.stack.enter_context(patch.object(runner, "__file__", str(self.root / "python/diagnostics/run_minimal_migration.py")))
        self.events = []
        self.verify = MagicMock(side_effect=lambda **kw: self.events.append(("verify", kw["before"])))
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.cursor.execute.side_effect = lambda sql: self.events.append(("sql", sql.strip()))
        self.connect = self.stack.enter_context(patch.object(runner, "get_conn", return_value=self.conn))
        def backup(args, **kwargs):
            self.events.append(("backup",))
            self.assertTrue(kwargs["check"])
            self.assertEqual(args[-1], "team_player_injuries")
            path = next(value.split("=", 1)[1] for value in args if value.startswith("--result-file="))
            Path(path).write_text("verified backup", encoding="utf-8")
        self.dump = self.stack.enter_context(patch.object(runner.subprocess, "run", side_effect=backup))
        self.ddl = self.root / "changes.sql"
        self.ddl.write_text("CREATE TABLE example (id INT); ALTER TABLE example ADD name TEXT;", encoding="utf-8")

    def run_migration(self):
        runner.run_migration(name="test", tables=("team_player_injuries",), sql_paths=(self.ddl,), verify_schema=self.verify)

    def test_preflight_backup_sql_postflight_order(self):
        self.run_migration()
        self.assertEqual([item[0] for item in self.events], ["verify", "backup", "sql", "sql", "verify"])
        self.assertEqual(self.events[0], ("verify", True))
        self.assertEqual(self.events[-1], ("verify", False))
        self.conn.commit.assert_called_once()
        self.conn.close.assert_called_once()

    def test_failed_preflight_does_not_dump_or_write(self):
        self.verify.side_effect = AssertionError("not the audited schema")
        with self.assertRaises(AssertionError):
            self.run_migration()
        self.dump.assert_not_called()
        self.connect.assert_not_called()

    def test_failed_dump_does_not_execute_ddl(self):
        self.dump.side_effect = RuntimeError("dump failed")
        with self.assertRaisesRegex(RuntimeError, "dump failed"):
            self.run_migration()
        self.connect.assert_not_called()

    def test_failed_sql_keeps_backup_and_does_not_claim_postflight(self):
        self.cursor.execute.side_effect = RuntimeError("DDL failed")
        with self.assertRaisesRegex(RuntimeError, "DDL failed"):
            self.run_migration()
        self.verify.assert_called_once_with(before=True)
        self.assertEqual(len(list((self.root / "logs/database-backups").glob("*/before_test.sql"))), 1)
        self.conn.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
