import copy
from datetime import datetime, timezone
import json
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

import numpy as np

from one_touch_loader.core.tournament_bracket import build_bracket
from one_touch_loader.core.european_probability import ScoreModel, simulate_bracket_title, tie_winners
from one_touch_loader.core.fixture_scores import score_pair, CURRENT_SCORE_TYPE_ID
from one_touch_loader.loaders import tournament_bracket_loader as loader


def fixture(fid, home, away, stage='Final', *, competition=2, leg='1/1', score=None,
            penalties=None, state=None, aggregate=None):
    stages = {'8th Finals': 1, 'Quarter-finals': 2, 'Semi-finals': 3, 'Final': 4}
    slots = []
    for side, team in (('home', home), ('away', away)):
        slots.append({'id': team or 260131, 'name': f'Team {team}' if team else 'TBC',
            'placeholder': team is None, 'short_code': None, 'image_path': None, 'meta': {'location': side}})
    scores = []
    for kind, values in ((1525, score), (5, penalties)):
        if values:
            scores += [{'type_id': kind, 'participant_id': team, 'score': {'goals': goals}}
                       for team, goals in zip((home, away), values)]
    return {'id': fid, 'league_id': competition, 'season_id': 100, 'stage_id': stages[stage],
        'stage': {'id': stages[stage], 'name': stage, 'type_id': 224, 'sort_order': stages[stage]},
        'participants': slots, 'scores': scores, 'leg': leg, 'aggregate_id': aggregate,
        'aggregate': {'winner_participant_id': None} if aggregate else None,
        'state_id': state if state is not None else 5 if score else 1,
        'state': {'developer_name': 'FT' if score else 'NS'}, 'starting_at': '2027-04-01 20:00:00'}


def build(fixtures, **kwargs):
    return build_bracket(competition_id=fixtures[0]['league_id'] if fixtures else 2,
                         season_id=100, season_name='2026/2027', fixtures=fixtures,
                         fetched_at='2027-04-02T00:00:00Z', **kwargs)


def actual(season_id):
    rows = json.loads((Path(__file__).parent / 'fixtures/tournament_bracket_cases.json').read_text(encoding='utf-8'))
    return next(r['fixtures'] for r in rows if r['season_id'] == season_id)


def actual_bracket(season_id):
    rows = actual(season_id)
    return build_bracket(competition_id=rows[0]['league_id'], season_id=season_id,
        season_name='2026/2027' if season_id == 28279 else '2025/2026', fixtures=rows,
        fetched_at='2026-09-22T00:00:00Z')


