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
        self.assertEqual(len(rows), 134)
        self.assertEqual(len(names), 134)
        self.assertEqual(names[83], "Barcelona")
        self.assertEqual(names[117], "Conventry")
        self.assertEqual(names[9818], "R Santandr")
        self.assertEqual(names[683], "M’gladbach")
        self.assertNotIn(90, names)  # 목록에 없는 Augsburg에는 이름을 지정하지 않아요.
        self.assertNotIn(62, names)  # UEFA 예선에 있어도 첨부 표에 없는 팀은 제외해요.
        self.assertEqual(names[58], "Sporting")
        self.assertEqual(names[49], "Salzburg")
        self.assertEqual(names[494], "NEC")
        self.assertEqual(names[3369], "Linz ASK")
        self.assertEqual(names[132649], "Ararat-Armenia")
        self.assertTrue(all(name and len(name) <= 64 for name in names.values()))

    def test_preview_accepts_only_reviewed_old_or_corrected_short_names(self):
        rows = migration.reviewed_rows()
        previous = migration.previous_names()
        self.assertEqual(len(previous), 12)
        self.assertEqual(previous[49], "Red Bull Salzburg")
        saved = [(row["team_id"], row.get("name", "Unchanged team"), previous.get(row["team_id"], row["short_name"]))
                 for row in rows]
        schema = [("varchar(64)", "YES")]
        with patch.object(migration, "fetch_all", side_effect=[schema, saved]):
            ready, summary = migration.preview()
        self.assertTrue(ready)
        self.assertEqual((summary["reviewed"], summary["updates"]), (134, 12))
        self.assertEqual({row["team_id"] for row in summary["changes"]}, set(previous))
        corrected = [(key, original, migration.short_names()[key]) for key, original, _ in saved]
        with patch.object(migration, "fetch_all", side_effect=[schema, corrected]):
            self.assertEqual(migration.preview()[1]["updates"], 0)
        for invalid in (
            [row for row in saved if row[0] != 49],
            [(key, "Another club" if key == 49 else original, name) for key, original, name in saved],
            [(key, original, "Other reviewed name" if key == 49 else name) for key, original, name in saved],
        ):
            with patch.object(migration, "fetch_all", side_effect=[schema, invalid]), self.assertRaises(ValueError):
                migration.preview()

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
