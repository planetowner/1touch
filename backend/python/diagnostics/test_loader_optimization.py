"""원본 재사용이 출전 기록의 최신성, ID 연결 순서와 실패 시 저장 범위를 지키는지 확인해요."""
from contextlib import ExitStack
from copy import deepcopy
from datetime import date, datetime
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import Mock, patch

from diagnostics.test_squad_roles import inputs
from diagnostics.test_understat import SAMPLE, sample_rows
from one_touch_loader.core import squad_roles as roles
from one_touch_loader.loaders import squad_roles_loader as squads
from one_touch_loader.loaders import understat_ids_loader as ids
from one_touch_loader.loaders import understat_loader as xg
from diagnostics import refresh_squad_roles as command


def role_inputs():
    data = inputs()
    data.update(current_season='2026/2027', training_seasons=[f'{y}/{y+1}' for y in range(2021, 2026)])
    for move in data['transfers']:
        move['transfer_date'] = date(2020, 1, 1)
    for index, season in enumerate(data['training_seasons'], 2):
        data['seasons'].append(dict(season_id=index, competition_id=8, season_name=season, is_current=0))
        data['roster'].extend(dict(row, season_id=index) for row in list(data['roster'][:12]))
        for original in data['fixtures'][:2]:
            fixture = dict(original, season_id=index, fixture_id=index*10+original['fixture_id'],
                           starting_at=original['starting_at'].replace(year=int(season[:4])))
            data['fixtures'].append(fixture)
            data['absences'].append(dict(fixture_id=fixture['fixture_id'], absences=[]))
            minutes = [5, 6, 7, 25, 26, 27, 51, 52, 53, 79, 80]
            data['lineups'].extend(dict(row, season_id=index, fixture_id=fixture['fixture_id'], minutes_played=minute)
                                  for row, minute in zip(data['lineups'][:11], minutes))
    return data


