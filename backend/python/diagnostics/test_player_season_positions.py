"""원본 경기와 저장 포지션이 같은 트랜잭션에서 바뀌는지 확인해요."""
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
import re
import sqlite3
import unittest
from unittest.mock import MagicMock, patch

from diagnostics.test_player_rating_rankings import MemoryCursor
from one_touch_loader.loaders import player_season_positions_loader as loader
from one_touch_loader.loaders import fixture_details_loader as details


class PositionStorageTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.row_factory = sqlite3.Row
        self.addCleanup(self.db.close)
        self.db.executescript('''
            PRAGMA foreign_keys=ON;
            CREATE TABLE players (player_id BIGINT PRIMARY KEY);
            CREATE TABLE competitions (competition_id BIGINT PRIMARY KEY);
            CREATE TABLE seasons (season_id BIGINT PRIMARY KEY,competition_id BIGINT,name TEXT);
            CREATE TABLE stages (stage_id BIGINT PRIMARY KEY,season_id BIGINT);
            CREATE TABLE fixtures (fixture_id BIGINT PRIMARY KEY,stage_id BIGINT,state_id INT,starting_at TEXT);
            CREATE TABLE fixture_lineups (fixture_id BIGINT,team_id BIGINT,player_id BIGINT,
                lineup_type_id INT,match_position_id INT,minutes_played INT,rating REAL);
            CREATE TABLE fixture_events (fixture_id BIGINT,team_id BIGINT,event_type_id INT,
                player_id BIGINT,related_player_id BIGINT);
            INSERT INTO players VALUES (1),(2),(3);
            INSERT INTO competitions VALUES (8),(24);
            INSERT INTO seasons VALUES (10,8,'2026/2027'),(11,24,'2026/2027'),(12,8,'2025/2026');
            INSERT INTO stages VALUES (10,10),(11,11),(12,12);
            INSERT INTO fixtures VALUES (1,10,5,'2026-08-01 10:00:00'),
                (2,11,5,'2026-08-02 10:00:00'),(3,11,2,'2026-08-03 10:00:00'),
                (4,12,5,'2025-08-01 10:00:00');
            INSERT INTO fixture_lineups VALUES (1,6,1,11,26,90,7),(2,9,1,11,27,90,7),
                (3,9,1,11,25,90,7),(2,9,2,12,26,0,NULL),(4,6,1,11,24,90,7);
        ''')
        ddl = (Path(__file__).parents[1] / 'one_touch_loader/sql/create_player_season_positions.sql').read_text()
        self.db.executescript(re.sub(r'\) ENGINE=[^;]+;', ');', ddl))
        self.conn = MagicMock()
        self.conn.cursor.side_effect = lambda **kwargs: MemoryCursor(self.db)
        self.conn.close.side_effect = lambda: None
        self.conn.rollback.side_effect = self.db.rollback
        self.db.commit()

    @contextmanager
    def transaction(self):
        try:
            yield self.conn
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

    def refresh(self, season='2026/2027', **kwargs):
        with self.conn.cursor(dictionary=True) as cur:
            return loader.refresh_season_positions(cur, season, as_of=datetime(2026,10,2), **kwargs)

    def saved(self):
        return [tuple(row) for row in self.db.execute(
            'SELECT season_name,player_id,position_group_id FROM player_season_positions ORDER BY season_name,player_id')]

    def test_one_value_across_teams_and_competitions_with_separate_past_season(self):
        self.assertEqual(self.refresh(), 1)
        self.refresh('2025/2026')
        self.assertEqual(self.saved(), [('2025/2026',1,24),('2026/2027',1,27)])

    def test_substitution_event_only_update_and_removal(self):
        self.refresh()
        with loader.refresh_positions_after_fixtures(self.conn, [2]):
            self.db.execute('INSERT INTO fixture_events VALUES (2,9,18,2,NULL)')
        self.assertIn(('2026/2027',2,26), self.saved())
        with loader.refresh_positions_after_fixtures(self.conn, [2]):
            self.db.execute('DELETE FROM fixture_events WHERE fixture_id=2')
        self.assertNotIn(('2026/2027',2,26), self.saved())

    def test_position_correction_and_removed_player_are_refreshed(self):
        self.refresh()
        with loader.refresh_positions_after_fixtures(self.conn, [2]):
            self.db.execute('UPDATE fixture_lineups SET match_position_id=25 WHERE fixture_id=2 AND player_id=1')
        self.assertEqual(self.saved(), [('2026/2027',1,25)])
        with loader.refresh_positions_after_fixtures(self.conn, [1,2]):
            self.db.execute('DELETE FROM fixture_lineups WHERE fixture_id IN (1,2)')
        self.assertEqual(self.saved(), [])

    def test_completion_cancellation_and_timestamp_correction(self):
        self.refresh()
        with loader.refresh_positions_after_fixtures(self.conn, [3]):
            self.db.execute('UPDATE fixtures SET state_id=5 WHERE fixture_id=3')
        self.assertEqual(self.saved(), [('2026/2027',1,25)])
        with loader.refresh_positions_after_fixtures(self.conn, [3]):
            self.db.execute('UPDATE fixtures SET state_id=2 WHERE fixture_id=3')
        self.assertEqual(self.saved(), [('2026/2027',1,27)])
        with loader.refresh_positions_after_fixtures(self.conn, [2]):
            self.db.execute("UPDATE fixtures SET starting_at='2026-07-01 10:00:00' WHERE fixture_id=2")
        self.assertEqual(self.saved(), [('2026/2027',1,26)])

    def test_season_move_refreshes_old_and_new_seasons(self):
        self.refresh()
        self.refresh('2025/2026')
        with loader.refresh_positions_after_fixtures(self.conn, [4]):
            self.db.execute('UPDATE fixtures SET stage_id=10 WHERE fixture_id=4')
        self.assertEqual(self.saved(), [('2026/2027',1,27)])

    def test_same_input_does_not_recalculate_or_write(self):
        self.refresh()
        with patch.object(loader, 'refresh_season_positions', wraps=loader.refresh_season_positions) as refresh:
            with loader.refresh_positions_after_fixtures(self.conn, [1,2]):
                pass
        refresh.assert_not_called()

    def test_failure_preserves_original_and_saved_positions(self):
        self.refresh()
        self.db.commit()
        before = self.saved()
        with self.assertRaisesRegex(RuntimeError, 'stop'), self.transaction():
            with loader.refresh_positions_after_fixtures(self.conn, [2]):
                self.db.execute('DELETE FROM fixture_lineups WHERE fixture_id=2')
                raise RuntimeError('stop')
        self.assertEqual(self.saved(), before)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM fixture_lineups WHERE fixture_id=2').fetchone()[0], 2)
        with patch.object(loader, 'refresh_season_positions', side_effect=RuntimeError('write failed')):
            with self.assertRaisesRegex(RuntimeError, 'write failed'), self.transaction():
                with loader.refresh_positions_after_fixtures(self.conn, [2]):
                    self.db.execute('DELETE FROM fixture_lineups WHERE fixture_id=2')
        self.assertEqual(self.saved(), before)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM fixture_lineups WHERE fixture_id=2').fetchone()[0], 2)

    def test_rebuild_preview_does_not_write_and_apply_covers_all_seasons(self):
        with patch.object(loader, 'get_conn', return_value=self.conn), \
             patch.object(loader, 'transaction', self.transaction):
            report = loader.rebuild()
            self.assertFalse(report['applied'])
            self.assertEqual(self.saved(), [])
            report = loader.rebuild(apply=True)
        self.assertTrue(report['applied'])
        self.assertEqual(self.saved(), [('2025/2026',1,24),('2026/2027',1,27)])

    def test_detail_writer_updates_raw_and_saved_position_together(self):
        from contextlib import nullcontext
        self.db.execute('ALTER TABLE fixture_lineups ADD COLUMN formation_field TEXT')
        self.db.execute('ALTER TABLE fixture_lineups ADD COLUMN jersey_number INT')
        self.refresh()
        self.db.commit()
        with patch.object(details, 'transaction', self.transaction), \
             patch.object(details.player_rankings, 'refresh_player_ratings_after_fixture', side_effect=lambda *a, **k: nullcontext()), \
             patch.object(details.squad_roles, 'refresh_squad_roles_after_fixture', side_effect=lambda *a, **k: nullcontext()):
            details.replace_fixture_detail_rows(2, {'lineups': [(2,9,1,11,None,None,90,7,25)]})
        self.assertEqual(self.saved(), [('2026/2027',1,25)])
        self.assertEqual(self.db.execute('SELECT match_position_id FROM fixture_lineups WHERE fixture_id=2').fetchone()[0], 25)


if __name__ == '__main__':
    unittest.main()
