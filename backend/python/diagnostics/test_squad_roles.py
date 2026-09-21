"""스쿼드 역할의 분모, 이적 범위, 유망주 경계와 읽기 전용 기본 실행을 검증해요."""
from copy import deepcopy
from datetime import date, datetime, timedelta
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import MagicMock, patch

import numpy as np

from one_touch_loader.core.squad_roles import (
    age_at, build_usage_rows, calculate_squad_roles, classify_usage, fit_usage_model,
)

with patch('mysql.connector.pooling.MySQLConnectionPool') as pool:
    pool.return_value.get_connection.side_effect = AssertionError('Operational DB access in tests')
    from one_touch_loader.loaders import squad_roles_loader as loader
    from diagnostics import refresh_squad_roles as command


def inputs():
    games = [dict(season_id=1, fixture_id=i+1, home_team_id=8, away_team_id=9,
                  starting_at=datetime(2026, 8, 1)+timedelta(days=i*7)) for i in range(2)]
    players = [dict(season_id=1, team_id=8, player_id=p, date_of_birth=date(1990, 1, 1), display_name=str(p))
               for p in range(1, 13)]
    lineups = [dict(**p, fixture_id=game['fixture_id'], lineup_type_id=11,
                    minutes_played=90, rating=7) for game in games for p in players[:11]]
    transfers = [dict(transfer_id=p, player_id=p, from_team_id=None, to_team_id=8, type_id=219,
                     from_team_name=None, from_team_image=None, to_team_name='Club', to_team_image=None,
                     transfer_date=date(2025, 1, 1)) for p in range(1, 13)]
    return dict(as_of=datetime(2026, 9, 20),
                seasons=[dict(season_id=1, competition_id=8, season_name='2026/2027', is_current=1)],
                fixtures=games, roster=players, lineups=lineups, transfers=transfers, substitutions=[],
                absences=[dict(fixture_id=g['fixture_id'], absences=[]) for g in games])


def row_for(data, player_id=1):
    return next(r for r in build_usage_rows(data) if r['player_id'] == player_id)


