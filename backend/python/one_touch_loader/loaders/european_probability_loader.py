"""유럽대항전 우승확률을 학습·갱신해요. 저장은 --apply일 때만 실행해요."""
import argparse
from collections import defaultdict
from dataclasses import asdict
from datetime import datetime, timedelta, timezone
import hashlib
from pathlib import Path

import numpy as np
from scipy.special import expit

from ..core.clubelo import rating_before
from ..core.cup_betting import EUROPE_COMPETITION_IDS, utc_datetime
from ..core.european_probability import (MODEL_METHOD, OUTCOME_KIND, TITLE_EVENTS, ScoreModel,
    disciplinary_points, fit_penalties, fit_scores, score_loss, simulate_title, simulate_bracket_title)
from ..core.sportmonks import SportmonksClient, correct_event_metadata
from . import cup_betting_loader, probability_loader as common
from .probability_training import BIG5_IDS, MODEL_SEASONS, TRAIN_SEASONS, VALIDATION_SEASON


def read_fixtures():
    return common.read_fixtures(MODEL_SEASONS) + cup_betting_loader.read_fixtures()


def read_card_fixtures(fixtures):
    ids = sorted({f['fixture_id'] for f in fixtures if f['competition_id'] in EUROPE_COMPETITION_IDS
                  and f.get('stage_type_id') == 223 and f['state_id'] == 5})
    client, result = SportmonksClient(), []
    for start in range(0, len(ids), 50):
        # 선수뿐 아니라 감독 카드도 읽어요. 현재 DB에 빠진 감독 경고를 원본에서 확인했어요.
        result.extend(client.get_fixtures_batch(ids[start:start + 50], include='events.type;coaches'))
    return result


def card_points(raw, fixture):
    if raw['id'] != fixture['fixture_id'] or raw['state_id'] != 5:
        raise ValueError('Disciplinary source does not match the completed fixture')
    events = correct_event_metadata([dict(e) for e in raw['events']])
    return disciplinary_points(events, (fixture['home_team_id'], fixture['away_team_id']))


def build_dataset(fixtures, histories, card_fixtures):
    scores, penalties, cards, excluded = [], [], [], []
    for f in fixtures:
        if f['season_name'] not in MODEL_SEASONS or f['starting_at'] is None:
            continue
        day = utc_datetime(f['starting_at']).date()
        elos = [rating_before(histories.get(f[key], []), day) for key in ('home_team_id', 'away_team_id')]
        if None in elos:
            continue
        row = {'fixture_id': f['fixture_id'], 'season_name': f['season_name'], 'starting_at': str(f['starting_at']),
               'difference': elos[0] - elos[1]}
        if f['state_id'] == 5 and f['competition_id'] in (*BIG5_IDS, *EUROPE_COMPETITION_IDS):
            if f['home_score'] is None or f['away_score'] is None:
                raise ValueError('Completed training fixture is missing a score')
            scores.append({**row, 'scores': [f['home_score'], f['away_score']],
                           'neutral': f.get('stage_name', '').casefold() == 'final'})
        if (f['state_id'] == 8 and f['home_penalty_score'] is not None and f['away_penalty_score'] is not None
                and f['home_penalty_score'] != f['away_penalty_score']):
            penalties.append({**row, 'home_win': int(f['home_penalty_score'] > f['away_penalty_score'])})
    by_id = {f['fixture_id']: f for f in fixtures}
    for raw in card_fixtures:
        fixture = by_id[raw['id']]
        if fixture['season_name'] not in MODEL_SEASONS:
            continue
        try:
            totals = card_points(raw, fixture)
        except ValueError as error:
            excluded.append({'fixture_id': raw['id'], 'reason': str(error)})
            continue
        cards.append({'fixture_id': raw['id'], 'season_name': fixture['season_name'],
                      'points': [totals[fixture['home_team_id']], totals[fixture['away_team_id']]]})
    if len({r['fixture_id'] for r in scores}) != len(scores):
        raise ValueError('Duplicate score training fixture')
    return {'scores': scores, 'penalties': penalties, 'cards': cards, 'excluded_cards': excluded}