class RoleReuseTests(unittest.TestCase):
    def test_fresh_current_minutes_and_birthday_reuse_only_training(self):
        data = role_inputs()
        data['roster'][11]['date_of_birth'] = date(2004, 9, 20)
        data['as_of'] = datetime(2026, 9, 19)
        first = roles.calculate_squad_roles(data)
        self.assertEqual(first['players'][11]['role'], 'prospect')
        for lineup in data['lineups']:
            if lineup['season_id'] == 1 and lineup['player_id'] == 1:
                lineup['minutes_played'] = 5
        data['as_of'] = datetime(2026, 9, 20)
        with patch.object(roles, 'fit_usage_model', wraps=roles.fit_usage_model) as fit:
            result = roles.calculate_squad_roles(data, calibration=first)
        fit.assert_not_called()
        self.assertTrue(result['calibration_reused'])
        self.assertEqual(first['players'][0]['role'], 'crucial')
        self.assertEqual(result['players'][0]['role'], 'sporadic')
        self.assertEqual(result['players'][11]['role'], 'sporadic')
        self.assertEqual(result['players'][0]['minutes_played'], 10)
        self.assertEqual(result['players'], roles.calculate_squad_roles(data)['players'])

    def test_historical_minutes_correction_refits_and_matches_full_calculation(self):
        data = role_inputs()
        first = roles.calculate_squad_roles(data)
        data['lineups'][-1]['minutes_played'] = 0
        with patch.object(roles, 'fit_usage_model', wraps=roles.fit_usage_model) as fit:
            result = roles.calculate_squad_roles(data, calibration=first)
        self.assertEqual(fit.call_count, 6)
        self.assertFalse(result['calibration_reused'])
        self.assertEqual(result, roles.calculate_squad_roles(data))

    def test_current_injury_confirmation_can_correct_historical_training(self):
        data = role_inputs()
        first = roles.calculate_squad_roles(data)
        data['absences'][1]['absences'] = [dict(team_id=8, player_id=12, category='injury',
            sideline_id=10, start_date=date(2025, 7, 1), end_date=None)]
        result = roles.calculate_squad_roles(data, calibration=first)
        self.assertFalse(result['calibration_reused'])
        self.assertEqual(result['model']['sample_count'], first['model']['sample_count']-1)
        self.assertEqual(result, roles.calculate_squad_roles(data))

    def test_training_version_change_refits(self):
        data = role_inputs()
        first = roles.calculate_squad_roles(data)
        with patch.object(roles, 'CALIBRATION_VERSION', roles.CALIBRATION_VERSION+1):
            result = roles.calculate_squad_roles(data, calibration=first)
        self.assertFalse(result['calibration_reused'])

    def test_absence_cache_round_trip_fetches_current_only_and_force_refreshes_history(self):
        data = role_inputs()
        record = data['absences'][-1]
        record['absences'] = [dict(team_id=8, player_id=12, category='injury', sideline_id=10,
                                   start_date=date(2025, 7, 1), end_date=None)]
        source = {r['fixture_id']: r for r in data['absences']}
        with patch.object(squads, 'collect_fixture_absences', side_effect=lambda fs, **kw:
                          [source[f['fixture_id']] for f in fs]) as fetch:
            cold, cache = squads.collect_squad_role_absences(data)
            self.assertEqual(len(fetch.call_args.args[0]), 12)
            cached_json = json.loads(json.dumps(cache, default=str))
            warm, warm_cache = squads.collect_squad_role_absences(data, cache=cached_json)
            self.assertEqual([f['fixture_id'] for f in fetch.call_args.args[0]], [1, 2])
            self.assertEqual(warm_cache['historical_fixtures_reused'], 10)
            self.assertEqual(warm, cold)
            corrected, _ = squads.collect_squad_role_absences(data, cache=cached_json, refresh_training=True)
            self.assertEqual(len(fetch.call_args.args[0]), 12)
            self.assertEqual(corrected, cold)

    def test_changed_historical_fixture_is_fetched_again_and_removed_fixture_is_dropped(self):
        data = role_inputs()
        source = {r['fixture_id']: r for r in data['absences']}
        with patch.object(squads, 'collect_fixture_absences', side_effect=lambda fs, **kw:
                          [source[f['fixture_id']] for f in fs]) as fetch:
            _, cache = squads.collect_squad_role_absences(data)
            removed = data['fixtures'].pop()
            data['fixtures'][-1]['starting_at'] = datetime(2025, 8, 3)
            result, cache = squads.collect_squad_role_absences(data, cache=cache)
        self.assertEqual(len(fetch.call_args.args[0]), 3)
        self.assertNotIn(str(removed['fixture_id']), cache['historical_absences'])
        self.assertEqual(len(result), 11)

    def test_failed_absence_refresh_preserves_cache_and_never_applies_roles(self):
        with TemporaryDirectory() as folder:
            path = Path(folder)/'training.json'
            original = '{"current_season": "2026/2027"}'
            path.write_text(original, encoding='utf-8')
            with (patch.object(command, 'read_squad_role_inputs', return_value=role_inputs()),
                  patch.object(command, 'collect_squad_role_absences', side_effect=RuntimeError('source failed')),
                  patch.object(command, 'save_current_squad_roles') as save,
                  patch('sys.argv', ['roles', '--apply', '--training-cache', str(path),
                                     '--report', str(Path(folder)/'report.json')])):
                with self.assertRaisesRegex(RuntimeError, 'source failed'):
                    command.main()
            save.assert_not_called()
            self.assertEqual(path.read_text(encoding='utf-8'), original)

    def test_preview_command_persists_training_only_and_reads_new_minutes_on_next_run(self):
        data = role_inputs()
        source = {r['fixture_id']: r for r in data['absences']}
        with TemporaryDirectory() as folder:
            cache_path, report_path = Path(folder)/'training.json', Path(folder)/'report.json'
            with (patch.object(command, 'read_squad_role_inputs', return_value=data) as read,
                  patch.object(squads, 'collect_fixture_absences', side_effect=lambda fs, **kw:
                               [source[f['fixture_id']] for f in fs]) as fetch,
                  patch.object(command, 'save_current_squad_roles') as save,
                  patch('sys.argv', ['roles', '--training-cache', str(cache_path), '--report', str(report_path)])):
                command.main()
                data['lineups'][0]['minutes_played'] = 5
                command.main()
                report = json.loads(report_path.read_text(encoding='utf-8'))
                cache = json.loads(cache_path.read_text(encoding='utf-8'))
            self.assertEqual(read.call_count, 2)
            self.assertEqual(len(fetch.call_args.args[0]), 2)
            self.assertTrue(report['calibration_reused'])
            self.assertEqual(report['players'][0]['minutes_played'], 95)
            self.assertNotIn('players', cache['calibration'])
            self.assertNotIn('1', cache['historical_absences'])
            save.assert_not_called()


class UnderstatReuseTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.source = dict(teams={'148': {'title': 'Barcelona'}, '223': {'title': 'Girona'}},
                           dates=[deepcopy(SAMPLE['match'])])
        self.details = deepcopy(SAMPLE['details'])
        _, players = sample_rows()
        # 실제 별칭 예외가 있는 선수는 그 검증 ID를 써야 이름 일치 경로와 혼동하지 않아요.
        players['9805'] = ids.VERIFIED_UNDERSTAT_PLAYER_ID_OVERRIDES['9805']
        self.expected = xg.normalize_understat_match(SAMPLE['match'], SAMPLE['details'], 1,
                                                    {'148': 10, '223': 20}, players)
        self.missing_player = players.pop('9805')
        self.maps = dict(team={'148': 10, '223': 20}, fixture={}, player=players)
        self.scope = [dict(season_id=100, competition_id=564, name='2024/2025')]
        self.session = Mock(headers={})
        self.session.get.side_effect = self.response
        self.stack.enter_context(patch('one_touch_loader.core.understat.requests.Session', return_value=self.session))
        self.stack.enter_context(patch.object(xg, 'load_understat_scope', return_value=self.scope))
        self.stack.enter_context(patch.object(xg, 'load_external_ids', side_effect=self.maps.__getitem__))
        player = next(p for roster in self.details['rosters'].values() for p in roster.values() if p['player_id'] == '9805')
        observations = [dict(team_id=10, player_id=self.missing_player, display_name=player['player'], full_name=None)]
        self.observe = self.stack.enter_context(patch.object(ids, 'load_player_observations', return_value=observations))
        fixtures = [dict(fixture_id=1, home_team_id=10, away_team_id=20, starting_at='2025-03-30')]
        self.fixtures = self.stack.enter_context(patch.object(ids, 'load_mapping_fixtures', return_value=fixtures))
        self.stack.enter_context(patch.object(ids, 'write_understat_report', return_value='report.json'))
        self.stack.enter_context(patch.object(xg, 'write_understat_report', return_value='report.json'))
        self.id_write = self.stack.enter_context(patch.object(ids, 'transaction'))
        self.xg_write = self.stack.enter_context(patch.object(xg, 'replace_understat_rows'))

    def response(self, url, **kwargs):
        response = Mock()
        response.json.return_value = self.details if 'getMatchData' in url else self.source
        return response

    def test_combined_check_reuses_http_payload_and_new_planned_ids_without_db_writes(self):
        result = xg.refresh_understat('2024/2025', [564], check=True)
        self.assertEqual(result, dict(fixtures=1, players=31, shots=26, unavailable=0,
                                     mappings=dict(seasons=1, pending=0, unavailable=0)))
        self.assertEqual([c.args[0] for c in self.session.get.call_args_list], [
            'https://understat.com/', 'https://understat.com/getLeagueData/La_liga/2024',
            'https://understat.com/getMatchData/27270'])
        self.id_write.assert_not_called()
        self.xg_write.assert_not_called()
        self.session.close.assert_called_once()

    def test_combined_write_preserves_exact_rows_and_waits_for_mapping_commit(self):
        events = []
        self.id_write.return_value.__exit__.side_effect = lambda *args: events.append('ids_committed')
        self.xg_write.side_effect = lambda *args: events.append('xg_stored')
        xg.refresh_understat()
        self.assertEqual(events, ['ids_committed', 'xg_stored'])
        self.xg_write.assert_called_once_with([self.expected])
        self.assertEqual(self.session.get.call_count, 3)

    def test_pending_mapping_stops_before_xg_preparation(self):
        self.observe.return_value = []
        with patch.object(xg, 'collect_understat') as collect:
            with self.assertRaisesRegex(ValueError, 'unresolved mappings'):
                xg.refresh_understat(check=True)
        collect.assert_not_called()
        self.xg_write.assert_not_called()
        self.session.close.assert_called_once()

    def test_mapping_commit_failure_stops_before_xg(self):
        self.id_write.return_value.__exit__.side_effect = RuntimeError('commit failed')
        with self.assertRaisesRegex(RuntimeError, 'commit failed'):
            xg.refresh_understat()
        self.xg_write.assert_not_called()
        self.session.close.assert_called_once()

    def test_source_failure_stops_before_mapping_or_xg_storage(self):
        def fail_details(url, **kwargs):
            if 'getMatchData' in url:
                raise RuntimeError('network failed')
            return self.response(url, **kwargs)
        self.session.get.side_effect = fail_details
        with self.assertRaisesRegex(RuntimeError, 'network failed'):
            xg.refresh_understat()
        self.id_write.assert_not_called()
        self.xg_write.assert_not_called()
        self.session.close.assert_called_once()

    def test_known_corrupt_match_is_not_downloaded_or_stored_by_combined_command(self):
        self.source['dates'][0]['id'] = '31948'
        result = xg.refresh_understat(check=True)
        self.assertEqual(result['unavailable'], 1)
        self.assertEqual(result['fixtures'], 0)
        self.assertEqual(self.session.get.call_count, 2)
        self.id_write.assert_not_called()
        self.xg_write.assert_not_called()

    def test_a_new_run_downloads_again_and_uses_provider_corrections(self):
        xg.refresh_understat(check=True)
        self.source['dates'][0]['xG']['h'] = '3.0'
        xg.refresh_understat()
        self.assertEqual(self.session.get.call_count, 6)
        self.assertEqual(self.xg_write.call_args.args[0][0]['expected_goals'][1], 3)

    def test_later_season_resolves_mapping_before_any_xg_check(self):
        self.scope.append(dict(season_id=101, competition_id=564, name='2025/2026'))
        self.observe.side_effect = [[], self.observe.return_value]
        result = xg.refresh_understat(check=True)
        self.assertEqual(result['mappings']['pending'], 0)
        self.assertEqual(result['fixtures'], 2)
        # 원본 경기 ID가 같으면 시즌 조회만 추가돼요.
        self.assertEqual(self.session.get.call_count, 4)
        self.id_write.assert_not_called()
        self.xg_write.assert_not_called()


if __name__ == '__main__':
    unittest.main()
