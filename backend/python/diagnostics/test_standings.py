from __future__ import annotations

import unittest
import re
import sqlite3
from unittest.mock import Mock, patch

# 단독 실행에서도 운영 DB에 연결하지 않아요.
with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.api.repos import standings_repo
    from one_touch_loader.loaders import standings_loader as loader
    from one_touch_loader.loaders.standings_loader import _previous_positions, _standing_rows


def _details() -> list[dict]:
    values = {
        "overall-won": 3,
        "overall-draw": 2,
        "overall-lost": 1,
        "overall-goals-for": 10,
        "overall-goals-against": 4,
    }
    return [
        {"type": {"code": code}, "value": value}
        for code, value in values.items()
    ]


class StandingsLoaderTests(unittest.TestCase):
    def test_targets_keep_domestic_history_and_start_europe_at_league_phase(self):
        with sqlite3.connect(':memory:') as db:
            db.execute('CREATE TABLE seasons(season_id,competition_id,name)')
            db.executemany('INSERT INTO seasons VALUES(?,?,?)', [
                (1, 8, '2017/2018'), (2, 8, '2016/2017'), (3, 24, '2024/2025'),
                (4, 2, '2023/2024'), (23619, 2, '2024/2025'),
                (23620, 5, '2024/2025'), (23616, 2286, '2024/2025'),
            ])
            def fetch(sql, params):
                return db.execute(sql.replace('%s', '?').replace(
                    'LEFT(name, 4)', 'substr(name, 1, 4)'), params).fetchall()
            with patch.object(loader, 'fetch_all', side_effect=fetch):
                self.assertEqual([r[0] for r in loader._targets()], [1, 23619, 23620, 23616])
                self.assertEqual(loader._targets('2024/2025', [5]), [(23620, 5, '2024/2025')])
                self.assertEqual(loader._targets('2023/2024', [2]), [])

    def test_european_tables_validate_league_phase_members_and_share_row_mapping(self):
        with sqlite3.connect(':memory:') as db:
            db.executescript('''
                CREATE TABLE stages(stage_id,season_id,stage_type_id);
                CREATE TABLE rounds(round_id,stage_id,name);
                CREATE TABLE fixtures(stage_id,round_id,state_id,home_team_id,away_team_id);
                CREATE TABLE team_seasons(season_id,team_id);
                INSERT INTO stages VALUES(1,100,223),(2,100,225);
                INSERT INTO rounds VALUES(101,1,'1'),(102,1,'2'),(103,2,'9');
                INSERT INTO fixtures VALUES(1,102,5,10,20),(2,103,5,10,99);
                INSERT INTO team_seasons VALUES(100,10),(100,20),(100,99);
            ''')
            source = [dict(season_id=100, participant_id=team, position=rank,
                           points=11, details=_details())
                      for rank, team in enumerate((10, 20), 1)]
            def fetch(sql, params):
                return db.execute(sql.replace('%s', '?'), params).fetchall()
            db.create_function('REGEXP', 2, lambda pattern, value: bool(re.search(pattern, value)))
            with patch.object(loader, 'SportmonksClient') as client, \
                 patch.object(loader, 'fetch_all', side_effect=fetch), \
                 patch.object(loader, '_replace_season') as save:
                client.return_value.get_standings_for_season.return_value = source
                client.return_value.get_live_standings.return_value = source
                client.return_value.get_standings_for_round.return_value = [
                    {'participant_id': 10, 'position': 2},
                    {'participant_id': 20, 'position': 1},
                ]
                for competition in (2, 5, 2286):
                    for live in (False, True):
                        with self.subTest(competition=competition, live=live):
                            result = loader.refresh_current_table(100, competition, live=live, apply=False)
                            self.assertEqual(result['rows'], 2)
                            save.assert_not_called()
                loader.refresh_current_table(100, 2, live=True, apply=True)
                self.assertEqual(save.call_args.args[1][0], (100, 10, 1, 2, 3, 2, 1, 10, 4, 11))
                source.pop()
                with self.assertRaisesRegex(ValueError, 'every season participant'):
                    loader.refresh_current_table(100, 2, live=True, apply=True)
                self.assertEqual(save.call_count, 1)

    def test_builds_only_stored_columns_from_observed_fields(self) -> None:
        client = Mock()
        client.get_standings_for_season.return_value = [
            {
                "participant_id": 10,
                "position": 2,
                "points": 11,
                "details": _details(),
            }
        ]

        with patch.object(loader, '_previous_positions', return_value={10: 4}):
            self.assertEqual(
                _standing_rows(client, 28083),
                [(28083, 10, 2, 4, 3, 2, 1, 10, 4, 11)],
            )


class StandingsRoundTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.addCleanup(self.db.close)
        self.db.create_function('REGEXP', 2, lambda pattern, value: bool(re.search(pattern, value)))
        self.db.executescript('''
            CREATE TABLE stages(stage_id,season_id,stage_type_id);
            CREATE TABLE rounds(round_id,stage_id,name);
            CREATE TABLE fixtures(stage_id,round_id,state_id,starting_at);
            CREATE TABLE team_seasons(season_id,team_id);
            INSERT INTO stages VALUES(1,28083,223),(2,28083,225),(3,28083,224),(4,99,223);
            INSERT INTO team_seasons VALUES(28083,6),(28083,10);
        ''')
        self.db.executemany('INSERT INTO rounds VALUES(?,1,?)', [(n, str(n)) for n in range(1, 39)])
        fetch = patch.object(loader, 'fetch_all', side_effect=lambda sql, params:
                             self.db.execute(sql.replace('%s', '?'), params).fetchall())
        fetch.start()
        self.addCleanup(fetch.stop)
        self.client = Mock()
        self.client.get_standings_for_round.return_value = [
            {'participant_id': 6, 'position': 20}, {'participant_id': 10, 'position': 19},
        ]

    def test_official_and_live_sixth_round_compare_with_fifth_despite_stale_metadata(self):
        # 실제 오류처럼 순위 응답은 5라운드 ID를 담고, 6라운드 완료 표시도 늦어요.
        self.client.get_rounds_for_season.return_value = [
            {'id': n, 'name': str(n), 'finished': n <= 5, 'is_current': n == 7}
            for n in range(1, 8)
        ]
        source = [dict(season_id=28083, participant_id=team, position=position,
                       round_id=5, points=3, details=_details())
                  for team, position in ((6, 19), (10, 20))]
        self.client.get_standings_for_season.return_value = source
        self.client.get_live_standings.return_value = source
        self.db.executescript('''
            INSERT INTO fixtures VALUES(1,5,5,'2026-09-19'),(1,6,5,'2026-10-10'),
                                       (1,7,1,'2026-10-17');
        ''')
        with patch.object(loader, 'SportmonksClient', return_value=self.client), \
             patch.object(loader, '_replace_season') as save:
            for live in (False, True):
                with self.subTest(live=live):
                    self.db.execute('UPDATE fixtures SET state_id=? WHERE round_id=6', (2 if live else 5,))
                    loader.refresh_current_table(28083, 8, live=live, apply=False)
                    save.assert_not_called()
                    loader.refresh_current_table(28083, 8, live=live, apply=True)
                    row = save.call_args.args[1][0]
                    self.assertEqual((row[2], row[3], row[3] - row[2]), (19, 20, 1))
                    self.assertEqual(save.call_args.kwargs['live'], live)
                    self.client.get_standings_for_round.assert_called_with(5)
                    save.reset_mock()

    def test_first_round_or_unstarted_season_has_no_previous_position(self):
        for state in (1, 2, 5):
            with self.subTest(state=state):
                self.db.execute('DELETE FROM fixtures')
                self.db.execute('INSERT INTO fixtures VALUES(1,1,?,NULL)', (state,))
                self.assertEqual(_previous_positions(self.client, 28083), {})
        self.client.get_standings_for_round.assert_not_called()

    def test_first_match_of_second_round_uses_first_round(self):
        self.db.executescript('INSERT INTO fixtures VALUES(1,1,5,NULL),(1,2,2,NULL);')
        self.assertEqual(_previous_positions(self.client, 28083), {6: 20, 10: 19})
        self.client.get_standings_for_round.assert_called_once_with(1)

    def test_round_number_ignores_future_postponed_cup_and_other_season_matches(self):
        self.db.executescript('''
            INSERT INTO rounds VALUES(90,2,'90'),(91,3,'91'),(92,4,'92'),(93,1,'Final');
            INSERT INTO fixtures VALUES(1,9,5,'2026-10-01'),(1,10,5,'2026-10-05'),
                (1,2,5,'2026-10-10'),(1,11,1,'2026-10-17'),(1,12,13,'2026-10-18'),
                (2,90,5,'2026-10-11'),(3,91,5,'2026-10-11'),
                (4,92,5,'2026-10-11'),(1,93,5,'2026-10-11');
        ''')
        self.assertEqual(_previous_positions(self.client, 28083), {6: 20, 10: 19})
        self.client.get_standings_for_round.assert_called_once_with(9)

    def test_completed_season_uses_penultimate_round(self):
        self.db.execute('INSERT INTO fixtures VALUES(1,38,5,NULL)')
        self.assertEqual(_previous_positions(self.client, 28083), {6: 20, 10: 19})
        self.client.get_standings_for_round.assert_called_once_with(37)


