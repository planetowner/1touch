"""컵 단일 경기의 최종 결과를 학습하고 경기 전 배당을 저장해요. 기본은 조회만 해요."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from dataclasses import asdict
from datetime import datetime, timedelta, timezone
import hashlib
from pathlib import Path

from ..core.betting import OPEN_STATE_IDS, SETTLEMENT_RULE, match_outcome, prediction_options
from ..core.clubelo import rating_before
from ..core.cup_betting import (CUP_COMPETITION_IDS, MODEL_METHOD, aggregate_index, fixture_context,
                               match_format, utc_datetime)
from ..core.fixture_states import COMPLETED_STATE_IDS
from ..core.probability import OUTCOMES, evaluate_wdl, fit_wdl
from .probability_loader import (_dump, _fetch, _read, latest_model, read_histories,
                                read_clubelo_mapping, refresh_histories, store_model, store_runs)
from .probability_training import MODEL_SEASONS, TRAIN_SEASONS, VALIDATION_SEASON, _baseline, _inputs


def read_fixtures():
    marks = ','.join('%s' for _ in CUP_COMPETITION_IDS)
    return _fetch(f'''SELECT f.fixture_id,f.home_team_id,f.away_team_id,f.starting_at,f.state_id,
        f.home_score,f.away_score,f.home_penalty_score,f.away_penalty_score,f.leg,f.aggregate_id,
        st.stage_type_id,st.name AS stage_name,s.competition_id,s.season_id,s.name AS season_name
        FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id JOIN seasons s ON s.season_id=st.season_id
        WHERE s.competition_id IN ({marks}) AND s.name IN ('2023/2024','2024/2025','2025/2026','2026/2027')
        ORDER BY f.starting_at,f.fixture_id''', CUP_COMPETITION_IDS)


def build_dataset(fixtures, histories):
    rows, excluded, seen = [], [], set()
    first_legs = aggregate_index(fixtures)
    for fixture in fixtures:
        if (fixture['competition_id'] not in CUP_COMPETITION_IDS or fixture['season_name'] not in MODEL_SEASONS
                or fixture['state_id'] not in COMPLETED_STATE_IDS):
            continue
        fixture_id = fixture['fixture_id']
        if fixture_id in seen:
            raise ValueError(f'Duplicate training fixture: {fixture_id}')
        seen.add(fixture_id)
        if fixture['starting_at'] is None:
            excluded.append({'fixture_id': fixture_id, 'reason': 'kickoff_unconfirmed'})
            continue
        kickoff = utc_datetime(fixture['starting_at'])
        context = match_format(fixture, first_legs, as_of=kickoff)
        reason = 'match_format_unavailable' if context is None else None
        outcome = match_outcome(fixture, draw_allowed=context['draw_allowed']) if context else None
        if context and outcome is None:
            reason = 'final_result_incomplete'
        ratings = [rating_before(histories.get(fixture[key], []), kickoff.date())
                   for key in ('home_team_id', 'away_team_id')]
        if reason is None and any(value is None for value in ratings):
            reason = 'missing_pre_match_elo'
        if reason:
            excluded.append({'fixture_id': fixture_id, 'reason': reason})
            continue
        rows.append({**fixture_context(fixture), **context, 'competition_id': fixture['competition_id'],
                     'season_name': fixture['season_name'], 'home_elo': ratings[0], 'away_elo': ratings[1],
                     'elo_difference': ratings[0] - ratings[1], 'outcome': OUTCOMES.index(outcome)})
    rows.sort(key=lambda row: (row['starting_at'], row['fixture_id']))
    return {'rows': rows, 'excluded': excluded}


def train_and_validate(dataset):
    rows = dataset['rows']
    training = [r for r in rows if r['season_name'] in TRAIN_SEASONS]
    validation = [r for r in rows if r['season_name'] == VALIDATION_SEASON]
    if (not training or not validation or any(r['season_name'] not in MODEL_SEASONS for r in rows)
            or max(r['starting_at'] for r in training) >= min(r['starting_at'] for r in validation)):
        raise ValueError('Validation requires a nonempty later season')
    model = fit_wdl(*_inputs(training), draw_allowed=[r['draw_allowed'] for r in training])
    metrics = evaluate_wdl(model, *_inputs(validation), draw_allowed=[r['draw_allowed'] for r in validation])
    baseline = evaluate_wdl(_baseline(training), *_inputs(validation),
                            draw_allowed=[r['draw_allowed'] for r in validation])
    refitted = fit_wdl(*_inputs(rows), draw_allowed=[r['draw_allowed'] for r in rows])
    data_hash = hashlib.sha256(_dump(rows).encode()).hexdigest()
    report = {
        'method': MODEL_METHOD, 'settlement_rule': SETTLEMENT_RULE, 'dataset_sha256': data_hash,
        'validation': {'training_seasons': TRAIN_SEASONS, 'training_fixtures': len(training),
                       'season': VALIDATION_SEASON, 'model': asdict(model), 'metrics': metrics,
                       'frequency_baseline': baseline},
        'forecast_model': {**asdict(refitted), 'training_seasons': MODEL_SEASONS, 'training_fixtures': len(rows),
                           'last_training_fixture_at': max(r['starting_at'] for r in rows),
                           'predict_from_season': '2026/2027'},
        'training_rows': rows, 'excluded': dataset['excluded'],
        'limitations': ['Only teams with verified historical Elo are included',
                        'Historical Elo was retrieved retrospectively',
                        'No separate neutral-venue, line-up or aggregate-margin feature'],
    }
    report['model_id'] = hashlib.sha256(_dump([MODEL_METHOD, SETTLEMENT_RULE, data_hash, refitted.coefficients]).encode()).hexdigest()
    return report


def prepare_runs(fixtures, histories, report, *, observed_at):
    if report['method'] != MODEL_METHOD or report['settlement_rule'] != SETTLEMENT_RULE:
        raise ValueError('A cup final-result model is required')
    if utc_datetime(report['forecast_model']['last_training_fixture_at']) >= observed_at:
        raise ValueError('The model must have been trained on past fixtures')
    first_legs, runs, excluded = aggregate_index(fixtures), {}, []
    for fixture in fixtures:
        if (fixture['competition_id'] not in CUP_COMPETITION_IDS or fixture['season_name'] != '2026/2027'
                or fixture['state_id'] not in OPEN_STATE_IDS or fixture['starting_at'] is None
                or utc_datetime(fixture['starting_at']) <= observed_at):
            continue
        context = match_format(fixture, first_legs, as_of=observed_at)
        reason = 'match_format_unavailable' if context is None else None
        # 오늘까지 관측한 전력만 써요. 미래 킥오프 날짜로 Elo를 조회하지 않아요.
        ratings = [rating_before(histories.get(fixture[key], []), observed_at.date() + timedelta(days=1))
                   for key in ('home_team_id', 'away_team_id')]
        if reason is None and any(value is None for value in ratings):
            reason = 'missing_pre_match_elo'
        run = runs.setdefault(fixture['season_id'], {
            'model_id': report['model_id'], 'season_id': fixture['season_id'],
            'as_of': observed_at.isoformat(), 'history_kind': 'observed_calculation',
            'market_kind': SETTLEMENT_RULE, 'fixture_markets': {}, 'teams': {},
        })
        if reason:
            excluded.append({'fixture_id': fixture['fixture_id'], 'reason': reason})
            continue
        run['fixture_markets'][str(fixture['fixture_id'])] = {
            'fixture': fixture_context(fixture), **context, 'home_elo': ratings[0], 'away_elo': ratings[1],
            'options': prediction_options(report['forecast_model']['coefficients'], *ratings,
                                          draw_allowed=context['draw_allowed']),
        }
    return list(runs.values()), excluded


def refresh(*, apply=False, histories=None):
    report, fixtures = latest_model(MODEL_METHOD), read_fixtures()
    team_ids = {f[key] for f in fixtures if f['season_name'] == '2026/2027'
                for key in ('home_team_id', 'away_team_id')}
    mapping = read_clubelo_mapping(team_ids)
    if histories is None:
        histories = refresh_histories(mapping, apply=apply)
    runs, excluded = prepare_runs(fixtures, histories, report, observed_at=datetime.now(timezone.utc))
    if apply and runs:
        store_runs(runs)
    return {'applied': apply, 'markets': sum(len(r['fixture_markets']) for r in runs),
            'excluded': excluded, 'source_teams': len(mapping)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('train', 'refresh'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--input-json', type=Path, help='읽기 전용으로 내보낸 경기·Elo를 로컬에서 검증해요.')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args(argv)
    if args.input_json and (args.apply or args.command != 'train'):
        parser.error('--input-json is only supported for read-only training')
    if args.command == 'refresh':
        print(_dump(refresh(apply=args.apply)))
        return
    if args.output is None:
        parser.error('train requires --output')
    if args.input_json:
        source, histories = _read(args.input_json), defaultdict(list)
        for row in source['ratings']:
            histories[row['team_id']].append({'date': row['rating_date'], 'elo': row['elo']})
        fixtures = source['fixtures']
    else:
        fixtures, histories = read_fixtures(), read_histories()
    report = train_and_validate(build_dataset(fixtures, histories))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(_dump(report), encoding='utf-8')
    if args.apply:
        store_model(report)
    print(_dump({'applied': args.apply, 'model_id': report['model_id'],
                 'training_fixtures': report['forecast_model']['training_fixtures'],
                 'validation': report['validation'],
                 'exclusions': dict(Counter(r['reason'] for r in report['excluded']))}))


if __name__ == '__main__':
    main()
