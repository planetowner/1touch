"""한 번 수집한 명단으로 선수 저장 후 스쿼드를 갱신하는 순서를 확인해요."""
from copy import deepcopy
import unittest
from unittest.mock import Mock, patch

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.loaders import players_loader as loader


class CombinedRefreshTests(unittest.TestCase):
    def setUp(self):
        self.scope = [dict(team_id=team, team_name=str(team), season_id=1,
                           season_name='2026/2027', competition_id=8, is_current=True)
                      for team in (8, 9)]
        self.squads = {team: [dict(player_id=team, position_id=25, jersey_number=10,
                                 player=dict(id=team, display_name=f'Embedded {team}', name=f'Player {team}',
                                             detailed_position_id=24))] for team in (8, 9)}
        self.client = Mock()
        self.client.iter_transfers_by_team.return_value = []
        self.client.get_team_squad.side_effect = lambda team: deepcopy(self.squads[team])
        self.client.get_player_or_none.side_effect = lambda player: dict(
            id=player, display_name=f'Direct {player}', name=f'Player {player}', detailed_position_id=24)
        self.calls = []
        self.saved = []
        def save_players(rows):
            self.calls.append('players')
            self.saved = rows
            return len(rows)
        def save_squad(team, season, squad):
            self.assertEqual(len(self.saved), 2)
            self.calls.append(('squad', team))
            self.assertEqual(squad, self.squads[team])
            return dict(squad_members=len(squad), deleted_stale=0)
        patches = [
            patch.object(loader, 'load_squad_scope', return_value=self.scope),
            patch.object(loader, 'SportmonksClient', return_value=self.client),
            patch.object(loader, 'fetch_all', return_value=[(24,)]),
            patch.object(loader, '_upsert_player_rows', side_effect=save_players),
            patch.object(loader, '_replace_squad_snapshot', side_effect=save_squad),
            patch('builtins.print'),
        ]
        self.mocks = [p.start() for p in patches]
        for p in patches:
            self.addCleanup(p.stop)

    def test_reuses_verified_squads_after_all_direct_profiles_are_saved(self):
        result = loader.collect_players_for_competition_season('2026/2027', 8, with_squads=True)
        self.assertEqual(self.calls, ['players', ('squad', 8), ('squad', 9)])
        self.assertEqual([row[1] for row in self.saved], ['Direct 8', 'Direct 9'])
        self.assertEqual(self.client.iter_transfers_by_team.call_count, 2)
        self.assertEqual(self.client.get_team_squad.call_count, 2)
        self.assertEqual(self.client.get_player_or_none.call_count, 2)
        self.assertEqual(result['stored_squad_members'], 2)

    def test_default_player_command_does_not_write_squads(self):
        result = loader.collect_players_for_competition_season('2026/2027', 8)
        self.assertEqual(self.calls, ['players'])
        self.assertNotIn('stored_squad_members', result)

    def test_failed_profile_prevents_all_squad_writes(self):
        self.client.get_player_or_none.side_effect = [dict(id=8, display_name=None, name='Invalid'),
                                                    dict(id=9, display_name='Valid', name='Valid')]
        with self.assertRaisesRegex(RuntimeError, 'Player load completed with failures'):
            loader.collect_players_for_competition_season('2026/2027', 8, with_squads=True)
        self.mocks[4].assert_not_called()

    def test_failed_scope_prevents_all_squad_writes(self):
        self.client.get_team_squad.side_effect = [[], self.squads[9]]
        with self.assertRaisesRegex(RuntimeError, 'Player load completed with failures'):
            loader.collect_players_for_competition_season('2026/2027', 8, with_squads=True)
        self.mocks[4].assert_not_called()

    def test_failed_player_transaction_prevents_all_squad_writes(self):
        self.mocks[3].side_effect = RuntimeError('player transaction failed')
        with self.assertRaisesRegex(RuntimeError, 'player transaction failed'):
            loader.collect_players_for_competition_season('2026/2027', 8, with_squads=True)
        self.mocks[4].assert_not_called()


class CombinedCommandTests(unittest.TestCase):
    def test_flag_keeps_selected_season_and_competitions(self):
        with patch('mysql.connector.pooling.MySQLConnectionPool'):
            from one_touch_loader import cli
        with patch.object(cli, 'collect_players_for_competition_season', return_value={
                'loaded_team_seasons': 20, 'unique_players': 500}) as collect, \
                patch('sys.argv', ['loader', 'players', '2026/2027', '8', '82', '--with-squads']), \
                patch('builtins.print'):
            cli.main()
        self.assertEqual([c.args for c in collect.call_args_list], [('2026/2027', 8), ('2026/2027', 82)])
        self.assertTrue(all(c.kwargs == dict(with_squads=True) for c in collect.call_args_list))


if __name__ == '__main__':
    unittest.main()