class TournamentBracketTests(unittest.TestCase):
    def test_results_reconstruct_aggregate_winner_not_second_leg_bet_winner(self):
        rows = [fixture(1, 1, 2, 'Semi-finals', leg='1/2', score=(1, 0)),
                fixture(2, 2, 1, 'Semi-finals', leg='2/2', score=(1, 0), penalties=(3, 4), state=8),
                fixture(3, 3, 4, 'Semi-finals', leg='1/2', score=(2, 0)),
                fixture(4, 4, 3, 'Semi-finals', leg='2/2', score=(0, 0)),
                fixture(5, 1, 3)]
        b = build(rows)
        self.assertEqual(b['path_status'], 'complete')
        self.assertEqual(len(b['edges']), 2)
        first = b['stages'][0]['ties'][0]
        self.assertEqual(first['winner_team_id'], 1)
        self.assertEqual(first['aggregate_score'], [1, 1])
        self.assertEqual(first['winner_basis'], 'penalties')
        self.assertEqual(b['stages'][1]['ties'][0]['slots'][0]['source_tie_id'], first['tie_id'])

    def test_next_round_can_supply_missing_winner_without_inventing_scores(self):
        rows = [fixture(1, 1, 2, 'Semi-finals', competition=24, state=5), fixture(2, 1, 3, competition=24)]
        b = build(rows)
        first = b['stages'][0]['ties'][0]
        self.assertEqual(first['winner_team_id'], 1)
        self.assertEqual(first['winner_basis'], 'next_round_entry')
        self.assertIsNone(first['fixtures'][0]['home_score'])

    def test_future_pairings_are_not_inferred_from_ids_dates_or_sort_order(self):
        b = build([fixture(1, 1, 2, 'Semi-finals', competition=24),
                   fixture(2, 3, 4, 'Semi-finals', competition=24), fixture(3, None, None, competition=24)])
        self.assertEqual(b['edges'], [])
        self.assertEqual(b['path_status'], 'partial')
        self.assertNotIn('260131', b['teams'])
        self.assertTrue(all(s['team_id'] is None for s in b['stages'][-1]['ties'][0]['slots']))

    def test_known_provider_edges_keep_second_leg_slot_orientation(self):
        rows = [fixture(1, 1, 2, 'Quarter-finals', leg='1/2'), fixture(2, 2, 1, 'Quarter-finals', leg='2/2'),
                fixture(3, None, None, 'Semi-finals', leg='1/2', aggregate=99),
                fixture(4, None, None, 'Semi-finals', leg='2/2', aggregate=99)]
        # 동일한 TBC는 aggregate로만 묶을 수 있어요.
        self.assertEqual(len(build(rows)['stages'][1]['ties']), 1)
        rows[2]['participants'][0]['name'] = rows[3]['participants'][1]['name'] = 'Winner Quarter-final 1'
        rows[2]['participants'][1]['name'] = rows[3]['participants'][0]['name'] = 'Winner Quarter-final 2'
        b = build(rows, provider_edges=[{'parent_fixture_id': 2, 'parent_outcome': 'winner',
                                        'child_fixture_id': 4, 'child_slot': 'home'}])
        self.assertEqual(b['edges'][0]['to_slot'], 'away')
        with self.assertRaisesRegex(ValueError, 'Conflicting bracket progression'):
            build(rows, provider_edges=[{'parent_fixture_id': 2, 'parent_outcome': 'winner',
                'child_fixture_id': 4, 'child_slot': side} for side in ('home', 'away')])

    def test_copa_missing_aggregate_and_mislabelled_preliminary_legs(self):
        b = actual_bracket(26557)
        prelim = next(s for s in b['stages'] if s['key'] == 'preliminary')
        self.assertEqual(len(prelim['ties']), 2)
        for tie in prelim['ties']:
            self.assertEqual([f['leg'] for f in tie['fixtures']], ['1/2', '2/2'])
            self.assertTrue(all(f['source_leg'] == '1/1' for f in tie['fixtures']))
            self.assertIsNotNone(tie['next_tie_id'])
        semi = next(s for s in b['stages'] if s['key'] == 'semifinal')
        self.assertEqual(len(semi['ties']), 2)
        self.assertTrue(all(t['next_tie_id'] for t in semi['ties']))
        self.assertTrue(all(f['aggregate_id'] is None for t in semi['ties'] for f in t['fixtures']))

    def test_official_coppa_score_correction_is_shared_and_non_mutating(self):
        rows = actual(25642)
        original = copy.deepcopy(rows[0])
        self.assertEqual(score_pair(rows[0], 133057, 6911, CURRENT_SCORE_TYPE_ID), (1, 0))
        self.assertEqual(rows[0], original)
        b = actual_bracket(25642)
        self.assertEqual(b['stages'][0]['ties'][0]['winner_team_id'], 133057)
        self.assertEqual(len(b['edges']), 1)

    def test_coppa_stage_order_and_placeholder_semifinals(self):
        b = actual_bracket(28279)
        self.assertEqual([s['key'] for s in b['stages']], ['quarterfinal', 'semifinal', 'final'])
        self.assertEqual(len(b['stages'][1]['ties']), 2)
        self.assertTrue(all(t['legs_complete'] for t in b['stages'][1]['ties']))
        self.assertEqual(b['teams'], {})
        self.assertEqual(b['edges'], [])

    def test_duplicate_and_conflicting_paths_are_rejected(self):
        f = fixture(1, 1, 2)
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            build([f, f])
        rows = [fixture(1, 1, 2, 'Semi-finals', competition=24, score=(1, 0)),
                fixture(2, 1, 3, competition=24), fixture(3, 1, 4, competition=24)]
        with self.assertRaisesRegex(ValueError, 'multiple'):
            build(rows)

    def test_qualifying_replay_does_not_become_fa_main_bracket(self):
        f = fixture(1, 1, 2, competition=24)
        f['stage']['name'] = '2nd Round Qualifying Replays'
        b = build([f])
        self.assertEqual(b['status'], 'not_published')
        self.assertEqual(b['stages'], [])

    def test_hash_ignores_fetch_time_and_detail_loading_but_tracks_score(self):
        rows = [fixture(1, 1, 2)]
        first = build(rows)
        self.assertEqual(first['input_sha256'], build(rows, available_fixture_ids=[1])['input_sha256'])
        rows[0]['scores'] = [{'type_id': 1525, 'participant_id': 1, 'score': {'goals': 1}},
                             {'type_id': 1525, 'participant_id': 2, 'score': {'goals': 0}}]
        self.assertNotEqual(first['input_sha256'], build(rows)['input_sha256'])


