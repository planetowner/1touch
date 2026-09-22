import io
import sqlite3
import unittest
from unittest.mock import MagicMock, patch

from one_touch_loader.loaders import player_team_honours_loader as loader
from one_touch_loader.loaders.player_team_honours_loader import _winner_rows


class PlayerTeamHonoursTests(unittest.TestCase):
    def trophy(self, *, position=1):
        return {'team_id': 10, 'league_id': 20, 'season_id': 30,
                'trophy_id': position, 'trophy': {'name': 'Winner' if position == 1 else 'Runner-up', 'position': position},
                'team': {'id': 10, 'name': 'Team', 'image_path': 'https://example.com/team.png'},
                'league': {'id': 20, 'name': 'Cup'}, 'season': {'id': 30, 'name': '2025/2026'}}

    def test_winners_keep_provider_metadata_but_runner_up_is_excluded(self):
        rows, count = _winner_rows({'trophies': [self.trophy(), self.trophy(position=2)]}, 1)
        self.assertEqual(count, 2)
        self.assertEqual(rows, [(1, 10, 20, 30, 'Team', 'https://example.com/team.png', 'Cup', '2025/2026')])

    def test_missing_metadata_does_not_invent_names_or_remove_verified_win(self):
        trophy = self.trophy()
        trophy.update(team=None, league=None, season=None)
        self.assertEqual(_winner_rows({'trophies': [trophy]}, 1)[0], [(1, 10, 20, 30, None, None, None, None)])

    def test_mismatched_metadata_is_rejected_before_database_replacement(self):
        trophy = self.trophy()
        trophy['season']['id'] = 31
        with self.assertRaisesRegex(ValueError, 'id mismatch'):
            _winner_rows({'trophies': [trophy]}, 1)

    def test_missing_trophy_collection_is_not_an_empty_history(self):
        with self.assertRaises(ValueError):
            _winner_rows({}, 1)

    def test_refresh_keeps_verified_public_name_when_provider_relation_is_null(self):
        trophy = self.trophy()
        # 실제 조회에서 163번 대회와 18220번 시즌의 관계 객체가 모두 비어 있었어요.
        trophy.update(league_id=163, season_id=18220, league=None, season=None)
        row = _winner_rows({'trophies': [trophy]}, 1)[0][0]
        self.assertEqual(row[6], 'Bundesliga Play-offs')
        self.assertIsNone(row[7])

    def test_provider_name_takes_priority_over_public_catalog(self):
        trophy = self.trophy()
        trophy.update(league_id=163, league={'id': 163, 'name': 'Provider name'})
        self.assertEqual(_winner_rows({'trophies': [trophy]}, 1)[0][0][6], 'Provider name')


class HonourMetadataBackfillTests(unittest.TestCase):
    def rows(self):
        return [
            {'player_id': pid, 'team_id': 10, 'competition_id': cid, 'season_id': sid,
             'competition_name': name, 'season_name': season}
            for pid, cid, sid, name, season in (
                (1, 163, 100, None, None), (2, 163, 100, None, None),
                (3, 163, 101, 'Saved name', '2025/2026'), (4, 999999, 102, None, None))]

    def test_plan_preserves_known_names_and_groups_missing_seasons_by_id(self):
        plan = loader.prepare_metadata_updates(self.rows())
        self.assertEqual(plan['summary'], {
            'honours_scanned': 4, 'missing_competition_names_before': 3,
            'competition_names_to_fill': 2, 'projected_missing_competition_names': 1,
            'missing_season_names': 3, 'unresolved_competition_ids': 1, 'unresolved_season_ids': 2})
        self.assertEqual([row['player_id'] for row in plan['updates']], [1, 2])
        self.assertTrue(all(row['source_url'] == 'https://www.sportmonks.com/football-api/coverage/'
                            for row in plan['updates']))
        self.assertEqual(plan['unresolved_seasons'][0], {
            'competition_id': 163, 'competition_name': 'Bundesliga Play-offs',
            'season_id': 100, 'affected_honours': 2})
        self.assertEqual(plan['unresolved_competitions'], [{'competition_id': 999999, 'affected_honours': 1}])

    def test_public_document_supplies_names_absent_from_coverage_page(self):
        row = self.rows()[0] | {'competition_id': 1741}
        update = loader.prepare_metadata_updates([row])['updates'][0]
        self.assertEqual(update['competition_name'], 'CONCACAF Nations League')
        self.assertIn('docs.google.com/spreadsheets/', update['source_url'])

    def test_check_never_opens_a_write_transaction(self):
        with patch.object(loader, '_read_honour_metadata', return_value=self.rows()), \
             patch.object(loader, 'transaction') as transaction:
            result = loader.fill_missing_competition_names()
        transaction.assert_not_called()
        self.assertFalse(result['applied'])
        self.assertEqual(result['updated_rows'], 0)

    def test_apply_reports_fresh_counts_after_commit(self):
        before = self.rows()
        after = [r | {'competition_name': 'Bundesliga Play-offs'} if r['player_id'] in (1, 2)
                 else r.copy() for r in before]
        connection = MagicMock()
        cursor = connection.cursor.return_value.__enter__.return_value
        cursor.rowcount = 2
        with patch.object(loader, '_read_honour_metadata', side_effect=[before, after]), \
             patch.object(loader, 'transaction') as transaction:
            transaction.return_value.__enter__.return_value = connection
            result = loader.fill_missing_competition_names(apply=True)
        cursor.executemany.assert_called_once_with(loader.SQL_FILL_COMPETITION_NAME, [
            ('Bundesliga Play-offs', 1, 10, 163, 100), ('Bundesliga Play-offs', 2, 10, 163, 100)])
        self.assertEqual(result['updated_rows'], 2)
        self.assertEqual(result['observed_after']['competition_names_to_fill'], 0)
        self.assertEqual(result['observed_after']['missing_competition_names_before'], 1)
        self.assertEqual(result['observed_after']['missing_season_names'], 3)

    def test_update_sql_changes_only_empty_names_without_adding_or_removing_wins(self):
        with sqlite3.connect(':memory:') as conn:
            conn.execute('''CREATE TABLE player_team_honours (
                player_id INTEGER,team_id INTEGER,competition_id INTEGER,season_id INTEGER,
                competition_name TEXT,season_name TEXT,
                PRIMARY KEY(player_id,team_id,competition_id,season_id))''')
            conn.executemany('INSERT INTO player_team_honours VALUES (?,?,?,?,?,?)', [
                (1, 10, 163, 100, None, '2020/2021'), (2, 10, 163, 100, 'Already filled', None)])
            conn.executemany(loader.SQL_FILL_COMPETITION_NAME.replace('%s', '?'), [
                ('Bundesliga Play-offs', pid, 10, 163, 100) for pid in (1, 2, 999)])
            self.assertEqual(conn.execute('SELECT * FROM player_team_honours ORDER BY player_id').fetchall(), [
                (1, 10, 163, 100, 'Bundesliga Play-offs', '2020/2021'),
                (2, 10, 163, 100, 'Already filled', None)])

    def test_cli_defaults_to_check(self):
        with patch.object(loader, 'fill_missing_competition_names', return_value={}) as fill, \
             patch('sys.stdout', new=io.StringIO()):
            loader.main([])
        fill.assert_called_once_with(apply=False)


if __name__ == '__main__':
    unittest.main()
