from datetime import datetime, timezone
import json
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

import numpy as np

from one_touch_loader.core import european_probability as core
from one_touch_loader.core.betting import match_outcome
from one_touch_loader.loaders import european_probability_loader as loader


def inputs(competition_id=2):
    fixtures = []
    for home in range(36):
        for offset in range(1, core.LEAGUE_GAMES[competition_id] // 2 + 1):
            fixtures.append({'fixture_id': len(fixtures)+1, 'home_team_id': home,
                'away_team_id': (home+offset) % 36, 'state_id': 1, 'home_score': None, 'away_score': None,
                'competition_id': competition_id, 'season_id': 100, 'season_name': '2026/2027',
                'stage_type_id': 223, 'stage_name': 'League Stage', 'round_name': str(offset),
                'leg': None, 'aggregate_id': None, 'starting_at': '2026-10-01 20:00:00'})
    coefficients = {str(t): {'coefficient': 30+t, 'season_coefficients': [0, 0, 0, 0, 30+t],
        'association_floor': 0, 'domestic_position': None} for t in range(36)}
    return dict(competition_id=competition_id, team_ids=list(range(36)), fixtures=fixtures,
        elos=dict.fromkeys(range(36), 1700), coefficients=coefficients, discipline={},
        model=core.ScoreModel((.3, .2, .8)), penalty_coefficient=0, card_samples=[[2, 3], [1, 4]],
        simulations=200, seed=20260921)


def card(event_id, kind, *, team=1, player=10, coach=None, name=None, rescinded=False):
    return {'id': event_id, 'type_id': kind, 'participant_id': team, 'player_id': player,
            'coach_id': coach, 'player_name': name, 'rescinded': rescinded}


class EuropeanProbabilityTests(unittest.TestCase):
    def test_every_article18_tie_break_has_priority_over_later_rules(self):
        # 0·1번 팀은 앞선 기준을 같게 두고 다음 기준으로만 순서를 가려요.
        for criterion in range(11):
            with self.subTest(criterion=criterion):
                values = {k: np.full((1, 4), v) for k,v in (
                    ('points', 8), ('goals_for', 10), ('goals_against', 10), ('away_goals', 3),
                    ('wins', 2), ('away_wins', 1), ('discipline', 5))}
                opponents = np.array([[0,0,1,0], [0,0,0,1], [1,0,0,0], [0,1,0,0]])
                coef = np.array([0,1,2,3])
                if criterion == 0: values['points'][0,0] += 1
                elif criterion == 1: values['goals_against'][0,0] -= 1
                elif criterion == 2:
                    values['goals_for'][0,0] += 1
                    values['goals_against'][0,0] += 1
                elif criterion == 3: values['away_goals'][0,0] += 1
                elif criterion == 4: values['wins'][0,0] += 1
                elif criterion == 5: values['away_wins'][0,0] += 1
                elif criterion == 6: values['points'][0,2] += 1
                elif criterion == 7: values['goals_against'][0,2] -= 1
                elif criterion == 8:
                    values['goals_for'][0,2] += 1
                    values['goals_against'][0,2] += 1
                elif criterion == 9: values['discipline'][0,0] -= 1
                else: coef[[0,1]] = [1,0]
                order = core.league_order(**values, opponents=opponents, coefficient=coef)[0].tolist()
                self.assertLess(order.index(0), order.index(1))

    def test_annex_d_coefficient_recent_seasons_association_and_domestic_position(self):
        def row(annual, floor=0, position=None):
            return dict(coefficient=max(sum(annual), floor), season_coefficients=annual,
                        association_floor=floor, domestic_position=position)
        comparisons = [
            (row([0,0,0,0,11]), row([0,0,0,0,10])),
            (row([0,0,0,4,6]), row([0,0,0,5,5])),
            (row([0,0,3,2,5]), row([0,1,2,2,5])),
            (row([0,0,0,0,10], 3), row([0,0,0,0,10], 2)),
            (row([0,0,0,0,0], 20, 6), row([0,0,0,0,0], 20, 7)),
        ]
        for first, second in comparisons:
            np.testing.assert_array_equal(core.coefficient_priority([1,2], {'1':first, '2':second}), [1,0])
        with self.assertRaisesRegex(ValueError, 'domestic positions'):
            core.coefficient_priority([1,2], {'1':first, '2':first})

    def test_verified_current_coefficient_registry_resolves_all_108_teams(self):
        path = Path(core.__file__).with_name('uefa_coefficients_2026.json')
        coefficients = json.loads(path.read_text(encoding='utf-8'))['teams']
        self.assertEqual(len(coefficients),108)
        self.assertEqual(len(set(core.coefficient_priority([int(t) for t in coefficients], coefficients))),108)
        self.assertGreater(core.coefficient_priority([52,3],coefficients)[0],
                           core.coefficient_priority([52,3],coefficients)[1])

    def test_cards_include_officials_and_double_yellow_is_three_in_total(self):
        events = [card(1,19), card(2,21), card(3,19,player=None,coach=90),
                  card(4,20,team=2), card(5,19,team=2), card(6,19,player=None),
                  card(7,20,rescinded=True)]
        self.assertEqual(core.disciplinary_points(events,(1,2)), {1:5,2:4})
        self.assertEqual(core.disciplinary_points([card(1,21)],(1,2)), {1:3,2:0})
        with self.assertRaisesRegex(ValueError, 'Cannot link'):
            core.disciplinary_points([card(1,19,player=None),card(2,21)], (1,2))
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            core.disciplinary_points([card(1,19),card(1,19)], (1,2))
        with self.assertRaisesRegex(ValueError, 'participant'):
            core.disciplinary_points([card(1,19,team=3)], (1,2))

    def test_second_leg_bet_winner_and_tie_winner_can_differ(self):
        rng = Mock()
        rng.poisson.side_effect = [np.array([v]) for v in [1,0,0,1,0,0]]
        rng.random.return_value = np.array([.99])
        winner = core.tie_winners(np.array([0]),np.array([1]),np.array([1700,1700]),
                                  core.ScoreModel((.3,.2,.8)),0,rng)
        np.testing.assert_array_equal(winner,[1])
        self.assertEqual(match_outcome({'state_id':8,'home_score':1,'away_score':0,
                         'home_penalty_score':3,'away_penalty_score':4}), 'home_win')

    def test_neutral_final_and_extra_time_exposure(self):
        model = core.ScoreModel((.3,.2,.8))
        home,away = model.rates(0,neutral=True)
        self.assertEqual(home,away)
        np.testing.assert_allclose(model.rates(100,minutes=30),np.array(model.rates(100))/3)
        rng = Mock()
        rng.poisson.side_effect=[np.array([1]),np.array([0])]
        core.tie_winners(np.array([0]),np.array([1]),np.array([1700,1700]),model,0,rng,final=True)
        self.assertEqual(rng.poisson.call_count,2)

    def test_annex_b_pairs_and_seeded_home_path_survive_an_upset(self):
        order = np.arange(36)[None,:]
        rng = Mock(); rng.integers.return_value=np.array([0])
        calls=[]
        def win_other(home,away,*args,**kwargs):
            calls.append((home.copy(),away.copy(),kwargs.get('final',False)))
            return away
        with patch.object(core,'tie_winners',side_effect=win_other):
            core.simulate_knockout(order,np.full(36,1700),core.ScoreModel((.3,.2,.8)),0,rng)
        np.testing.assert_array_equal(calls[0][0],[[10,12,8,14]])
        np.testing.assert_array_equal(calls[0][1],[[20,18,22,16]])
        np.testing.assert_array_equal(calls[1][0],[[4,2,6,0]])
        # 3/4와 1/2를 꺾은 팀이 8강 2차전 홈을 이어받아요.
        np.testing.assert_array_equal(calls[2][0],[[18,16]])
        self.assertTrue(calls[-1][2])

    def test_all_three_competitions_conserve_probability_and_seed_is_reproducible(self):
        for competition in core.LEAGUE_GAMES:
            args=inputs(competition)
            first=core.simulate_title(**args)
            self.assertEqual(first,core.simulate_title(**args))
            self.assertEqual(sum(t['wins'] for t in first.values()),args['simulations'])
            self.assertAlmostEqual(sum(t['probability'] for t in first.values()),1)
            self.assertTrue(all(0 <= t['probability'] <= 1 for t in first.values()))

    def test_complete_results_and_cards_fix_the_table_without_resampling(self):
        args=inputs()
        for f in args['fixtures']:
            f.update(state_id=5,home_score=0,away_score=0)
            args['discipline'][f['fixture_id']]={f['home_team_id']:0,f['away_team_id']:0}
        orders=[]
        def take_first(order,*unused):
            orders.append(order)
            return order[:,0]
        with patch.object(core,'simulate_knockout',side_effect=take_first):
            result=core.simulate_title(**args)
        np.testing.assert_array_equal(orders[0],np.tile(np.arange(35,-1,-1),(200,1)))
        self.assertEqual(result[35]['probability'],1)
        self.assertEqual(result[35]['resolution'], 'unresolved')
        self.assertTrue(all(result[t]['resolution'] == 'impossible' for t in range(12)))

    def test_bracket_certainty_uses_confirmed_winners_not_sample_counts(self):
        from diagnostics.test_tournament_bracket import build, fixture
        bracket = build([fixture(1001, 1, 2)])
        args = dict(bracket=bracket, team_ids=[1, 2, 3], elos={1: 1700, 2: 1700, 3: 1700},
                    model=core.ScoreModel((.3, .2, .8)), penalty_coefficient=0, simulations=1, seed=7)
        estimates = core.simulate_bracket_title(**args)
        self.assertEqual({estimates[t]['probability'] for t in (1, 2)}, {0, 1})
        self.assertTrue(all(estimates[t]['resolution'] == 'unresolved' for t in (1, 2)))
        self.assertEqual(estimates[3]['resolution'], 'impossible')
        args['bracket'] = build([fixture(1001, 1, 2, score=(2, 1))])
        resolved = core.simulate_bracket_title(**args)
        self.assertEqual(resolved[1]['resolution'], 'certain')
        self.assertEqual(resolved[2]['resolution'], 'impossible')

    def test_missing_schedule_elo_or_unresolved_match_is_not_invented(self):
        for kind in ('schedule','elo','unresolved','score'):
            args=inputs()
            if kind=='schedule': args['fixtures'].pop()
            if kind=='elo': args['elos'].pop(0)
            if kind=='unresolved': args['fixtures'][0]['state_id']=15
            if kind=='score': args['fixtures'][0]['state_id']=5
            with self.subTest(kind=kind), self.assertRaises(ValueError): core.simulate_title(**args)

    def test_live_score_does_not_block_other_completed_match_results(self):
        args=inputs()
        baseline=core.simulate_title(**args)
        args['fixtures'][0].update(state_id=2,home_score=99,away_score=0)
        self.assertEqual(core.simulate_title(**args),baseline)

    def test_drawn_path_is_not_randomly_reconstructed_and_check_never_writes(self):
        args=inputs(); f={**args['fixtures'][0],'stage_type_id':224}
        report={'model_id':'m','method':core.MODEL_METHOD,'forecast_model':{
            'coefficients':[.3,.2,.8],'last_training_fixture_at':'2026-05-01 12:00:00'}}
        runs,status=loader.prepare_runs([f],{},report,[],observed_at=datetime(2026,9,21,tzinfo=timezone.utc))
        self.assertEqual(runs,[])
        self.assertEqual(status[0]['status'],'verified_knockout_path_required')
        with patch.object(loader.common,'latest_model',return_value=report), \
             patch.object(loader.cup_betting_loader,'read_fixtures',return_value=[f]), \
             patch.object(loader,'read_card_fixtures',return_value=[]), \
             patch.object(loader.common,'_fetch',return_value=[]), \
             patch.object(loader.common,'store_runs') as store:
            self.assertFalse(loader.refresh(histories={})['applied'])
        store.assert_not_called()

    def test_verified_bracket_is_used_and_fingerprinted_by_refresh(self):
        from diagnostics.test_tournament_bracket import build, fixture
        args = inputs()
        for f in args['fixtures']:
            f.update(state_id=5, home_score=0, away_score=0)
        bracket = build([fixture(1001, 1, 2, score=(2, 1))])
        report = {'model_id': 'm', 'method': core.MODEL_METHOD, 'forecast_model': {
            'coefficients': [.3, .2, .8], 'penalty_coefficient': 0,
            'last_training_fixture_at': '2026-05-01 12:00:00'}, 'limitations': [], 'validation': {'metrics': {}}}
        coefficients = {'season_name': '2026/2027', 'teams': args['coefficients'], 'source_url': 'verified'}
        histories = {t: [{'date': '2027-04-01', 'elo': 1700}] for t in args['team_ids']}
        observed_at = datetime(2027, 4, 2, tzinfo=timezone.utc)
        with patch.object(loader.common, '_read', return_value=coefficients), \
             patch.object(loader, 'simulate_title') as undrawn:
            runs, status = loader.prepare_runs(args['fixtures'], histories, report, [],
                observed_at=observed_at, brackets=[bracket], simulations=100)
            undrawn.assert_not_called()
            self.assertEqual(status[0]['status'], 'updated')
            self.assertEqual(runs[0]['bracket_input_sha256'], bracket['input_sha256'])
            self.assertEqual(runs[0]['teams']['1']['probability'], 1)
            self.assertEqual(runs[0]['teams']['2']['probability'], 0)
            self.assertEqual(runs[0]['teams']['1']['resolution'], 'certain')
            self.assertEqual(runs[0]['teams']['2']['resolution'], 'impossible')
            self.assertEqual(runs[0]['teams']['1']['played'], 9)
            self.assertEqual(runs[0]['teams']['1']['previous_fixture_at'], '2027-04-01T20:00:00+00:00')
            with patch.object(loader, 'simulate_bracket_title', wraps=core.simulate_bracket_title) as simulate:
                options = dict(observed_at=observed_at, brackets=[bracket], simulations=100,
                               previous_by_season={100: runs[0]})
                self.assertEqual(loader.prepare_runs(args['fixtures'], histories, report, [], **options)[0], [])
                simulate.assert_not_called()
                runs[0]['refresh_input_version'] = 2
                updated, _ = loader.prepare_runs(args['fixtures'], histories, report, [], **options)
                self.assertEqual(updated[0]['refresh_input_version'], 3)
                simulate.assert_called_once()
            bracket['fetched_at'] = '2027-04-03T00:00:00Z'
            with self.assertRaisesRegex(ValueError, 'predate'):
                loader.prepare_runs(args['fixtures'], histories, report, [],
                    observed_at=observed_at, brackets=[bracket], simulations=100)

    def test_stored_match_context_counts_only_completed_main_competition_fixtures(self):
        args = inputs()
        report = {'model_id': 'm', 'method': core.MODEL_METHOD, 'forecast_model': {
            'coefficients': [.3, .2, .8], 'penalty_coefficient': 0, 'card_samples': [[2, 3]],
            'last_training_fixture_at': '2026-05-01 12:00:00'}, 'limitations': [], 'validation': {'metrics': {}}}
        coefficients = {'season_name': '2026/2027', 'teams': args['coefficients'], 'source_url': 'verified'}
        histories = {t: [{'date': '2026-09-01', 'elo': 1700}] for t in args['team_ids']}
        first = args['fixtures'][0]
        first.update(state_id=5, home_score=1, away_score=0, starting_at='2026-09-10 19:00:00')
        fixtures = args['fixtures'] + [{**first, 'fixture_id': 901, 'stage_type_id': 225},
                                      {**first, 'fixture_id': 902, 'competition_id': 82}]
        raw = [{'id': first['fixture_id'], 'state_id': 5, 'events': []}]
        with patch.object(loader.common, '_read', return_value=coefficients):
            runs, _ = loader.prepare_runs(fixtures, histories, report, raw,
                observed_at=datetime(2026, 9, 21, tzinfo=timezone.utc), simulations=100)
        for team_id in (0, 1):
            team = runs[0]['teams'][str(team_id)]
            self.assertEqual(team['played'], 1)
            self.assertEqual(team['previous_fixture_at'], '2026-09-10T19:00:00+00:00')
        self.assertEqual(runs[0]['teams']['2']['played'], 0)
        self.assertIsNone(runs[0]['teams']['2']['previous_fixture_at'])

    def test_training_uses_only_pre_match_ratings_and_excludes_ambiguous_cards(self):
        f={**inputs()['fixtures'][0], 'home_team_id':1, 'away_team_id':2,
           'season_name':'2025/2026','state_id':5,'starting_at':'2025-10-02 20:00:00',
           'home_score':1,'away_score':0,'stage_name':'League Stage'}
        histories={1:[{'date':'2025-10-01','elo':1800},{'date':'2025-10-02','elo':9999}],
                   2:[{'date':'2025-10-01','elo':1700}]}
        raw={'id':f['fixture_id'],'state_id':5,'events':[card(1,19,player=None),card(2,21)]}
        data=loader.build_dataset([f],histories,[raw])
        self.assertEqual(data['scores'][0]['difference'],100)
        self.assertEqual(data['cards'],[])
        self.assertEqual(len(data['excluded_cards']),1)

    def test_stage_probabilities_conserve_places_and_do_not_invent_certainty(self):
        for competition in core.LEAGUE_GAMES:
            with self.subTest(competition=competition):
                estimates = core.simulate_title(**inputs(competition))
                for stage, places in (('winner', 1), ('final', 2), ('semifinal', 4),
                                      ('quarterfinal', 8), ('round16', 16), ('playoff', 24)):
                    self.assertAlmostEqual(sum(next(s['probability'] for s in e['stage_probabilities']
                                                   if s['stage_key'] == stage) for e in estimates.values()), places)
                for estimate in estimates.values():
                    stages = estimate['stage_probabilities']
                    self.assertEqual(len(stages), 6)
                    self.assertEqual([s['probability'] for s in stages], sorted(s['probability'] for s in stages))
                    self.assertTrue(all(s['resolution'] == 'unresolved' for s in stages))

    def test_final_league_table_confirms_direct_last16_and_playoff_milestones(self):
        args = inputs()
        for f in args['fixtures']:
            f.update(state_id=5, home_score=0, away_score=0)
            args['discipline'][f['fixture_id']] = {f['home_team_id']: 0, f['away_team_id']: 0}
        estimates = core.simulate_title(**args)
        for team, expected in ((35, ('certain', 'certain')), (20, ('certain', 'unresolved')),
                               (0, ('impossible', 'impossible'))):
            stages = {s['stage_key']: s for s in estimates[team]['stage_probabilities']}
            self.assertEqual((stages['playoff']['resolution'], stages['round16']['resolution']), expected)
        self.assertTrue(all(e['current_stage'] == 'league' for e in estimates.values()))

    def test_league_what_if_conditions_on_the_same_tournament_samples(self):
        args = inputs()
        args['simulations'] = 20000
        fixtures = [{**f, 'stage_key': 'league'} for f in args['fixtures']]
        args['next_fixtures'] = loader.next_matches(fixtures, args['team_ids'],
            {f['fixture_id'] for f in fixtures}, datetime(2026, 9, 20, tzinfo=timezone.utc))
        estimates = core.simulate_title(**args)
        for team, estimate in estimates.items():
            what_if = estimate['what_if']
            self.assertIsNotNone(what_if)
            self.assertEqual([s['outcome'] for s in what_if['scenarios']], ['win', 'draw', 'loss'])
            self.assertEqual(sum(s['simulations'] for s in what_if['scenarios']), args['simulations'])
            self.assertAlmostEqual(sum(s['probability'] * s['simulations'] / args['simulations']
                                      for s in what_if['scenarios']), estimate['probability'])
            for s in what_if['scenarios']:
                self.assertAlmostEqual(s['change_pp'], 100 * (s['probability'] - estimate['probability']))

    def test_final_what_if_has_only_win_and_loss_with_certain_title_results(self):
        from diagnostics.test_tournament_bracket import build, fixture
        bracket = build([fixture(1001, 1, 2)])
        final = dict(fixture_id=1001, home_team_id=1, away_team_id=2, starting_at='2027-04-01T20:00:00Z',
                     stage_key='final', leg='1/1', round_name='Final', draw_allowed=False,
                     result_basis='single_match_final_v1')
        args = dict(bracket=bracket, team_ids=[1, 2], elos={1: 1700, 2: 1700},
                    model=core.ScoreModel((.3, .2, .8)), penalty_coefficient=0, simulations=2000, seed=7,
                    next_fixtures={1: final, 2: final})
        estimates = core.simulate_bracket_title(**args)
        for estimate in estimates.values():
            self.assertEqual(estimate['current_stage'], 'final')
            self.assertEqual(estimate['what_if']['fixture']['probabilities'][1], 0)
            self.assertEqual([(s['outcome'], s['probability']) for s in estimate['what_if']['scenarios']],
                             [('win', 1), ('loss', 0)])
            stage = next(s for s in estimate['stage_probabilities'] if s['stage_key'] == 'final')
            self.assertEqual((stage['probability'], stage['resolution']), (1, 'certain'))
        args['simulations'] = 1
        sparse = core.simulate_bracket_title(**args)
        for estimate in sparse.values():
            missing = next(s for s in estimate['what_if']['scenarios'] if s['simulations'] == 0)
            self.assertIsNone(missing['probability'])
            self.assertIsNone(missing['change_pp'])

    def test_match_samples_keep_first_leg_orientation_and_aggregate_winner_separate(self):
        rng = Mock()
        rng.poisson.side_effect = [np.array([v]) for v in (1, 0, 0, 1, 0, 0)]
        rng.random.return_value = np.array([.99])
        results = []
        winner = core.tie_winners(np.array([0]), np.array([1]), np.array([1700, 1700]),
            core.ScoreModel((.3, .2, .8)), 0, rng, match_results=results)
        self.assertEqual(winner.tolist(), [1])
        self.assertEqual([r.tolist() for r in results], [[0], [0]])

    def test_drawn_second_leg_what_if_keeps_the_first_leg_and_verified_final_path(self):
        from diagnostics.test_tournament_bracket import build, fixture
        rows = [fixture(1, 1, 2, 'Semi-finals', leg='1/2', score=(2, 0)),
                fixture(2, 2, 1, 'Semi-finals', leg='2/2'),
                fixture(3, 3, 4, 'Semi-finals', leg='1/2', score=(0, 0)),
                fixture(4, 4, 3, 'Semi-finals', leg='2/2'), fixture(5, None, None)]
        edges = [{'parent_fixture_id': p, 'parent_outcome': 'winner', 'child_fixture_id': 5, 'child_slot': slot}
                 for p, slot in ((2, 'home'), (4, 'away'))]
        next_fixtures = {team: {'fixture_id': fid, 'home_team_id': home, 'away_team_id': away,
                              'draw_allowed': fid == 2} for fid, home, away in ((2, 2, 1), (4, 4, 3))
                         for team in (home, away)}
        estimates = core.simulate_bracket_title(bracket=build(rows, provider_edges=edges), team_ids=[1, 2, 3, 4],
            elos=dict.fromkeys(range(1, 5), 1700), model=core.ScoreModel((.3, .2, .8)), penalty_coefficient=0,
            simulations=20000, seed=19, next_fixtures=next_fixtures)
        for estimate in estimates.values():
            self.assertEqual(estimate['current_stage'], 'semifinal')
            scenarios = estimate['what_if']['scenarios']
            self.assertEqual(sum(s['simulations'] for s in scenarios), 20000)
            self.assertAlmostEqual(sum(s['probability'] * s['simulations'] / 20000 for s in scenarios),
                                   estimate['probability'])
        self.assertEqual([s['outcome'] for s in estimates[3]['what_if']['scenarios']], ['win', 'loss'])
        # 1차전에서 앞선 팀은 2차전에서 져도 합산 점수로 진출하고 우승할 수 있어요.
        self.assertGreater(estimates[1]['what_if']['scenarios'][2]['probability'], 0)
        self.assertLess(estimates[2]['what_if']['scenarios'][0]['probability'], 1)

    def test_completed_real_bracket_preserves_reached_and_eliminated_stages(self):
        from diagnostics.test_tournament_bracket import actual_bracket
        bracket = actual_bracket(25580)
        teams = sorted(int(t) for t in bracket['teams'])
        estimates = core.simulate_bracket_title(bracket=bracket, team_ids=teams, elos=dict.fromkeys(teams, 1700),
            model=core.ScoreModel((.3, .2, .8)), penalty_coefficient=0, simulations=1, seed=19)
        entrants = {s['key']: {slot['team_id'] for t in s['ties'] for slot in t['slots']}
                    for s in bracket['stages']}
        for team, estimate in estimates.items():
            stages = {s['stage_key']: s for s in estimate['stage_probabilities']}
            for key, participants in entrants.items():
                expected = (1, 'certain') if team in participants else (0, 'impossible')
                self.assertEqual((stages[key]['probability'], stages[key]['resolution']), expected)
            self.assertEqual(estimate['current_stage'],
                             next(key for key in reversed(core.EUROPE_STAGES) if team in entrants[key]))

    def test_next_match_uses_shared_second_leg_draw_rule_and_confirmed_schedule(self):
        first = {**inputs()['fixtures'][0], 'fixture_id': 1, 'home_team_id': 1, 'away_team_id': 2,
                 'stage_type_id': 224, 'stage_name': '8th Finals', 'stage_key': 'round16', 'leg': '1/2',
                 'aggregate_id': 'tie:1', 'starting_at': '2027-02-01', 'state_id': 5,
                 'home_score': 1, 'away_score': 1}
        second = {**first, 'fixture_id': 2, 'home_team_id': 2, 'away_team_id': 1, 'leg': '2/2',
                  'starting_at': '2027-02-08', 'state_id': 1, 'home_score': None, 'away_score': None}
        observed = datetime(2027, 2, 2, tzinfo=timezone.utc)
        for score, draw_allowed in ((1, False), (2, True)):
            first['home_score'] = score
            result = loader.next_matches([first, second], [1, 2], {1, 2}, observed)
            self.assertEqual(result[1]['fixture_id'], 2)
            self.assertEqual(result[1]['draw_allowed'], draw_allowed)
        for state in (2, 10, 13):
            second['state_id'] = state
            self.assertEqual(loader.next_matches([first, second], [1, 2], {1, 2}, observed), {})


if __name__=='__main__':
    unittest.main()