class BracketForecastTests(unittest.TestCase):
    def estimate(self, bracket, **kwargs):
        teams = sorted(int(t) for t in bracket['teams'])
        return simulate_bracket_title(bracket=bracket, team_ids=teams, elos=dict.fromkeys(teams, 1700),
            model=ScoreModel((.3, .2, .8)), penalty_coefficient=0, simulations=2000, seed=19, **kwargs)

    def test_completed_real_ucl_preserves_champion_and_eliminations(self):
        bracket = actual_bracket(25580)
        result = self.estimate(bracket)
        self.assertEqual(result[bracket['champion_team_id']]['probability'], 1)
        self.assertEqual(sum(t['wins'] for t in result.values()), 2000)
        self.assertEqual(sum(t['probability'] for t in result.values()), 1)

    def test_played_first_leg_is_not_resimulated(self):
        rng = Mock()
        rng.poisson.side_effect = [np.array([1]), np.array([1])]
        winner = tie_winners(np.array([0]), np.array([1]), np.array([1700, 1700]),
            ScoreModel((.3,.2,.8)), 0, rng, played_margin=-2)
        np.testing.assert_array_equal(winner, [1])
        self.assertEqual(rng.poisson.call_count, 2)

    def test_verified_unplayed_paths_and_live_result_handling(self):
        rows = [fixture(1, 1, 2, 'Semi-finals', leg='1/2', score=(20, 0)),
                fixture(2, 2, 1, 'Semi-finals', leg='2/2'),
                fixture(3, 3, 4, 'Semi-finals', leg='1/2', score=(20, 0)),
                fixture(4, 4, 3, 'Semi-finals', leg='2/2'), fixture(5, None, None)]
        edges = [{'parent_fixture_id': p, 'parent_outcome': 'winner', 'child_fixture_id': 5, 'child_slot': slot}
                 for p, slot in ((2, 'home'), (4, 'away'))]
        bracket = build(rows, provider_edges=edges)
        result = self.estimate(bracket)
        self.assertEqual(result[2]['probability'], 0)
        self.assertEqual(result[4]['probability'], 0)
        self.assertTrue(.4 < result[1]['probability'] < .6)
        rows[1]['state_id'] = 2
        with self.assertRaisesRegex(ValueError, 'live'):
            self.estimate(build(rows, provider_edges=edges))
        with self.assertRaisesRegex(ValueError, 'verified knockout path'):
            self.estimate(build(rows))


class BracketLoaderTests(unittest.TestCase):
    def test_check_never_writes_and_apply_uses_same_collected_payload(self):
        brackets = [build([fixture(1, 1, 2)])]
        with patch.object(loader, 'collect', return_value=brackets), patch.object(loader, 'store_brackets') as store:
            self.assertIs(loader.refresh(), brackets)
            store.assert_not_called()
            self.assertIs(loader.refresh(apply=True), brackets)
            store.assert_called_once_with(brackets)

    def test_collection_uses_full_season_without_big_five_team_filter(self):
        rows = [fixture(1, 90000, 90001)]
        with patch.object(loader, 'read_seasons', return_value=[dict(season_id=100, competition_id=2, season_name='2026/2027')]), \
             patch.object(loader, 'SportmonksClient') as client, patch.object(loader, '_fetch', return_value=[]):
            client.return_value.iter_fixtures_by_season.return_value = iter(rows)
            client.return_value.get_season_bracket.return_value = {'stages': [], 'edges': []}
            result = loader.collect()
        self.assertEqual(set(result[0]['teams']), {'90000', '90001'})
        self.assertFalse(result[0]['stages'][0]['ties'][0]['fixtures'][0]['detail_available'])
        client.return_value.iter_fixtures_by_season.assert_called_once_with(100, include=loader.INCLUDE)


if __name__ == '__main__':
    unittest.main()
