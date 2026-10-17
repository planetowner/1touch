"""선수 검색은 개수를 제한하기 전에 이름 일치도를 정렬해요."""
import re
import sqlite3
import unittest
from unittest.mock import MagicMock, patch

with patch('mysql.connector.pooling.MySQLConnectionPool') as pool:
    pool.return_value.get_connection.side_effect = AssertionError('Operational DB access in tests')
    from one_touch_loader.api.repos import player_detail_repo as repo
    from one_touch_loader.core import football_names


class PlayerSearchOrderTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.addCleanup(self.db.close)
        self.db.row_factory = sqlite3.Row
        self.db.create_function('REGEXP_REPLACE', 3,
                                lambda value, pattern, replacement:
                                None if value is None else
                                re.sub(pattern.replace('[[:space:]]', r'\s'), replacement, value))
        self.db.create_function('LOCATE', 2,
                                lambda needle, value: None if value is None else value.find(needle) + 1)
        self.db.executescript('''
            CREATE TABLE players (player_id INTEGER PRIMARY KEY, display_name TEXT,
                display_name_ko TEXT, image_path TEXT);
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY, is_current INTEGER);
            INSERT INTO seasons VALUES (1,1),(2,1),(3,0);
            CREATE TABLE team_squad_members (player_id INTEGER, season_id INTEGER);
        ''')
        self.conn = MagicMock()
        cursor = self.conn.cursor.return_value.__enter__.return_value
        cursor.execute.side_effect = self.execute
        cursor.fetchall.side_effect = lambda: [dict(row) for row in self.rows]
        for target in [patch.object(repo, 'get_conn', return_value=self.conn),
                       patch.object(football_names, 'fetch_all', side_effect=self.read)]:
            target.start()
            self.addCleanup(target.stop)

    def read(self, sql, params):
        return self.db.execute(sql.replace('%s', '?'), params).fetchall()

    def execute(self, sql, params):
        self.rows = self.read(sql, params)

    def player(self, identifier, name, *, korean=None, seasons=(1,)):
        self.db.execute('INSERT INTO players VALUES (?,?,?,NULL)', (identifier, name, korean))
        self.db.executemany('INSERT INTO team_squad_members VALUES (?,?)',
                            [(identifier, season) for season in seasons])

    def ids(self, query, *, limit=None):
        rows = repo.list_player_comparison_candidates(query, limit=limit)
        for row in rows:
            self.assertEqual(set(row), {'player_id', 'name', 'image'})
        return [row['player_id'] for row in rows]

    def test_exact_and_prefix_matches_survive_the_global_search_limit(self):
        for identifier in range(1, 14):
            self.player(identifier, f'A{identifier:02} Rodriguez')
        self.player(100, 'Rodri')
        self.player(101, 'Rodrigo')
        self.player(102, 'Rodri Junior')

        self.assertEqual(self.ids('Rodri', limit=12), [100, 102, 101, *range(1, 10)])
        self.assertEqual(self.ids('Rodri'), [100, 102, 101, *range(1, 14)])

    def test_rule_applies_to_other_names_and_uses_name_then_id_for_ties(self):
        self.player(8, 'Leo')
        self.player(7, 'Leo')
        self.player(6, 'Leon')
        self.player(5, 'Alex Leo')
        self.player(4, 'Bruno Leo')

        self.assertEqual(self.ids('Leo'), [7, 8, 6, 5, 4])

    def test_hyphen_normalization_also_applies_to_match_priority(self):
        self.player(1, 'Alex Heung-Min')
        self.player(2, 'Heung-Min Son')
        self.player(3, 'Heung-Min')
        for query in ['HeungMin', ' Heung-Min ']:
            with self.subTest(query=query):
                self.assertEqual(self.ids(query), [3, 2, 1])

    def test_korean_priority_ignores_whitespace_and_handles_missing_translations(self):
        self.player(1, 'Alex', korean='알렉스 로드리')
        self.player(2, 'Bruno', korean='로드리고')
        self.player(3, 'Zed', korean='로 드\t리')
        self.player(4, 'Missing translation')
        for query in ['로드리', ' 로 드\t리 ']:
            with self.subTest(query=query):
                self.assertEqual(self.ids(query), [3, 2, 1])

    def test_current_membership_does_not_duplicate_players_or_include_old_squads(self):
        self.player(1, 'Leo', seasons=(1, 2))
        self.player(2, 'Leo', seasons=(3,))
        self.player(3, 'Leo', seasons=())

        self.assertEqual(self.ids('Leo'), [1])

    def test_blank_query_keeps_name_order_and_search_is_parameterized(self):
        self.player(1, 'Zed')
        self.player(2, 'Alex')

        self.assertEqual(self.ids('  '), [2, 1])
        self.assertEqual(self.ids("' OR 1=1 --"), [])
        self.conn.commit.assert_not_called()


if __name__ == '__main__':
    unittest.main()
