"""시즌별 스쿼드 포지션을 프로필이나 출전 기록으로 덮지 않는지 확인해요."""
from datetime import datetime
import sqlite3
import unittest

from one_touch_loader.core.player_positions import season_player_position_ids


class PlayerPositionsTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.row_factory = sqlite3.Row
        self.addCleanup(self.db.close)
        self.queries = []
        self.db.executescript('''
            CREATE TABLE players (player_id INTEGER PRIMARY KEY,position_id INTEGER);
            CREATE TABLE positions (position_id INTEGER PRIMARY KEY,position_group_id INTEGER);
            CREATE TABLE competitions (competition_id INTEGER PRIMARY KEY);
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY,competition_id INTEGER,name TEXT,is_current INTEGER);
            CREATE TABLE team_squad_members (player_id INTEGER,team_id INTEGER,season_id INTEGER,position_group_id INTEGER);
            CREATE TABLE stages (stage_id INTEGER PRIMARY KEY,season_id INTEGER);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY,stage_id INTEGER,starting_at TEXT,state_id INTEGER);
            CREATE TABLE fixture_lineups (fixture_id INTEGER,player_id INTEGER,team_id INTEGER,
                lineup_type_id INTEGER,minutes_played INTEGER,rating REAL,match_position_id INTEGER);
            CREATE TABLE fixture_events (fixture_id INTEGER,team_id INTEGER,event_type_id INTEGER,
                player_id INTEGER,related_player_id INTEGER);
            INSERT INTO positions VALUES (156,27),(150,26),(154,25);
            INSERT INTO players VALUES (1,156),(2,150),(3,NULL),(4,156);
            INSERT INTO competitions VALUES (564),(301);
            INSERT INTO seasons VALUES (1,564,'2026/2027',1),(2,564,'2025/2026',0),(3,301,'2025/2026',0);
            INSERT INTO stages VALUES (1,1),(2,2),(3,3);
            INSERT INTO team_squad_members VALUES
                (1,83,1,26),(2,83,1,27),(3,83,1,26),(4,83,1,NULL),
                (1,83,2,26),(2,83,2,27),(3,83,2,NULL),(4,83,2,NULL);
            INSERT INTO fixtures VALUES (1,1,'2026-08-01 12:00:00',5),(2,1,'2026-08-02 12:00:00',5);
            INSERT INTO fixture_lineups VALUES (1,1,83,11,90,8,25),(2,1,83,11,90,8,25);
        ''')

    def fetch(self, sql, params=()):
        self.queries.append((sql, params))
        return [dict(r) for r in self.db.execute(sql.replace('%s', '?'), params)]

    def positions(self, name='2026/2027', **kwargs):
        return season_player_position_ids(self.fetch, name, datetime(2026,10,5), **kwargs)

    def test_current_squad_wins_even_when_profile_and_matches_disagree(self):
        self.assertEqual(self.positions(), {1:26,2:27,3:26,4:None})
        self.assertEqual(len(self.queries), 1)
        self.assertNotIn('fixture_lineups', self.queries[0][0])

    def test_past_season_uses_its_squad_even_when_current_profile_differs(self):
        self.assertEqual(self.positions('2025/2026', season_id=2), {1:26,2:27,3:None,4:None})

    def test_no_appearance_required_and_missing_position_is_not_inferred(self):
        self.db.execute('INSERT INTO fixture_lineups VALUES (1,4,83,11,90,8,27)')
        self.assertEqual(self.positions(player_ids=[2,4]), {2:27,4:None})
        self.assertEqual(self.positions(player_ids=[]), {})

    def test_league_scope_does_not_use_another_leagues_squad(self):
        self.db.execute('INSERT INTO team_squad_members VALUES (1,90,3,25)')
        self.assertEqual(self.positions('2025/2026',season_id=2,player_ids=[1]), {1:26})
        self.assertEqual(self.positions('2025/2026',season_id=3,player_ids=[1]), {1:25})

    def test_transfer_chooses_recent_teams_raw_position_without_counting_positions(self):
        self.db.executescript('''
            INSERT INTO team_squad_members VALUES (1,90,2,27);
            INSERT INTO fixtures VALUES (3,2,'2025-08-01 12:00:00',5),(4,2,'2026-01-01 12:00:00',5);
            INSERT INTO fixture_lineups VALUES (3,1,83,11,90,8,25),(4,1,90,11,90,8,25);
        ''')
        self.assertEqual(self.positions('2025/2026',season_id=2,player_ids=[1]), {1:27})
        self.assertEqual(len(self.queries), 2)
        self.assertTrue(all('match_position_id' not in sql for sql, _ in self.queries))


if __name__ == '__main__':
    unittest.main()
