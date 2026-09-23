from datetime import datetime, timezone
import unittest
from unittest.mock import patch

import numpy as np

from one_touch_loader.core.betting import SETTLEMENT_RULE, match_outcome, prediction_options
from one_touch_loader.core.cup_betting import MODEL_METHOD, aggregate_index, match_format
from one_touch_loader.core.probability import fit_wdl
from one_touch_loader.loaders import cup_betting_loader as loader
from one_touch_loader.loaders import probability_loader


NOW = datetime(2026, 9, 21, 12, tzinfo=timezone.utc)


def fixture(**updates):
    return {'fixture_id': 1, 'home_team_id': 10, 'away_team_id': 20, 'competition_id': 2,
            'season_id': 100, 'season_name': '2026/2027', 'stage_type_id': 224, 'stage_name': 'Final',
            'leg': '1/1', 'aggregate_id': None, 'starting_at': '2026-09-22 12:00:00',
            'state_id': 1, 'home_score': None, 'away_score': None,
            'home_penalty_score': None, 'away_penalty_score': None, **updates}


class CupBettingTests(unittest.TestCase):
    def test_group_stage_first_leg_and_single_match_formats(self):
        for f, expected in ((fixture(stage_type_id=223, stage_name='League Stage'), True),
                            (fixture(stage_name='Round of 16', leg='1/2'), True), (fixture(), False),
                            (fixture(competition_id=27, stage_name='3rd Round'), False)):
            self.assertEqual(match_format(f, {}, as_of=NOW)['draw_allowed'], expected)
        self.assertIsNone(match_format(fixture(stage_name='Qualification Round 3'), {}, as_of=NOW))
        self.assertIsNone(match_format(fixture(competition_id=390, stage_name='Semi-finals'), {}, as_of=NOW))

    def test_second_leg_depends_on_completed_first_leg_not_aggregate_winner(self):
        second = fixture(stage_name='Round of 16', leg='2/2', aggregate_id=7)
        first = fixture(fixture_id=2, home_team_id=20, away_team_id=10, leg='1/2', aggregate_id=7,
                        starting_at='2026-09-14 12:00:00', state_id=5, home_score=1, away_score=0)
        self.assertIsNone(match_format(second, {}, as_of=NOW))
        for score, expected in ((0, True), (1, False)):
            first['away_score'] = score
            context = match_format(second, aggregate_index([first]), as_of=NOW)
            self.assertEqual(context['draw_allowed'], expected)
        for change in ({'state_id': 1}, {'away_score': None}, {'starting_at': '2026-09-22 13:00:00'},
                       {'home_team_id': 30}):
            self.assertIsNone(match_format(second, aggregate_index([{**first, **change}]), as_of=NOW))

    def test_fa_replays_are_season_specific(self):
        old = fixture(competition_id=24, stage_name='3rd Round', season_name='2023/2024')
        self.assertTrue(match_format(old, {}, as_of=NOW)['draw_allowed'])
        self.assertFalse(match_format({**old, 'season_name': '2024/2025'}, {}, as_of=NOW)['draw_allowed'])
        self.assertFalse(match_format({**old, 'stage_name': '3rd Round Replays'}, {}, as_of=NOW)['draw_allowed'])

    def test_masked_training_has_no_impossible_draw_and_keeps_probabilities_normalized(self):
        differences = [-200, 0, 200, -100, 50, 100, -150, 0, 150]
        outcomes = [2, 1, 0, 2, 0, 0, 0, 2, 2]
        allowed = [True] * 3 + [False] * 6
        model = fit_wdl(differences, outcomes, draw_allowed=allowed)
        probabilities = model.predict(differences, draw_allowed=allowed)
        np.testing.assert_allclose(probabilities.sum(axis=1), 1)
        np.testing.assert_array_equal(probabilities[3:, 1], 0)
        self.assertEqual([o['outcome'] for o in prediction_options(model.coefficients, 1800, 1700,
                                                                 draw_allowed=False)], ['home_win', 'away_win'])
        with self.assertRaisesRegex(ValueError, 'decisive'):
            fit_wdl(differences, outcomes, draw_allowed=False)

    def test_training_uses_final_result_and_strictly_pre_match_elo(self):
        histories = {10: [{'date': '2025-01-01', 'elo': 1800}, {'date': '2025-01-02', 'elo': 9999}],
                     20: [{'date': '2025-01-01', 'elo': 1700}]}
        f = fixture(season_name='2024/2025', starting_at='2025-01-02 12:00:00', state_id=8,
                    home_score=1, away_score=1, home_penalty_score=3, away_penalty_score=4)
        data = loader.build_dataset([f], histories)
        self.assertEqual(data['rows'][0]['outcome'], 2)
        self.assertEqual(data['rows'][0]['elo_difference'], 100)
        incomplete = loader.build_dataset([{**f, 'away_penalty_score': None}], histories)
        self.assertEqual(incomplete['excluded'][0]['reason'], 'final_result_incomplete')
        self.assertEqual(loader.build_dataset([f], {})['excluded'][0]['reason'], 'missing_pre_match_elo')

    def test_real_two_leg_shootout_example_uses_match_score(self):
        # Sportmonks 18844237: 해당 경기는 원정 3–2 승, 승부차기는 홈 4–3 승이에요.
        f = fixture(fixture_id=18844237, state_id=8, leg='2/2', home_score=2, away_score=3,
                    home_penalty_score=4, away_penalty_score=3)
        self.assertEqual(match_outcome(f), 'away_win')

    def test_snapshot_has_fixture_identity_and_no_future_elo_or_closed_match(self):
        report = {'model_id': 'b' * 64, 'method': MODEL_METHOD, 'settlement_rule': SETTLEMENT_RULE,
                  'forecast_model': {'coefficients': [.5, 1.3, .2, -1.2],
                                     'last_training_fixture_at': '2026-05-30 12:00:00'}}
        histories = {10: [{'date': '2026-09-20', 'elo': 1800}, {'date': '2026-09-22', 'elo': 9999}],
                     20: [{'date': '2026-09-20', 'elo': 1700}]}
        runs, excluded = loader.prepare_runs([fixture(), fixture(fixture_id=2, state_id=2),
                                             fixture(fixture_id=3, away_team_id=30)], histories, report, observed_at=NOW)
        self.assertEqual(list(runs[0]['fixture_markets']), ['1'])
        self.assertEqual(runs[0]['fixture_markets']['1']['home_elo'], 1800)
        self.assertEqual(excluded, [{'fixture_id': 3, 'reason': 'missing_pre_match_elo'}])
        self.assertEqual(runs[0]['teams'], {})

    def test_league_latest_model_does_not_select_cup_model(self):
        with patch.object(probability_loader, '_fetch', side_effect=[
                [{'model_id': 'a', 'created_at': NOW}], [{'payload': '{"method":"league"}'}]]) as fetch:
            self.assertEqual(probability_loader.latest_model()['method'], 'league')
            self.assertEqual(fetch.call_args_list[0].args[1], ('multinomial_logistic_elo_difference_v1',))

    def test_refresh_check_does_not_write(self):
        with patch.object(loader, 'latest_model', return_value={}), patch.object(loader, 'read_fixtures', return_value=[]), \
                patch.object(loader, 'read_clubelo_mapping', return_value={}), patch.object(loader, 'refresh_histories', return_value={}) as histories, \
                patch.object(loader, 'prepare_runs', return_value=([{'fixture_markets': {'1': {}}}], [])), \
                patch.object(loader, 'store_runs') as store:
            self.assertFalse(loader.refresh()['applied'])
            store.assert_not_called()
            histories.assert_called_once_with({}, apply=False)


if __name__ == '__main__':
    unittest.main()