class UsageTests(unittest.TestCase):
    def test_injury_and_suspension_reduce_denominator_but_doubtful_does_not(self):
        for category, expected in [('injury', 1), ('suspended', 1), ('doubtful', .5)]:
            with self.subTest(category=category):
                data = inputs()
                first = data['lineups'][0]
                first['player_id'] = 12
                data['absences'][0]['absences'] = [dict(team_id=8, player_id=1, category=category)]
                row = row_for(data)
                self.assertEqual(row['minutes_played'], 90)
                self.assertEqual(row['usage_rate'], expected)

    def test_multiple_absences_do_not_subtract_the_same_game_twice(self):
        data = inputs()
        data['lineups'][0]['player_id'] = 12
        data['absences'][0]['absences'] = [dict(team_id=8, player_id=1, category=c) for c in ('injury', 'suspended')]
        self.assertEqual(row_for(data)['excluded_matches'], 1)

    def test_actual_matchday_selection_overrides_prematch_absence(self):
        data = inputs()
        data['absences'][0]['absences'] = [dict(team_id=8, player_id=1, category='injury')]
        row = row_for(data)
        self.assertEqual(row['usage_rate'], 1)
        self.assertEqual(row['lineup_absence_conflicts'], 1)

    def test_unused_bench_is_available_and_missing_played_minutes_are_not_zero(self):
        data = inputs()
        data['lineups'].append(dict(**data['roster'][11], fixture_id=1, lineup_type_id=12,
                                    minutes_played=None, rating=None))
        self.assertEqual(row_for(data, 12)['usage_rate'], 0)
        data['substitutions'] = [dict(fixture_id=1, team_id=8, player_id=1, related_player_id=12)]
        self.assertEqual(row_for(data, 12)['unavailable_reason'], 'minutes_unavailable')
        data['lineups'][0]['minutes_played'] = None
        self.assertEqual(row_for(data)['unavailable_reason'], 'minutes_unavailable')

    def test_missing_absences_or_incomplete_lineups_do_not_mean_zero_absences(self):
        data = inputs()
        data['absences'].pop()
        self.assertEqual(row_for(data)['unavailable_reason'], 'absence_data_unavailable')
        data = inputs()
        data['lineups'].pop()
        self.assertEqual(row_for(data)['unavailable_reason'], 'incomplete_lineups')

    def test_minutes_above_90_are_not_silently_clipped(self):
        data = inputs()
        data['lineups'][0]['minutes_played'] = 96
        self.assertEqual(row_for(data)['unavailable_reason'], 'invalid_minutes')

    def test_transfer_in_excludes_prior_club_games(self):
        data = inputs()
        data['transfers'][0]['transfer_date'] = date(2026, 8, 5)
        data['lineups'][0]['player_id'] = 12
        row = row_for(data)
        self.assertEqual(row['available_matches'], 1)
        self.assertEqual(row['usage_rate'], 1)

    def test_unknown_or_conflicting_membership_does_not_invent_a_join_date(self):
        data = inputs()
        data['transfers'][0]['transfer_date'] = date(2026, 8, 5)
        self.assertEqual(row_for(data)['unavailable_reason'], 'membership_dates_unavailable')
        data['transfers'].pop(0)
        self.assertEqual(row_for(data)['unavailable_reason'], 'membership_unavailable')

    def test_departed_players_stay_in_historical_population(self):
        data = inputs()
        data['roster'].pop(0)
        row = row_for(data)
        self.assertEqual(row['usage_rate'], 1)
        self.assertFalse(row['current_roster'])

    def test_all_unavailable_is_not_zero_usage(self):
        data = inputs()
        for fixture in data['absences']:
            fixture['absences'] = [dict(team_id=8, player_id=12, category='injury')]
        row = row_for(data, 12)
        self.assertIsNone(row['usage_rate'])
        self.assertEqual(row['unavailable_reason'], 'no_available_matches')

    def test_de_jong_injury_period_covers_four_missing_fixture_links(self):
        data = inputs()
        dates = [(8, 23), (8, 27), (8, 31), (9, 6), (9, 13), (9, 16), (9, 19)]
        data['fixtures'] = [dict(data['fixtures'][0], fixture_id=i+1, starting_at=datetime(2026, month, day))
                            for i, (month, day) in enumerate(dates)]
        data['lineups'] = [dict(row, fixture_id=game['fixture_id'])
                          for game in data['fixtures'] for row in data['lineups'][:11]]
        injury = dict(team_id=8, player_id=12, category='injury', sideline_id=805693,
                      start_date=date(2026, 6, 30))
        data['absences'] = [dict(fixture_id=i+1, absences=[injury] if i >= 4 else []) for i in range(7)]
        row = row_for(data, 12)
        self.assertEqual(row['available_matches'], 0)
        self.assertEqual(row['excluded_matches'], 7)
        self.assertEqual(row['injury_period_matches'], 4)
        self.assertIsNone(row['usage_rate'])
        self.assertEqual(row['unavailable_reason'], 'no_available_matches')

        # 부상 기간 안이어도 실제 벤치에 포함됐으면 그 경기는 출전 가능해요.
        data['lineups'].append(dict(**data['roster'][11], fixture_id=1, lineup_type_id=12,
                                    minutes_played=None, rating=None))
        row = row_for(data, 12)
        self.assertEqual(row['available_matches'], 1)
        self.assertEqual(row['excluded_matches'], 6)
        self.assertEqual(row['lineup_absence_conflicts'], 1)

    def test_injury_period_does_not_extend_past_last_confirmed_absence(self):
        data = inputs()
        data['absences'][0]['absences'] = [dict(team_id=8, player_id=12, category='injury',
                                               sideline_id=10, start_date=date(2026, 7, 1))]
        row = row_for(data, 12)
        self.assertEqual(row['available_matches'], 1)
        self.assertEqual(row['excluded_matches'], 1)

    def test_suspension_period_does_not_imply_other_fixture_absences(self):
        data = inputs()
        data['absences'][1]['absences'] = [dict(team_id=8, player_id=12, category='suspended',
                                               sideline_id=10, start_date=date(2026, 7, 1))]
        self.assertEqual(row_for(data, 12)['available_matches'], 1)

    def test_old_injury_end_is_not_extended_by_a_later_fixture_link(self):
        data = inputs()
        data['absences'][1]['absences'] = [dict(team_id=8, player_id=12, category='injury',
                                               sideline_id=10, start_date=date(2025, 7, 1),
                                               end_date=date(2025, 8, 1))]
        row = row_for(data, 12)
        self.assertEqual(row['available_matches'], 1)
        self.assertEqual(row['injury_period_matches'], 0)

    def test_future_injury_confirmation_does_not_fill_earlier_matches(self):
        data = inputs()
        data['fixtures'][1]['starting_at'] = data['as_of']+timedelta(days=1)
        data['absences'][1]['absences'] = [dict(team_id=8, player_id=12, category='injury',
                                               sideline_id=10, start_date=date(2026, 7, 1))]
        self.assertEqual(row_for(data, 12)['available_matches'], 1)

    def test_future_games_and_other_team_absences_do_not_change_usage(self):
        data = inputs()
        data['absences'][0]['absences'] = [dict(team_id=9, player_id=1, category='injury')]
        data['fixtures'][1]['starting_at'] = data['as_of']+timedelta(days=1)
        original = deepcopy(data)
        row = row_for(data)
        self.assertEqual(row['available_matches'], 1)
        self.assertEqual(row['usage_rate'], 1)
        self.assertEqual(data, original)