class StandingsRepositoryTests(unittest.TestCase):
    def test_last_five_excludes_qualifying_and_knockout_matches(self):
        with sqlite3.connect(':memory:') as db:
            db.row_factory = sqlite3.Row
            db.create_function('REGEXP', 2, lambda pattern, value: bool(re.search(pattern, value)))
            db.executescript('''
                CREATE TABLE stages(stage_id,season_id,stage_type_id);
                CREATE TABLE rounds(round_id,name);
                CREATE TABLE fixtures(fixture_id,stage_id,round_id,home_team_id,away_team_id,
                                      home_score,away_score,state_id,starting_at);
                INSERT INTO stages VALUES(1,100,223),(2,100,225),(3,100,224);
                INSERT INTO rounds VALUES(1,'1'),(2,'2');
                INSERT INTO fixtures VALUES
                    (1,1,1,10,20,1,0,5,'2026-09-01'),
                    (2,1,2,10,20,0,0,5,'2026-09-08'),
                    (3,2,1,10,99,0,1,5,'2026-09-09'),
                    (4,3,1,10,20,0,1,5,'2026-09-10');
            ''')
            def fetch(sql, params):
                return [dict(row) for row in db.execute(sql.replace('%s', '?'), params)]
            with patch.object(standings_repo, 'fetch_all_dict', side_effect=fetch):
                self.assertEqual(standings_repo._last_five_by_team(100), {10: ['W', 'D'], 20: ['L', 'D']})

    @patch("one_touch_loader.api.repos.standings_repo.fetch_all_dict")
    def test_derives_display_values_from_stored_rows_and_fixtures(
        self,
        fetch_all_dict: Mock,
    ) -> None:
        fetch_all_dict.side_effect = [
            [],
            [
                {
                    "position": 2,
                    "previous_position": 4,
                    "team_id": 10,
                    "team_name": "Home",
                    "team_logo": None,
                    "won": 3,
                    "draw": 2,
                    "lost": 1,
                    "goals_for": 10,
                    "goals_against": 4,
                    "points": 11,
                },
                {
                    "position": 3,
                    "previous_position": None,
                    "team_id": 20,
                    "team_name": "Away",
                    "team_logo": None,
                    "won": 2,
                    "draw": 2,
                    "lost": 2,
                    "goals_for": 8,
                    "goals_against": 7,
                    "points": 8,
                },
                {
                    "position": 4,
                    "previous_position": 4,
                    "team_id": 30,
                    "team_name": "No completed fixtures",
                    "team_logo": None,
                    "won": 0,
                    "draw": 0,
                    "lost": 0,
                    "goals_for": 0,
                    "goals_against": 0,
                    "points": 0,
                },
            ],
            [
                {
                    "home_team_id": 10,
                    "away_team_id": 20,
                    "home_score": 2,
                    "away_score": 1,
                },
                {
                    "home_team_id": 20,
                    "away_team_id": 10,
                    "home_score": 0,
                    "away_score": 0,
                },
            ],
        ]

        rows = standings_repo.list_standings(8, 28083)

        self.assertEqual(rows[0]["matches_played"], 6)
        self.assertEqual(rows[0]["goal_diff"], 6)
        self.assertEqual(rows[0]["rank_delta"], 2)
        self.assertEqual(rows[0]["last5_form"], ["D", "W"])
        self.assertNotIn("previous_position", rows[0])
        self.assertIsNone(rows[1]["rank_delta"])
        self.assertEqual(rows[1]["last5_form"], ["D", "L"])
        self.assertEqual(rows[2]["last5_form"], [])
        fixture_query = fetch_all_dict.call_args_list[2].args[0]
        self.assertIn("r.name REGEXP '^[0-9]+$'", fixture_query)


if __name__ == "__main__":
    unittest.main()
