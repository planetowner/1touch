"""운영 DB 없이 전날 순위, 필터, 일별 저장과 조회 전용 실행을 검증해요."""
from decimal import Decimal
import sqlite3
import unittest
from unittest.mock import MagicMock, patch

from diagnostics import test_player_rating_rankings as fixtures
from one_touch_loader.core.player_rank_changes import compare_rankings
from one_touch_loader.loaders import player_ranking_history_loader as history


def row(pid, rating, *, league=8, matches=10, position='FW'):
    return dict(player_id=pid, season_id=league * 10000 + 2026, competition_id=league,
                rating_sum=Decimal(str(rating)) * matches, rated_matches=matches, position=position)


def compare(current, previous, **filters):
    return compare_rankings(current, previous, season_name='2026/2027',
                            as_of='2026-09-22T12:00:00Z', **filters)


class RankingMovementTests(unittest.TestCase):
    def test_up_down_unchanged_and_competition_ties(self):
        result = compare([row(1, 9), row(2, 9), row(3, 7), row(4, 6)],
                         [row(1, 8), row(2, 7), row(3, 9), row(4, 6)])
        self.assertEqual([(r['rank'], r['previous_rank'], r['rank_delta'], r['movement'])
                          for r in result['items']],
                         [(1, 2, 1, 'up'), (1, 3, 2, 'up'), (3, 1, -2, 'down'), (4, 4, 0, 'unchanged')])

    def test_twelve_to_nine_is_three_places(self):
        before = [row(pid, 20 - pid) for pid in range(1, 13)]
        after = [row(pid, 11.5 if pid == 12 else 20 - pid) for pid in range(1, 13)]
        changed = next(r for r in compare(after, before)['items'] if r['player_id'] == 12)
        self.assertEqual((changed['rank'], changed['rank_delta']), (9, 3))

    def test_each_league_and_position_has_its_own_population(self):
        before = [row(1, 7), row(2, 8), row(3, 9, league=82), row(4, 9, position='MF')]
        after = [row(1, 8.5), *before[1:]]
        self.assertEqual(compare(after, before)['items'][2]['previous_rank'], 4)
        scoped = compare(after, before, competition_id=8, position='FW')['items']
        self.assertEqual((scoped[0]['rank'], scoped[0]['previous_rank'], scoped[0]['rank_delta']), (1, 2, 1))

    def test_transfer_is_weighted_once_and_rounded_display_does_not_determine_rank(self):
        rows = [row(1, 9, matches=1), row(1, 7, league=82, matches=9), row(2, 7.3),
                row(3, 7.201)]
        result = compare(rows, rows)
        self.assertEqual([r['player_id'] for r in result['items']], [2, 3, 1])
        self.assertEqual(result['total'], 3)

    def test_missing_baseline_is_unavailable_but_empty_baseline_is_new(self):
        for previous, expected in ((None, 'unavailable'), ([], 'new')):
            item = compare([row(1, 8)], previous)['items'][0]
            self.assertEqual(item['movement'], expected)
            self.assertIsNone(item['rank_delta'])
            self.assertIsNone(item['previous_rank'])

    def test_new_player_and_new_position_have_no_fake_change(self):
        before = [row(1, 8, position='MF')]
        current = [row(1, 8), row(2, 7)]
        self.assertEqual([r['movement'] for r in compare(current, before, position='FW')['items']], ['new', 'new'])
        self.assertEqual(compare(current, before)['items'][0]['movement'], 'unchanged')

    def test_invalid_filters_are_rejected(self):
        for filters in ({'competition_id': 2}, {'position': 'ST'}):
            with self.assertRaises(ValueError):
                compare([], [], **filters)


class RankingHistoryTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.row_factory = sqlite3.Row
        self.addCleanup(self.db.close)
        self.db.executescript('''
            CREATE TABLE competitions (competition_id INTEGER PRIMARY KEY);
            INSERT INTO competitions VALUES (8),(82),(301),(384),(564),(24);
            CREATE TABLE seasons (season_id INTEGER PRIMARY KEY,competition_id INTEGER,name TEXT,is_current INTEGER);
            CREATE TABLE stages (stage_id INTEGER PRIMARY KEY,season_id INTEGER);
            CREATE TABLE fixtures (fixture_id INTEGER PRIMARY KEY,stage_id INTEGER,state_id INTEGER,starting_at TEXT);
            CREATE TABLE fixture_lineups (fixture_id INTEGER,team_id INTEGER,player_id INTEGER,lineup_type_id INTEGER,
                match_position_id INTEGER,minutes_played INTEGER,rating NUMERIC);
            CREATE TABLE fixture_events (fixture_id INTEGER,team_id INTEGER,event_type_id INTEGER,player_id INTEGER,related_player_id INTEGER);
            CREATE TABLE player_rating_scores (season_id INTEGER,competition_id INTEGER,player_id INTEGER,
                rating_sum NUMERIC,rated_matches INTEGER);
            CREATE TABLE player_ranking_snapshots (snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
                season_name TEXT,snapshot_date TEXT,observed_at TEXT,input_sha256 TEXT,UNIQUE(season_name,snapshot_date));
            CREATE TABLE player_ranking_snapshot_rows (snapshot_id INTEGER,season_id INTEGER,competition_id INTEGER,
                player_id INTEGER,rating_sum NUMERIC,rated_matches INTEGER,position TEXT,
                PRIMARY KEY(snapshot_id,season_id,player_id));
        ''')
        for league in history.RATING_COMPETITION_IDS:
            self.db.execute('INSERT INTO seasons VALUES (?,?,?,1)', (league * 10000 + 2026, league, '2026/2027'))
        self.db.execute('INSERT INTO seasons VALUES (999,24,?,1)', ('2026/2027',))
        self.db.execute('INSERT INTO stages VALUES (1,82026),(2,999)')
        self.set_scores([row(1, 8), row(2, 7)])
        self.add_appearance(1, 1, 27)
        self.add_appearance(2, 2, 26)

    def set_scores(self, rows):
        self.db.execute('DELETE FROM player_rating_scores')
        self.db.executemany('INSERT INTO player_rating_scores VALUES (?,?,?,?,?)',
            [(r['season_id'], r['competition_id'], r['player_id'], str(r['rating_sum']), r['rated_matches']) for r in rows])

    def add_appearance(self, fixture, player, position, *, stage=1):
        self.db.execute('INSERT INTO fixtures VALUES (?,?,5,?)', (fixture, stage, '2026-09-20 10:00:00'))
        self.db.execute('INSERT INTO fixture_lineups VALUES (?,10,?,11,?,90,8)', (fixture, player, position))

    def capture(self, when):
        with fixtures.MemoryCursor(self.db) as cur:
            return history.capture_current_ranking(cur, observed_at=when)

    def changes(self, when, **filters):
        with fixtures.MemoryCursor(self.db) as cur:
            return history.read_changes(cur, observed_at=when, **filters)

    def test_same_day_overwrites_final_snapshot_but_never_moves_comparison_baseline(self):
        self.capture('2026-09-21T10:00:00Z')
        self.set_scores([row(1, 6), row(2, 7)])
        self.capture('2026-09-21T23:59:00Z')
        self.assertFalse(self.changes('2026-09-21T23:59:30Z')['comparison_available'])
        self.set_scores([row(1, 9), row(2, 7)])
        self.capture('2026-09-22T10:00:00Z')
        first = self.changes('2026-09-22T10:01:00Z')['items'][0]
        self.capture('2026-09-22T20:00:00Z')
        self.assertEqual(first, self.changes('2026-09-22T20:01:00Z')['items'][0])
        self.assertEqual((first['previous_rank'], first['rank_delta']), (2, 1))
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM player_ranking_snapshots').fetchone()[0], 2)

    def test_utc_midnight_and_days_without_updates(self):
        self.capture('2026-09-21T23:59:00Z')
        result = self.changes('2026-09-21T20:00:00-04:00')
        self.assertTrue(result['comparison_available'])
        self.assertEqual(result['comparison_date'], '2026-09-21')
        later = self.changes('2026-09-25T10:00:00Z')
        self.assertEqual(later['previous_snapshot_date'], '2026-09-21')
        self.assertEqual(later['comparison_date'], '2026-09-24')
        self.assertTrue(all(r['movement'] == 'unchanged' for r in later['items']))

    def test_first_capture_does_not_fabricate_yesterday_and_seasons_do_not_mix(self):
        self.capture('2026-09-21T12:00:00Z')
        self.assertFalse(self.changes('2026-09-21T20:00:00Z')['comparison_available'])
        self.db.execute("UPDATE seasons SET name='2027/2028'")
        result = self.changes('2027-09-21T12:00:00Z')
        self.assertFalse(result['comparison_available'])
        self.assertTrue(all(r['movement'] == 'unavailable' for r in result['items']))

    def test_unchanged_capture_only_updates_last_observation(self):
        first = self.capture('2026-09-21T10:00:00Z')
        with patch.object(fixtures.MemoryCursor, 'executemany', side_effect=AssertionError('unnecessary row rewrite')):
            again = self.capture('2026-09-21T23:00:00Z')
        self.assertEqual(first['input_sha256'], again['input_sha256'])
        self.assertEqual(again['status'], 'unchanged')
        self.assertEqual(self.changes('2026-09-22T00:01:00Z')['previous_observed_at'], '2026-09-21T23:00:00+00:00')

    def test_cup_position_change_keeps_the_prior_days_position(self):
        self.capture('2026-09-21T12:00:00Z')
        self.add_appearance(3, 1, 26, stage=2)
        self.add_appearance(4, 1, 26, stage=2)
        self.capture('2026-09-22T12:00:00Z')
        result = self.changes('2026-09-22T12:01:00Z', position='MF')['items']
        self.assertEqual(result[0]['movement'], 'new')
        self.assertEqual((result[1]['previous_rank'], result[1]['rank_delta']), (1, -1))

    def test_failed_daily_row_replacement_rolls_back_previous_snapshot(self):
        self.capture('2026-09-21T12:00:00Z')
        self.db.commit()
        original = [tuple(r) for r in self.db.execute('SELECT * FROM player_ranking_snapshot_rows')]
        with self.assertRaisesRegex(RuntimeError, 'failed'):
            with self.db, patch.object(fixtures.MemoryCursor, 'executemany', side_effect=RuntimeError('failed')):
                self.set_scores([row(1, 6), row(2, 7)])
                self.capture('2026-09-21T23:00:00Z')
        self.assertEqual(original, [tuple(r) for r in self.db.execute('SELECT * FROM player_ranking_snapshot_rows')])

    def test_missing_current_league_is_rejected_before_snapshot_writes(self):
        self.db.execute('UPDATE seasons SET is_current=0 WHERE competition_id=82')
        with self.assertRaisesRegex(ValueError, 'five current'):
            self.capture('2026-09-21T12:00:00Z')
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM player_ranking_snapshots').fetchone()[0], 0)


class RankingHistoryCommandTests(unittest.TestCase):
    def test_check_is_read_only_and_does_not_capture(self):
        from one_touch_loader.core import db
        conn = MagicMock()
        with patch.object(db, 'get_conn', return_value=conn), \
                patch.object(history, 'current_ranking_inputs', return_value=('2026/2027', [row(1, 8)])), \
                patch.object(history, 'capture_current_ranking') as capture:
            self.assertEqual(history.run(command='capture')['status'], 'preview')
        capture.assert_not_called()
        conn.start_transaction.assert_called_once_with(readonly=True, consistent_snapshot=True)
        conn.rollback.assert_called_once()
        conn.commit.assert_not_called()

    def test_change_query_cannot_write(self):
        with self.assertRaisesRegex(ValueError, 'Only capture'):
            history.run(command='changes', apply=True)


if __name__ == '__main__':
    unittest.main()
