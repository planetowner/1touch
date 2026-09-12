from __future__ import annotations

import io
import sqlite3
import unittest
from contextlib import ExitStack, redirect_stdout
from unittest.mock import MagicMock, patch

from one_touch_loader.core import db
from one_touch_loader.loaders import team_seasons_loader as loader


class TeamSeasonReloadTests(unittest.TestCase):
    def setUp(self):
        self.sqlite = sqlite3.connect(":memory:")
        self.addCleanup(self.sqlite.close)
        # 운영 DB에서 확인한 RESTRICT와 CASCADE 관계를 함께 재현해요.
        self.sqlite.executescript("""
            PRAGMA foreign_keys = ON;
            CREATE TABLE team_seasons (
                team_id INTEGER, season_id INTEGER,
                PRIMARY KEY (team_id, season_id)
            );
            CREATE TABLE team_best_eleven_formations (
                team_id INTEGER, season_id INTEGER, formation TEXT,
                FOREIGN KEY (team_id, season_id)
                    REFERENCES team_seasons ON DELETE RESTRICT
            );
            CREATE TABLE player_wages (
                team_id INTEGER, season_id INTEGER, amount INTEGER,
                FOREIGN KEY (team_id, season_id)
                    REFERENCES team_seasons ON DELETE CASCADE
            );
            INSERT INTO team_seasons VALUES (67, 28321), (68, 28321), (8, 28083);
            INSERT INTO team_best_eleven_formations VALUES (68, 28321, '4-3-3');
            INSERT INTO player_wages VALUES (68, 28321, 1000), (8, 28083, 2000);
        """)
        sqlite_cursor = self.sqlite.cursor()
        cursor = MagicMock()
        cursor.execute.side_effect = lambda sql, args=(): sqlite_cursor.execute(sql.replace("%s", "?"), args)
        cursor.executemany.side_effect = lambda sql, rows: sqlite_cursor.executemany(sql.replace("%s", "?"), rows)
        cursor.fetchall.side_effect = sqlite_cursor.fetchall
        self.connection = MagicMock()
        self.connection.cursor.return_value.__enter__.return_value = cursor
        self.connection.commit.side_effect = self.sqlite.commit
        self.connection.rollback.side_effect = self.sqlite.rollback

    def collect(self, incoming):
        counts = {"provider_team_count": len(incoming), "fixture_team_count": None,
                  "stored_team_count": len(incoming), "is_pending": not incoming}
        with ExitStack() as stack:
            stack.enter_context(patch.object(loader, "_load_scope", return_value=[(28321, 82, "2026/2027", True)]))
            stack.enter_context(patch.object(loader, "_load_team_ids", return_value={67, 68, 90}))
            stack.enter_context(patch.object(loader, "SportmonksClient"))
            stack.enter_context(patch.object(loader, "_collect_season_memberships", return_value=(incoming, counts)))
            stack.enter_context(patch.object(db, "get_conn", return_value=self.connection))
            stack.enter_context(redirect_stdout(io.StringIO()))
            return loader.collect_team_seasons_for_name("2026/2027")

    def test_reloading_unchanged_memberships_preserves_restrict_and_cascade_children(self):
        for _ in range(2):
            self.collect([(67, 28321), (68, 28321)])
        self.assertEqual(self.sqlite.execute("SELECT * FROM team_best_eleven_formations").fetchall(),
                         [(68, 28321, "4-3-3")])
        self.assertEqual(self.sqlite.execute("SELECT * FROM player_wages ORDER BY team_id").fetchall(),
                         [(8, 28083, 2000), (68, 28321, 1000)])

    def test_changes_only_requested_memberships_and_preserves_other_seasons(self):
        result = self.collect([(68, 28321), (90, 28321)])
        self.assertEqual(result["stored_memberships"], 2)
        self.assertEqual(self.sqlite.execute("SELECT * FROM team_seasons ORDER BY team_id").fetchall(),
                         [(8, 28083), (68, 28321), (90, 28321)])
        self.assertEqual(self.sqlite.execute("SELECT COUNT(*) FROM player_wages").fetchone()[0], 2)

    def test_real_removal_of_referenced_membership_still_fails_and_rolls_back(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.collect([(90, 28321)])
        self.assertEqual(self.sqlite.execute("SELECT * FROM team_seasons ORDER BY team_id").fetchall(),
                         [(8, 28083), (67, 28321), (68, 28321)])
        self.connection.rollback.assert_called_once()
        self.connection.commit.assert_not_called()


if __name__ == "__main__":
    unittest.main()