class ModelTests(unittest.TestCase):
    def setUp(self):
        self.rows = [dict(usage_rate=float(x)) for mean in (.08, .32, .59, .88)
                     for x in np.linspace(mean-.035, mean+.035, 40)]
        self.model = fit_usage_model(self.rows)

    def test_data_fits_repeatable_ordered_probabilities(self):
        self.assertEqual(self.model, fit_usage_model(list(reversed(self.rows))))
        roles = []
        for usage in np.linspace(0, 1, 1001):
            result = classify_usage(dict(usage_rate=float(usage), age=30), self.model)
            roles.append(('sporadic', 'rotation', 'important', 'crucial').index(result['role']))
            self.assertAlmostEqual(sum(result['probabilities'].values()), 1)
        self.assertEqual(roles, sorted(roles))
        self.assertEqual(set(roles), {0, 1, 2, 3})

    def test_prospect_requires_both_low_usage_and_age_at_most_21(self):
        for age, usage, expected in [(21, 0, 'prospect'), (22, 0, 'sporadic'), (17, 1, 'crucial')]:
            self.assertEqual(classify_usage(dict(usage_rate=usage, age=age), self.model)['role'], expected)
        self.assertIsNone(classify_usage(dict(usage_rate=0, age=None), self.model)['role'])
        self.assertIsNone(classify_usage(dict(usage_rate=None, age=19), self.model)['role'])

    def test_age_uses_calculation_date_and_changes_role_on_22nd_birthday(self):
        data = inputs()
        data['roster'][11]['date_of_birth'] = date(2004, 9, 20)
        data['as_of'] = datetime(2026, 9, 19)
        self.assertEqual(classify_usage(row_for(data, 12), self.model)['role'], 'prospect')
        data['as_of'] = datetime(2026, 9, 20)
        self.assertEqual(classify_usage(row_for(data, 12), self.model)['role'], 'sporadic')
        data['roster'][11]['date_of_birth'] = date(2004, 8, 5)
        self.assertEqual(row_for(data, 12)['age'], 22)
        self.assertEqual(classify_usage(row_for(data, 12), self.model)['role'], 'sporadic')
        self.assertEqual(age_at(date(2004, 9, 21), date(2026, 9, 20)), 21)

    def test_current_season_never_changes_the_historical_training_model(self):
        seasons = [f'{year}/{year+1}' for year in range(2021, 2026)]
        rows = [dict(r, season_name=season, current_roster=False, unavailable_reason=None)
                for season in seasons for r in self.rows]
        current = dict(usage_rate=.1, season_name='2026/2027', current_roster=True,
                       age=20, unavailable_reason=None)
        data = dict(as_of=datetime(2026, 9, 20), training_seasons=seasons, current_season='2026/2027')
        with patch('one_touch_loader.core.squad_roles.build_usage_rows', return_value=rows+[current]):
            first = calculate_squad_roles(data)
            current['usage_rate'] = 1
            second = calculate_squad_roles(data)
        self.assertEqual(first['model'], second['model'])
        self.assertEqual(first['players'][0]['role'], 'prospect')
        self.assertEqual(second['players'][0]['role'], 'crucial')


