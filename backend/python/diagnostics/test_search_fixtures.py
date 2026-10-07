"""검색 SQL의 상태별 개수와 날짜 정렬을 메모리 DB에서 확인해요."""
import sqlite3
import unittest
from unittest.mock import patch

with patch('mysql.connector.pooling.MySQLConnectionPool') as pool:
    pool.return_value.get_connection.side_effect = AssertionError('Operational DB access in tests')
    from one_touch_loader.api.repos import fixtures_repo as repo


class FixtureSearchTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.addCleanup(self.db.close)
        self.db.row_factory = sqlite3.Row
        self.db.create_function('UTC_TIMESTAMP', 0, lambda: '2026-10-07 12:00:00')
        self.db.create_function('DATE_FORMAT', 2, lambda value, pattern: value)
        self.db.executescript('''
            CREATE TABLE teams (team_id INTEGER PRIMARY KEY, name TEXT, short_name TEXT,
                short_code TEXT, image_path TEXT);
            INSERT INTO teams VALUES (8,'Liverpool','Liverpool','LIV',NULL),
                (9,'Everton','Everton','EVE',NULL), (10,'Exeter','Exeter','EXE',NULL);
            CREATE TABLE competitions (competition_id INTEGER PRIMARY KEY, competition_type TEXT);
            INSERT INTO competitions VALUES (8,'league');
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY, competition_id INTEGER);
            INSERT INTO seasons VALUES (1,8);
            CREATE TABLE stages (stage_id INTEGER PRIMARY KEY, season_id INTEGER, name TEXT);
            INSERT INTO stages VALUES (1,1,'Regular Season');
            CREATE TABLE fixture_states (state_id INTEGER PRIMARY KEY, state_code TEXT, name TEXT);
            CREATE TABLE rounds (round_id INTEGER PRIMARY KEY, name TEXT);
            CREATE TABLE venues (venue_id INTEGER PRIMARY KEY, name TEXT);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY, stage_id INTEGER,
                round_id INTEGER, group_id INTEGER, aggregate_id INTEGER, leg TEXT,
                venue_id INTEGER, state_id INTEGER, starting_at TEXT, home_team_id INTEGER,
                away_team_id INTEGER, home_score INTEGER, away_score INTEGER,
                home_penalty_score INTEGER, away_penalty_score INTEGER);
        ''')
        self.db.executemany('INSERT INTO fixture_states (state_id) VALUES (?)',
                            [(state,) for state in range(1, 26)])
        reader = patch.object(repo, 'fetch_all_dict', side_effect=self.read)
        self.fetch = reader.start()
        self.addCleanup(reader.stop)

    def read(self, sql, params):
        return [dict(row) for row in self.db.execute(sql.replace('%s', '?'), params)]

    def fixture(self, identifier, state, kickoff, *, home=8, away=9):
        self.db.execute('''INSERT INTO fixtures
            (fixture_id,stage_id,state_id,starting_at,home_team_id,away_team_id)
            VALUES (?,1,?,?,?,?)''', (identifier, state, kickoff, home, away))

    def test_balances_past_and_future_and_keeps_every_live_match(self):
        for day in range(1, 8):
            self.fixture(day, 5, f'2026-10-{day:02} 10:00:00')
        for day in range(8, 16):
            self.fixture(day, 1, f'2026-10-{day:02} 10:00:00', home=9, away=8)
        self.fixture(101, 3, '2026-10-07 10:00:00')
        self.fixture(102, 2, '2026-10-07 11:00:00')
        self.fixture(103, 21, '2026-10-07 11:00:00')
        self.fixture(104, 2, '2026-10-07 11:30:00', home=9, away=10)

        rows = repo.search_fixtures('LIV', team_ids=(8,))

        self.assertEqual([row['fixture_id'] for row in rows],
                         [102, 103, 101, 7, 6, 5, 4, 3, 8, 9, 10, 11, 12])
        self.assertEqual([row['status'] for row in rows], ['live'] * 3 + ['past'] * 5 + ['upcoming'] * 5)

    def test_sparse_groups_do_not_fill_the_other_groups_quota(self):
        for day in range(1, 8):
            self.fixture(day, 5, f'2026-10-{day:02} 10:00:00')
        self.fixture(8, 1, '2026-10-08 10:00:00')

        rows = repo.search_fixtures('Liverpool', team_ids=())

        self.assertEqual([row['fixture_id'] for row in rows], [7, 6, 5, 4, 3, 8])

    def test_date_boundaries_and_shared_status_groups(self):
        self.fixture(1, 1, '2026-10-07 12:00:00')
        self.fixture(2, 13, '2026-10-08 12:00:00')
        self.fixture(3, 14, '2026-10-06 12:00:00')
        self.fixture(4, 7, '2026-10-05 12:00:00')
        self.fixture(5, 10, '2026-10-01 12:00:00')
        self.fixture(6, 5, '2026-10-09 12:00:00')
        self.fixture(7, 12, '2026-10-08 12:00:00')
        self.fixture(8, 1, None)
        self.fixture(9, 5, None)

        rows = repo.search_fixtures('리버풀', team_ids=(8,))

        self.assertEqual([row['fixture_id'] for row in rows], [3, 4, 1, 2])
        self.assertEqual([row['status'] for row in rows], ['past', 'past', 'upcoming', 'upcoming'])

    def test_matching_both_participants_does_not_duplicate_a_fixture(self):
        self.fixture(1, 2, '2026-10-07 11:00:00')
        rows = repo.search_fixtures('unmatched', team_ids=(8, 9))
        self.assertEqual([row['fixture_id'] for row in rows], [1])

    def test_team_name_parameters_cannot_change_the_query(self):
        self.fixture(1, 2, '2026-10-07 11:00:00')
        self.assertEqual(repo.search_fixtures("' OR 1=1 --", team_ids=()), [])
        self.assertEqual(self.fetch.call_count, 1)


if __name__ == '__main__':
    unittest.main()
