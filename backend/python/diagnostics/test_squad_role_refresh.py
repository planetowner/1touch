"""종료·정정·종료 취소 때 역할을 같은 트랜잭션으로 갱신하는지 검증해요."""
import re
import sqlite3
import unittest
from unittest.mock import patch

from diagnostics.test_squad_roles import inputs, loader


class Cursor:
    def __init__(self, db):
        self.cur = db.cursor()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.cur.close()

    def execute(self, sql, params=()):
        self.cur.execute(sql.replace('%s', '?').replace('FOR UPDATE', ''), params)

    def fetchone(self):
        row = self.cur.fetchone()
        return dict(row) if row is not None else None

    def fetchall(self):
        return [dict(row) for row in self.cur.fetchall()]


class AutomaticRoleTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.row_factory = sqlite3.Row
        self.db.create_function('REGEXP', 2, lambda pattern, value: bool(re.search(pattern, value)))
        self.db.executescript('''
            CREATE TABLE seasons (season_id INTEGER, is_current INTEGER, competition_id INTEGER);
            CREATE TABLE stages (stage_id INTEGER, season_id INTEGER);
            CREATE TABLE rounds (round_id INTEGER, name TEXT);
            CREATE TABLE fixtures (fixture_id INTEGER, stage_id INTEGER, round_id INTEGER,
                                   state_id INTEGER, home_team_id INTEGER, away_team_id INTEGER);
            CREATE TABLE fixture_lineups (fixture_id INTEGER, team_id INTEGER, player_id INTEGER,
                                         lineup_type_id INTEGER, minutes_played INTEGER, rating REAL);
            CREATE TABLE fixture_event_types (event_type_id INTEGER, code TEXT);
            CREATE TABLE fixture_events (fixture_id INTEGER, team_id INTEGER, player_id INTEGER,
                                         related_player_id INTEGER, event_type_id INTEGER, event_id INTEGER);
            CREATE TABLE roles (player_id INTEGER PRIMARY KEY, role TEXT);
            INSERT INTO seasons VALUES (1,1,8);
            INSERT INTO stages VALUES (1,1);
            INSERT INTO rounds VALUES (1,'1');
            INSERT INTO fixtures VALUES (1,1,1,5,8,9),(2,1,1,2,8,9);
        ''')
        data = inputs()
        self.db.executemany('INSERT INTO fixture_lineups VALUES (?,?,?,?,?,?)',
                            [(r['fixture_id'], r['team_id'], r['player_id'], r['lineup_type_id'],
                              r['minutes_played'], r['rating']) for r in data['lineups']])
        self.db.execute("INSERT INTO roles VALUES (1,'crucial')")
        self.db.commit()
        self.addCleanup(self.db.close)
        for name, replacement in [('read_squad_role_inputs', self.read),
                                  ('collect_fixture_absences', self.absences),
                                  ('save_current_squad_roles', self.save)]:
            patcher = patch.object(loader, name, side_effect=replacement)
            mocked = patcher.start()
            setattr(self, name, mocked)
            self.addCleanup(patcher.stop)

    def cursor(self, **kwargs):
        return Cursor(self.db)

    def read(self, as_of, *, connection, current_only, team_ids):
        self.assertIs(connection, self)
        self.assertTrue(current_only)
        self.assertEqual(team_ids, [8, 9])
        data = inputs()
        data.update(current_season='2026/2027', training_seasons=[])
        completed = {r[0] for r in self.db.execute('SELECT fixture_id FROM fixtures WHERE state_id=5')}
        data['fixtures'] = [g for g in data['fixtures'] if g['fixture_id'] in completed]
        for lineup in data['lineups']:
            lineup['minutes_played'] = self.db.execute(
                'SELECT minutes_played FROM fixture_lineups WHERE fixture_id=? AND player_id=?',
                (lineup['fixture_id'], lineup['player_id'])).fetchone()[0]
        return data

    @staticmethod
    def absences(fixtures):
        return [dict(fixture_id=f['fixture_id'], absences=[]) for f in fixtures]

    def save(self, rows, *, connection):
        self.assertIs(connection, self)
        self.db.executemany('INSERT OR REPLACE INTO roles VALUES (?,?)',
                            [(r['player_id'], r['role']) for r in rows])
        return len(rows)

    def role(self):
        return self.db.execute('SELECT role FROM roles WHERE player_id=1').fetchone()[0]

    def store(self, state=5, minutes=0, *, records_changed=True):
        with self.db:
            with loader.refresh_squad_roles_after_fixture(self, 2, state_id=state,
                                                          records_changed=records_changed):
                self.db.execute('UPDATE fixtures SET state_id=? WHERE fixture_id=2', (state,))
                self.db.execute('UPDATE fixture_lineups SET minutes_played=? WHERE fixture_id=2 AND player_id=1',
                                (minutes,))

    def test_finish_and_minutes_correction_update_both_teams(self):
        self.store()
        self.assertEqual(self.role(), 'important')
        self.store(minutes=90)
        self.assertEqual(self.role(), 'crucial')
        self.assertEqual(self.save_current_squad_roles.call_count, 2)

    def test_live_and_identical_finished_snapshots_do_not_requery_absences(self):
        self.store(state=2)
        self.collect_fixture_absences.assert_not_called()
        self.store()
        self.store()
        self.collect_fixture_absences.assert_called_once()

    def test_finished_state_reversal_removes_match_from_denominator(self):
        self.store()
        self.store(state=2)
        self.assertEqual(self.role(), 'crucial')

    def test_absence_failure_rolls_back_match_and_roles_for_retry(self):
        self.collect_fixture_absences.side_effect = RuntimeError('source unavailable')
        with self.assertRaisesRegex(RuntimeError, 'source unavailable'):
            self.store()
        self.assertEqual(self.db.execute('SELECT state_id FROM fixtures WHERE fixture_id=2').fetchone()[0], 2)
        self.assertEqual(self.role(), 'crucial')
        self.collect_fixture_absences.side_effect = self.absences
        self.store()
        self.assertEqual(self.role(), 'important')

    def test_role_write_failure_rolls_back_match(self):
        self.save_current_squad_roles.side_effect = RuntimeError('write failed')
        with self.assertRaisesRegex(RuntimeError, 'write failed'):
            self.store()
        self.assertEqual(self.db.execute('SELECT state_id FROM fixtures WHERE fixture_id=2').fetchone()[0], 2)

    def test_cups_previous_seasons_and_unrelated_stats_do_not_refresh(self):
        self.store(records_changed=False)
        self.collect_fixture_absences.assert_not_called()
        self.db.execute('UPDATE seasons SET is_current=0')
        self.store(minutes=90)
        self.collect_fixture_absences.assert_not_called()
        self.db.execute('UPDATE seasons SET is_current=1,competition_id=999')
        self.store(minutes=0)
        self.collect_fixture_absences.assert_not_called()

    def test_invalid_fixture_write_does_not_refresh_roles(self):
        with self.assertRaisesRegex(RuntimeError, 'fixture write failed'):
            with self.db, loader.refresh_squad_roles_after_fixture(self, 2, state_id=5):
                raise RuntimeError('fixture write failed')
        self.collect_fixture_absences.assert_not_called()


if __name__ == '__main__':
    unittest.main()