def train_and_validate(dataset):
    def fit(rows):
        return fit_scores([r['difference'] for r in rows], [r['scores'] for r in rows], [r['neutral'] for r in rows])
    training = [r for r in dataset['scores'] if r['season_name'] in TRAIN_SEASONS]
    validation = [r for r in dataset['scores'] if r['season_name'] == VALIDATION_SEASON]
    if not training or not validation or max(r['starting_at'] for r in training) >= min(r['starting_at'] for r in validation):
        raise ValueError('A separate later validation season is required')
    fitted = fit(training)
    home_mean, away_mean = np.mean([r['scores'] for r in training], axis=0)
    baseline = ScoreModel((float(np.log(home_mean * away_mean) / 2), float(np.log(home_mean / away_mean)), 0.0))
    args = ([r['difference'] for r in validation], [r['scores'] for r in validation], [r['neutral'] for r in validation])
    pk_train = [r for r in dataset['penalties'] if r['season_name'] in TRAIN_SEASONS]
    pk_validation = [r for r in dataset['penalties'] if r['season_name'] == VALIDATION_SEASON]
    pk_coefficient = fit_penalties([r['difference'] for r in pk_train], [r['home_win'] for r in pk_train])
    pk_probs = expit(pk_coefficient * np.array([r['difference'] for r in pk_validation]) / 400)
    pk_actual = np.array([r['home_win'] for r in pk_validation])
    if not len(pk_validation) or not dataset['cards']:
        raise ValueError('Separate penalty validation and observed disciplinary samples are required')
    pk_loss = float(-np.mean(np.log(np.where(pk_actual, pk_probs, 1-pk_probs))))
    refitted = fit(dataset['scores'])
    # 2025/26 검증에서는 Elo 승부차기 모델이 50%보다 나빴어요. 검증에서 나은 모델만 사용해요.
    penalty = (fit_penalties([r['difference'] for r in dataset['penalties']], [r['home_win'] for r in dataset['penalties']])
               if pk_loss < np.log(2) else 0.0)
    report = {'method': MODEL_METHOD, 'validation': {
        'training_seasons': TRAIN_SEASONS, 'season': VALIDATION_SEASON,
        'training_fixtures': len(training), 'metrics': {'fixtures': len(validation),
            'score_log_loss': score_loss(fitted, *args), 'score_baseline_log_loss': score_loss(baseline, *args),
            'penalty_fixtures': len(pk_validation), 'penalty_elo_log_loss': pk_loss,
            'penalty_equal_chance_log_loss': float(np.log(2)),
            'penalty_method': 'elo' if penalty else 'equal_chance'}},
        'forecast_model': {**asdict(refitted), 'penalty_coefficient': penalty,
            'training_fixtures': len(dataset['scores']), 'penalty_fixtures': len(dataset['penalties']),
            'last_training_fixture_at': max(r['starting_at'] for r in dataset['scores']),
            'card_samples': [r['points'] for r in dataset['cards']]},
        'excluded_cards': dataset['excluded_cards'],
        'limitations': ['Independent Poisson goals with fixed current Elo and learned home advantage',
            'Extra-time goals use the same scoring process for 30 minutes',
            'Shoot-out model is selected against equal chance on a small held-out sample',
            'Future disciplinary points are sampled jointly from observed UEFA matches',
            'UEFA Article 18 and Annex D tie-breaks are applied to every simulated table',
            'Undrawn knockout paths follow UEFA Annex B; drawn paths need verified progression data']}
    report['dataset_sha256'] = hashlib.sha256(common._dump(dataset).encode()).hexdigest()
    report['model_id'] = hashlib.sha256(common._dump(report).encode()).hexdigest()
    return report


