"""새 프로세스에서도 선택하지 않은 수집·학습 모듈을 불러오지 않는지 확인해요."""
import json
import os
from pathlib import Path
import subprocess
import sys
import textwrap
import unittest


PYTHON_ROOT = Path(__file__).resolve().parents[1]
PRELUDE = """
import importlib.abc
import sys
from types import ModuleType

def stub(name, **attributes):
    module = ModuleType(name)
    module.__dict__.update(attributes)
    sys.modules[name] = module
    return module

class RejectUnselectedLoaders(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        if (fullname.startswith('one_touch_loader.loaders.')
                and fullname not in {'one_touch_loader.loaders.match_refresh',
                                     'one_touch_loader.loaders.betting_loader',
                                     'one_touch_loader.loaders.player_indicators_loader',
                                     'one_touch_loader.loaders.squad_roles_loader'}):
            raise AssertionError('Unexpected loader import: ' + fullname)
        if fullname.split('.')[0] in {'numpy', 'pandas', 'scipy', 'sklearn', 'selenium', 'mysql'}:
            raise AssertionError('Unexpected dependency import: ' + fullname)

sys.meta_path.insert(0, RejectUnselectedLoaders())
"""


class BatchImportTests(unittest.TestCase):
    def run_isolated(self, source):
        # 다른 테스트가 먼저 로드한 모듈 때문에 불필요한 import를 놓치지 않아요.
        result = subprocess.run(
            [sys.executable, '-B', '-c', PRELUDE + textwrap.dedent(source)],
            cwd=PYTHON_ROOT,
            env={**os.environ, 'PYTHONPATH': str(PYTHON_ROOT)},
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_betting_rules_do_not_load_prediction_modules(self):
        self.run_isolated("""
            from datetime import datetime, timedelta
            from decimal import Decimal
            from one_touch_loader.core import betting

            assert {5, 7, 8} <= set(betting.SETTLEMENT_STATE_IDS)
            fixture = {'state_id': 5, 'state_code': 'FT', 'home_score': 2, 'away_score': 1,
                       'starting_at': datetime(2026, 10, 9, 12)}
            bet = {'outcome': 'home_win', 'stake': 100, 'potential_return': 300}
            assert betting.settlement(fixture, bet)['payout'] == 300
            assert betting.total_return(100, Decimal('0.3')) == 333
            assert betting.betting_opens_at(fixture) == fixture['starting_at'] - timedelta(hours=24)
            assert 'one_touch_loader.core.probability' not in sys.modules
        """)

    def test_empty_betting_cli_does_not_load_repository_or_models(self):
        self.run_isolated("""
            import io
            import json
            from contextlib import redirect_stdout
            from unittest.mock import Mock

            fetch = Mock(return_value=[])
            stub('one_touch_loader.api.db', fetch_all_dict=fetch)
            class RejectRepository(importlib.abc.MetaPathFinder):
                def find_spec(self, fullname, path=None, target=None):
                    if fullname == 'one_touch_loader.api.repos.betting_repo':
                        raise AssertionError('Empty run imported the settlement repository')
            sys.meta_path.insert(0, RejectRepository())
            from one_touch_loader.loaders import betting_loader
            for arguments, applied in (([], False), (['--apply'], True)):
                with redirect_stdout(io.StringIO()) as output:
                    betting_loader.run_cli(arguments)
                assert json.loads(output.getvalue()) == {'applied': applied, 'settlements': []}
            assert fetch.call_count == 2
            assert 'one_touch_loader.api.repos.betting_repo' not in sys.modules
            assert 'one_touch_loader.core.probability' not in sys.modules
        """)

    def test_nonempty_betting_cli_keeps_order_results_and_apply_mode(self):
        self.run_isolated("""
            import io
            import json
            from contextlib import redirect_stdout
            from unittest.mock import Mock, call

            stub('one_touch_loader.api.db', fetch_all_dict=Mock(return_value=[
                {'bet_id': 10}, {'bet_id': 20}, {'bet_id': 30}]))
            settle = Mock()
            stub('one_touch_loader.api.repos.betting_repo', settle_bet=settle)
            from one_touch_loader.loaders import betting_loader
            results = [{'bet_id': 10, 'status': 'won', 'payout': 300}, None,
                       {'bet_id': 30, 'status': 'refunded', 'payout': 100}]
            for arguments, applied in (([], False), (['--apply'], True)):
                settle.reset_mock()
                settle.side_effect = list(results)
                with redirect_stdout(io.StringIO()) as output:
                    betting_loader.run_cli(arguments)
                assert settle.call_args_list == [call(key, apply=applied) for key in (10, 20, 30)]
                assert json.loads(output.getvalue()) == {
                    'applied': applied, 'settlements': [results[0], results[2]]}
        """)

    def test_usage_and_argument_helpers_do_not_load_database_or_collectors(self):
        self.run_isolated("""
            from one_touch_loader import cli
            assert cli._parse_competition_ids(['8', '82', '8']) == [8, 82]
            for arguments in ([], ['unknown-command'], ['team-attributes']):
                sys.argv = ['cli', *arguments]
                cli.main()
        """)

    def test_selected_commands_keep_arguments_without_loading_other_collectors(self):
        cases = [
            (['fixtures', 'live'], 'live_fixtures_loader', 'refresh_live_fixtures', [], {'apply': False}, {}),
            (['fixtures', 'live', '--apply'], 'live_fixtures_loader', 'refresh_live_fixtures', [], {'apply': True}, {}),
            (['fixtures', 'all'], 'fixtures_loader', 'collect_all_fixtures', [], {},
             {'collection_runs': 1, 'stored_fixtures': 2}),
            (['fixtures', '2026/2027', '8', '8'], 'fixtures_loader', 'collect_fixtures_for_competition_season',
             ['2026/2027', 8], {}, {'stored_fixture_count': 2}),
            (['news'], 'news_loader', 'run_cli', [['refresh']], {}, None),
            (['highlights', 'refresh', '8', '--check'], 'highlights_loader', 'run_cli',
             [['refresh', '8', '--check']], {}, None),
            (['community', 'cleanup', '--check'], 'community_maintenance', 'main', [['--check']], {}, None),
            (['probability', 'refresh', '--check'], 'probability_loader', 'main', [['refresh', '--check']], {}, None),
            (['opta-shots', 'sync', '--check'], 'opta_shots_loader', 'main', [['sync', '--check']], {}, None),
            (['team-attributes', 'train-regression'], 'team_attribute_regression_trainer',
             'train_team_attribute_regression_weights', [], {}, 1),
            (['team-attributes', 'build-current-scores'], 'team_attribute_scores_loader',
             'build_current_team_attribute_group_scores', [], {}, 1),
        ]
        for arguments, module, function, args, kwargs, result in cases:
            with self.subTest(command=arguments):
                self.run_isolated(f"""
                    import json
                    from unittest.mock import Mock
                    call = Mock(return_value=json.loads({json.dumps(result)!r}))
                    stub('one_touch_loader.loaders.{module}', **{{'{function}': call}})
                    from one_touch_loader import cli
                    sys.argv = ['cli', *{arguments!r}]
                    cli.main()
                    call.assert_called_once_with(*{args!r}, **{kwargs!r})
                """)

    def test_understat_commands_share_scope_parsing_but_load_only_selected_collector(self):
        for command, module, function in (
            ('understat-ids', 'understat_ids_loader', 'collect_understat_ids'),
            ('understat', 'understat_loader', 'collect_understat'),
            ('understat-refresh', 'understat_loader', 'refresh_understat'),
            ('xg-standings', 'xg_standings_loader', 'build_xg_standings'),
        ):
            with self.subTest(command=command):
                self.run_isolated(f"""
                    from unittest.mock import Mock
                    call = Mock(return_value={{}})
                    stub('one_touch_loader.loaders.{module}', **{{'{function}': call}})
                    from one_touch_loader import cli
                    sys.argv = ['cli', '{command}', 'all', '8', '8', '--check']
                    cli.main()
                    call.assert_called_once_with(None, [8], check=True)
                """)

    def test_unchanged_match_jobs_do_not_load_provider_or_calculation_modules(self):
        self.run_isolated("""
            import json
            from datetime import datetime, timezone
            from pathlib import Path
            from tempfile import TemporaryDirectory

            rows = [dict(fixture_id=1, home_team_id=10, away_team_id=20,
                         starting_at='2026-09-22 18:00:00', state_id=5,
                         home_score=1, away_score=0, season_id=100, competition_id=8,
                         season_name='2026/2027', has_xg=True, has_opta=True)]
            stub('one_touch_loader.api.db', fetch_all_dict=lambda sql: rows)
            stub('one_touch_loader.core.opta_schedule', COMPETITIONS={8: ()})
            stub('one_touch_loader.core.understat', UNDERSTAT_LEAGUES={8: 'EPL'})
            from one_touch_loader.loaders import match_refresh as jobs

            now = datetime(2026, 9, 22, 21, tzinfo=timezone.utc)
            state = {
                '1': {'signature': jobs.fingerprint(jobs.fixture_result(rows[0])), 'status': 'complete'},
                'probability': {'signature': jobs.fingerprint([jobs.fixture_result(rows[0])]),
                                'attempted_at': now.timestamp()},
            }
            with TemporaryDirectory() as folder:
                path = Path(folder) / 'state.json'
                path.write_text(json.dumps(state))
                for task in ('opta', 'understat', 'probability'):
                    result = jobs.refresh(task, state_path=path, apply=False, now=now)
                    assert result['attempted'] == 0, result
                    assert result['failures'] == [], result
                assert json.loads(path.read_text()) == state
        """)

    def test_squad_role_helpers_defer_model_until_calculation(self):
        self.run_isolated("""
            from datetime import datetime
            from unittest.mock import Mock

            stub('one_touch_loader.core.db', get_conn=Mock(), transaction=Mock())
            stub('one_touch_loader.core.sportmonks', SportmonksClient=Mock())
            stub('one_touch_loader.loaders.team_squad_members_loader',
                 BIG5_COMPETITION_IDS=[8], SPORTMONKS_DUPLICATE_PLAYER_IDS={})
            from one_touch_loader.loaders import squad_roles_loader as roles

            connection = Mock()
            with roles.refresh_squad_roles_after_fixture(connection, 1, records_changed=False):
                pass
            connection.cursor.assert_not_called()
            assert 'one_touch_loader.core.squad_roles' not in sys.modules

            calculate = Mock(return_value={'players': []})
            stub('one_touch_loader.core.squad_roles', calculate_squad_roles=calculate)
            roles.read_squad_role_inputs = Mock(return_value={'fixtures': []})
            roles.collect_fixture_absences = Mock(return_value=[])
            roles.CALIBRATION_PATH = Mock()
            roles.CALIBRATION_PATH.read_text.return_value = '{"version": 1}'
            now = datetime(2026, 9, 22, 21)
            assert roles.preview_squad_roles(connection=connection, team_ids=[10], as_of=now) == {'players': []}
            roles.read_squad_role_inputs.assert_called_once_with(
                now, connection=connection, current_only=True, team_ids=[10])
            calculate.assert_called_once_with({'fixtures': [], 'absences': []}, model={'version': 1})
        """)

    def test_unchanged_player_indicators_and_empty_snapshot_do_not_load_model(self):
        self.run_isolated("""
            from datetime import datetime
            from unittest.mock import Mock

            stub('one_touch_loader.core.db', get_conn=Mock())
            from one_touch_loader.loaders import player_indicators_loader as loader

            inputs = ([{'player_id': 1}], [], [], None)
            now = datetime(2026, 10, 8)
            previous = dict(input_sha256=loader.input_fingerprint(inputs),
                            player_count=1, as_of=now, calculated_at=now)
            loader.read_current_inputs = Mock(return_value=inputs)
            for apply in (False, True):
                cursor = Mock()
                cursor.fetchone.return_value = previous
                report = loader._refresh(cursor, apply=apply)
                assert report['status'] == 'unchanged', report
                assert report['as_of'] == report['calculated_at'] == now
                assert report['calculation_seconds'] == report['write_seconds'] == 0
                cursor.executemany.assert_not_called()
            assert loader.build_snapshot(now, ([], [], [], None)) == {}
            assert 'one_touch_loader.core.player_indicators' not in sys.modules
        """)


if __name__ == '__main__':
    unittest.main()