class CollectionTests(unittest.TestCase):
    def test_absence_batch_uses_shared_id_validation_without_detail_normalization(self):
        client = loader.SportmonksClient.__new__(loader.SportmonksClient)
        client._get = MagicMock(return_value={'data': [dict(id=2, sidelined=[]), dict(id=1, sidelined=[])]})
        self.assertEqual([f['id'] for f in client.get_fixtures_batch([1, 2], include='sidelined.sideline')], [1, 2])
        client._get.assert_called_once_with('fixtures/multi/1,2', params={'include': 'sidelined.sideline'})
        client._get.return_value['data'].pop()
        with self.assertRaises(ValueError):
            client.get_fixtures_batch([1, 2], include='sidelined.sideline')

    def test_fixture_absence_identity_and_category_are_preserved(self):
        client = MagicMock()
        client.get_fixtures_batch.return_value = [dict(id=1, sidelined=[dict(
            fixture_id=1, participant_id=8, player_id=None, sideline_id=10,
            sideline=dict(id=10, team_id=8, player_id=1, category='suspended',
                          start_date='2026-07-31', end_date='2026-08-01'))])]
        result = loader.collect_fixture_absences(inputs()['fixtures'][:1], client=client)
        self.assertEqual(result, [dict(fixture_id=1, absences=[dict(team_id=8, player_id=1, category='suspended',
                                                                  sideline_id=10, start_date=date(2026, 7, 31),
                                                                  end_date=date(2026, 8, 1))])])
        client.get_fixtures_batch.return_value[0]['sidelined'][0]['participant_id'] = 99
        with self.assertRaises(ValueError):
            loader.collect_fixture_absences(inputs()['fixtures'][:1], client=client)

    def test_injury_team_does_not_replace_fixture_participant_after_transfer(self):
        client = MagicMock()
        client.get_fixtures_batch.return_value = [dict(id=1, sidelined=[dict(
            fixture_id=1, participant_id=8, player_id=1, sideline_id=10,
            sideline=dict(id=10, team_id=77, player_id=1, category='injury'))])]
        result = loader.collect_fixture_absences(inputs()['fixtures'][:1], client=client)
        self.assertEqual(result[0]['absences'][0]['team_id'], 8)

    def test_apply_updates_only_matching_current_squad_roles_in_one_transaction(self):
        with patch.object(loader, 'transaction') as transaction:
            cur = transaction.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value
            rows = [dict(role=None, team_id=8, season_id=1, player_id=12),
                    dict(role='prospect', team_id=8, season_id=1, player_id=1)]
            loader.save_current_squad_roles(rows)
            sql, params = cur.executemany.call_args.args
            self.assertIn('SET sm.squad_role=%s', sql)
            self.assertIn('s.is_current=1', sql)
            self.assertEqual(params, [(None, 8, 1, 12), ('prospect', 8, 1, 1)])
            transaction.assert_called_once()

    def test_default_command_never_writes_operational_data(self):
        report = dict(as_of='2026-09-20', role_counts={}, current_unavailable={}, players=[])
        with TemporaryDirectory() as folder, patch.object(command, 'preview_squad_roles', return_value=report), \
                patch.object(command, 'save_current_squad_roles') as save, \
                patch('sys.argv', ['refresh_squad_roles', '--report', str(Path(folder)/'report.json')]):
            command.main()
            save.assert_not_called()


if __name__ == '__main__':
    unittest.main()
