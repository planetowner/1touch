"""한 번 수집한 명단으로 선수 저장 후 스쿼드를 갱신하는 순서를 확인해요."""
from copy import deepcopy
from datetime import date
import unittest
from unittest.mock import Mock, patch

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from one_touch_loader.loaders import players_loader as loader
    from one_touch_loader.loaders.team_squad_members_loader import _filter_current_squad_items

from one_touch_loader.core.sportmonks import SportmonksClient


class RenewedPlayerSquadTests(unittest.TestCase):
    def test_verified_renewals_keep_current_squad_and_jersey(self):
        cases = (
            (268, 113, 571561, 492766, 3468, '2025-07-14', 26, 14),
            (129261, 37, 561986, 9253, 625, '2022-07-20', 27, 21),
        )
        for case in cases:
            with self.subTest(player_id=case[0]):
                self.check_renewal(*case)

    def check_renewal(self, player_id, team_id, departure_id, arrival_id,
                      previous_team_id, start, position_id, jersey_number):
        # 실제 응답의 이적 두 건을 재현해요. 재계약 뒤 남은 이탈만 제외하고 영입은 보존해요.
        transfers = [
            dict(id=departure_id, player_id=player_id, from_team_id=team_id, to_team_id=260131,
                 type_id=219, date='2026-07-01', completed=True),
            dict(id=arrival_id, player_id=player_id, from_team_id=previous_team_id, to_team_id=team_id,
                 type_id=220, date=start, completed=True),
        ]
        squad = [dict(player_id=player_id, team_id=team_id, position_id=position_id,
                      jersey_number=jersey_number, start=start, end='2027-06-30')]
        client = SportmonksClient.__new__(SportmonksClient)
        client._iter_paginated_data = Mock()
        sources = (
            (lambda: client.iter_transfers_by_player(player_id), transfers, [arrival_id]),
            (lambda: client.iter_transfers_by_team(team_id), transfers, [arrival_id]),
            (lambda: client.iter_transfers_between_dates(date(2026, 7, 1), date(2026, 10, 7)),
             transfers[:1], []),
        )
        for index, (source, payload, expected_ids) in enumerate(sources):
            with self.subTest(source=index):
                client._iter_paginated_data.return_value = payload
                corrected = list(source())
                self.assertEqual([row['id'] for row in corrected], expected_ids)
                kept, removed = _filter_current_squad_items(
                    squad, corrected, team_id, date(2026, 7, 1), date(2026, 10, 7),
                )
                self.assertEqual(kept, squad)
                self.assertEqual(removed, set())
        client._get = Mock(return_value={'data': transfers[0]})
        self.assertIsNone(client.get_transfer(departure_id))


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
        self.client.get_team_season_squad.side_effect = lambda team, season: deepcopy(self.squads[team])
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
        self.assertEqual(self.client.get_team_season_squad.call_count, 2)
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