def prepare_runs(fixtures, histories, report, card_fixtures, *, observed_at, simulations=100000,
                 seed=20260917, brackets=()):
    coefficient_data = common._read(Path(__file__).parents[1] / 'core/uefa_coefficients_2026.json')
    if report['method'] != MODEL_METHOD or utc_datetime(report['forecast_model']['last_training_fixture_at']) >= observed_at:
        raise ValueError('A previously trained European title model is required')
    current = [f for f in fixtures if f['competition_id'] in EUROPE_COMPETITION_IDS
               and f['season_name'] == coefficient_data['season_name']]
    raw_by_id = {r['id']: r for r in card_fixtures}
    model = ScoreModel(tuple(report['forecast_model']['coefficients']))
    runs, statuses = [], []
    bracket_by_season = {b['season_id']: b for b in brackets}
    for season_id, competition_id in sorted({(f['season_id'], f['competition_id']) for f in current}):
        season = [f for f in current if f['season_id'] == season_id]
        bracket = bracket_by_season.get(season_id)
        drawn = any(f['stage_type_id'] == 224 for f in season) or bool(bracket and bracket['stages'])
        if drawn and (bracket is None or bracket['path_status'] != 'complete'):
            statuses.append({'season_id': season_id, 'status': 'verified_knockout_path_required'})
            continue
        league = [f for f in season if f['stage_type_id'] == 223]
        teams = sorted({f[key] for f in league for key in ('home_team_id', 'away_team_id')})
        elos = {t: rating_before(histories.get(t, []), observed_at.date() + timedelta(days=1)) for t in teams}
        if any(value is None for value in elos.values()):
            raise ValueError(f'Missing current Elo for UEFA season {season_id}')
        discipline = {}
        for f in league:
            if not drawn and f['state_id'] == 5:
                if utc_datetime(f['starting_at']) >= observed_at:
                    raise ValueError('A completed fixture is dated after the forecast')
                discipline[f['fixture_id']] = card_points(raw_by_id[f['fixture_id']], f)
        model_args = dict(team_ids=teams, elos=elos, model=model,
            penalty_coefficient=report['forecast_model']['penalty_coefficient'], simulations=simulations, seed=seed)
        if drawn:
            if (bracket['competition_id'] != competition_id or bracket['season_name'] != coefficient_data['season_name']
                    or utc_datetime(bracket['fetched_at']) > observed_at):
                raise ValueError('The bracket must belong to this season and predate the calculation')
            # 과거 결과로 복원한 경로를 경기 전 시점의 예측인 것처럼 재사용하지 않아요.
            if any(f['state_id'] in (5, 7, 8) and (f['starting_at'] is None or utc_datetime(f['starting_at']) >= observed_at)
                   for st in bracket['stages'] for tie in st['ties'] for f in tie['fixtures']):
                raise ValueError('A completed knockout fixture is dated after the forecast')
            estimates = simulate_bracket_title(bracket=bracket, **model_args)
        else:
            estimates = simulate_title(competition_id=competition_id, fixtures=league,
                coefficients=coefficient_data['teams'], discipline=discipline,
                card_samples=report['forecast_model']['card_samples'], **model_args)
        run = {'model_id': report['model_id'], 'season_id': season_id, 'as_of': observed_at.isoformat(),
            'outcome_kind': OUTCOME_KIND, 'simulations': simulations, 'seed': seed,
            'max_sampling_standard_error_pp': 50 / np.sqrt(simulations),
            'probability_method': MODEL_METHOD, 'strength_source_url': 'https://clubelo.com/Ranking',
            'bracket_input_sha256': bracket['input_sha256'] if drawn else None,
            'coefficient_source_url': coefficient_data['source_url'], 'limitations': report['limitations'],
            'validation': report['validation']['metrics'], 'teams': {str(t): {
                'elo': elos[t], 'event': TITLE_EVENTS[competition_id], **estimates[t]} for t in teams}}
        run['input_sha256'] = common.input_fingerprint(league, {'elos': elos, 'discipline': discipline,
            'coefficients': {str(t): coefficient_data['teams'][str(t)] for t in teams},
            'bracket_input_sha256': run['bracket_input_sha256']})
        runs.append(run)
        statuses.append({'season_id': season_id, 'status': 'updated', 'teams': len(teams)})
    return runs, statuses


def refresh(*, apply=False, histories=None, simulations=100000, seed=20260917, brackets=None):
    report, fixtures = common.latest_model(MODEL_METHOD), cup_betting_loader.read_fixtures()
    current = [f for f in fixtures if f['competition_id'] in EUROPE_COMPETITION_IDS and f['season_name']=='2026/2027']
    if brackets is None:
        from ..core.db_json import decoded
        brackets = [decoded(r['payload']) for r in common._fetch("""SELECT b.payload FROM tournament_brackets b
            JOIN seasons s ON s.season_id=b.season_id WHERE s.is_current=1 AND s.competition_id IN (2,5,2286)""")]
    if histories is None:
        ids = {f[k] for f in current if f['stage_type_id']==223 for k in ('home_team_id','away_team_id')}
        histories = common.refresh_histories(common.read_clubelo_mapping(ids), apply=apply)
    raw = read_card_fixtures(current)
    runs, statuses = prepare_runs(current, histories, report, raw, observed_at=datetime.now(timezone.utc),
                                  simulations=simulations, seed=seed, brackets=brackets)
    if apply and runs:
        common.store_runs(runs)
    return {'applied': apply, 'competitions': statuses}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('train', 'refresh'))
    parser.add_argument('--input-json', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--simulations', type=int, default=100000)
    parser.add_argument('--seed', type=int, default=20260917)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args(argv)
    if args.command == 'refresh':
        result = refresh(apply=args.apply, simulations=args.simulations, seed=args.seed)
    else:
        if args.input_json:
            if args.apply:
                raise ValueError('Offline inputs are only for read-only validation')
            source = common._read(args.input_json)
            fixtures, histories, raw = source['fixtures'], defaultdict(list), source['card_fixtures']
            for row in source['ratings']:
                histories[row['team_id']].append({'date': str(row['rating_date']), 'elo': row['elo']})
        else:
            fixtures, histories = read_fixtures(), common.read_histories()
            raw = read_card_fixtures([f for f in fixtures if f['season_name'] in MODEL_SEASONS])
        result = train_and_validate(build_dataset(fixtures, histories, raw))
        if args.apply:
            common.store_model(result)
    if args.output:
        args.output.write_text(common._dump(result)+'\n', encoding='utf-8')
    print(common._dump({k: v for k, v in result.items() if k not in ('forecast_model','excluded_cards')}))


if __name__ == '__main__':
    main()
