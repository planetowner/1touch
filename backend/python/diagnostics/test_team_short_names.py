from contextlib import closing
import json
import sqlite3
import unittest
from unittest.mock import patch


with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from diagnostics import migrate_team_short_names as migration
    from one_touch_loader.api.repos import teams_repo
    from one_touch_loader.api.schemas.common import FixtureOut, TeamOut, StandingRowOut
    from one_touch_loader.loaders.teams_loader import SQL_UPSERT_TEAM


class TeamShortNamesTests(unittest.TestCase):
    def test_reviewed_names_are_unique_and_preserve_requested_spelling(self):
        rows = json.loads(migration.SEED_PATH.read_text(encoding="utf-8"))
        names = migration.short_names()
        self.assertEqual(len(rows), 95)
        self.assertEqual(len(names), 95)
        self.assertEqual(names[83], "Barcelona")
        self.assertEqual(names[117], "Conventry")
        self.assertEqual(names[9818], "R Santandr")
        self.assertEqual(names[683], "M’gladbach")
        self.assertNotIn(90, names)  # 목록에 없는 Augsburg에는 이름을 지정하지 않아요.
        self.assertTrue(all(name and len(name) <= 64 for name in names.values()))

    def test_migration_updates_only_short_names_and_can_run_again(self):
        with closing(sqlite3.connect(":memory:")) as db:
            db.execute("CREATE TABLE teams (team_id INTEGER PRIMARY KEY, name TEXT, short_code TEXT, short_name TEXT)")
            names = migration.short_names()
            db.executemany("INSERT INTO teams VALUES (?, ?, ?, NULL)",
                           [(team_id, f"Original {team_id}", "OLD") for team_id in names])
            db.execute("INSERT INTO teams VALUES (90, 'FC Augsburg', 'FCA', NULL)")

            class Cursor:
                def __enter__(self):
                    return self

                def __exit__(self, *args):
                    return False

                def executemany(self, sql, rows):
                    db.executemany(sql.replace("%s", "?"), rows)

            class Connection:
                def cursor(self):
                    return Cursor()

                def commit(self):
                    db.commit()

            for _ in range(2):
                migration.migrate_data(Connection())
            self.assertEqual(dict(db.execute("SELECT team_id, short_name FROM teams WHERE short_name IS NOT NULL")), names)
            self.assertEqual(db.execute("SELECT name, short_code, short_name FROM teams WHERE team_id=90").fetchone(),
                             ("FC Augsburg", "FCA", None))
            self.assertEqual(db.execute("SELECT name, short_code FROM teams WHERE team_id=83").fetchone(),
                             ("Original 83", "OLD"))

    def test_team_api_reads_stored_name_and_preserves_original_name(self):
        with closing(sqlite3.connect(":memory:")) as db:
            db.row_factory = sqlite3.Row
            db.execute("CREATE TABLE teams (team_id INTEGER PRIMARY KEY, name TEXT, short_name TEXT, short_code TEXT, image_path TEXT)")
            db.execute("INSERT INTO teams VALUES (83, 'FC Barcelona', 'Barcelona', 'BAR', NULL)")
            def fetch(sql, params):
                return dict(db.execute(sql.replace("%s", "?"), params).fetchone())
            with patch.object(teams_repo, "fetch_one_dict", side_effect=fetch):
                team = TeamOut.model_validate(teams_repo.get_team(83)).model_dump()
            self.assertEqual((team["name"], team["short_name"], team["short_code"]),
                             ("FC Barcelona", "Barcelona", "BAR"))

    def test_provider_refresh_does_not_overwrite_app_names(self):
        self.assertNotIn("short_name", SQL_UPSERT_TEAM)

    def test_nested_api_models_expose_nullable_short_names(self):
        self.assertIn("home_team_short_name", FixtureOut.model_fields)
        self.assertIn("away_team_short_name", FixtureOut.model_fields)
        self.assertIn("team_short_name", StandingRowOut.model_fields)
        self.assertIsNone(TeamOut(team_id=90, name="FC Augsburg").short_name)


if __name__ == "__main__":
    unittest.main()
