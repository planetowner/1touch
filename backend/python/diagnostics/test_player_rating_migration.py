import unittest
from unittest.mock import patch

with patch("mysql.connector.pooling.MySQLConnectionPool") as pool:
    pool.return_value.get_connection.side_effect = AssertionError("Operational DB access in isolated tests")
    from diagnostics import migrate_player_rating_cumulative as migration


class PlayerRatingMigrationTests(unittest.TestCase):
    def test_verified_old_schema_is_pending_and_check_mode_does_not_run_migration(self):
        values = [[("frozen_at",)], [("(`rated_matches` >= 10)",)]]
        with patch.object(migration, "fetch_all", side_effect=values), patch("builtins.print"):
            self.assertFalse(migration.verify_schema(before=True))
        with patch.object(migration, "verify_schema", return_value=False), patch("sys.argv", ["migration"]):
            with patch("diagnostics.run_minimal_migration.run_migration") as run:
                migration.main()
                run.assert_not_called()

    def test_new_schema_is_verified_and_partial_schema_is_rejected(self):
        with patch.object(migration, "fetch_all", side_effect=[[("updated_at",)], [("(`rated_matches` >= 1)",)]]), patch("builtins.print"):
            self.assertTrue(migration.verify_schema(before=False))
        with patch.object(migration, "fetch_all", side_effect=[[("updated_at",)], [("(`rated_matches` >= 10)",)]]):
            with self.assertRaises(ValueError):
                migration.verify_schema(before=True)

    def test_apply_uses_existing_backup_and_migration_workflow(self):
        with patch.object(migration, "verify_schema", return_value=False), patch("sys.argv", ["migration", "--apply"]):
            with patch("diagnostics.run_minimal_migration.run_migration") as run:
                migration.main()
        self.assertEqual(run.call_args.kwargs["tables"], (
            "player_rating_references", "player_rating_reference_samples", "player_rating_scores",
        ))
        self.assertEqual(run.call_args.kwargs["sql_paths"][0].name, "migrate_player_rating_cumulative.sql")
