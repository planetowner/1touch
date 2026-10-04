"""현재 ClubElo와 기존 승무패 모델로 테스트 경기의 실제 배당을 계산해요."""
from datetime import timedelta, timezone
import hashlib
import json
from pathlib import Path

from one_touch_loader.core.betting import OPEN_STATE_IDS, SETTLEMENT_RULE, prediction_options
from one_touch_loader.core.clubelo import rating_before
from one_touch_loader.core.cup_betting import fixture_context, utc_datetime
from . import CLUBELO_TEAMS, COMPETITION_ID, SEASON_ID, SEASON_NAME, require_test_database

METHOD = 'live_test_laliga2_transferred_elo_v1'


def model_report():
    source = json.loads(Path(__file__).with_name('model.json').read_text())
    identifier = hashlib.sha256(f"{METHOD}:{source['model_id']}".encode()).hexdigest()
    return {**source, 'model_id': identifier, 'method': METHOD,
            'source_model_id': source['model_id'],
            'limitations': [*source['limitations'],
                           'Transferred from the Big Five model; La Liga 2 accuracy is not validated']}


def prepare_run(fixtures, histories, report, observed_at):
    if utc_datetime(report['forecast_model']['last_training_fixture_at']) >= observed_at:
        raise ValueError('The model contains results at or after the prediction time')
    run = {'model_id': report['model_id'], 'season_id': SEASON_ID,
           'as_of': observed_at.isoformat(), 'history_kind': 'observed_calculation',
           'market_kind': SETTLEMENT_RULE, 'fixture_markets': {}, 'teams': {}}
    excluded = []
    for fixture in fixtures:
        if (fixture['competition_id'], fixture['season_id'], fixture['season_name']) != (
                COMPETITION_ID, SEASON_ID, SEASON_NAME):
            raise ValueError('A fixture is outside the isolated test season')
        if (fixture['stage_type_id'] != 223 or fixture['state_id'] not in OPEN_STATE_IDS
                or fixture['starting_at'] is None or utc_datetime(fixture['starting_at']) <= observed_at):
            continue
        ratings = [rating_before(histories.get(fixture[key], []), observed_at.date() + timedelta(days=1))
                   for key in ('home_team_id', 'away_team_id')]
        if any(value is None for value in ratings):
            excluded.append(fixture['fixture_id'])
            continue
        run['fixture_markets'][str(fixture['fixture_id'])] = {
            'fixture': fixture_context(fixture), 'first_leg': None, 'draw_allowed': True,
            'home_elo': ratings[0], 'away_elo': ratings[1],
            'options': prediction_options(report['forecast_model']['coefficients'], *ratings),
        }
    # 시간이 지났다는 이유만으로 같은 배당 이력을 계속 쌓지 않아요.
    run['input_sha256'] = hashlib.sha256(json.dumps(
        run['fixture_markets'], sort_keys=True, allow_nan=False).encode()).hexdigest()
    return run, excluded


def refresh(*, apply=False):
    require_test_database()
    from datetime import datetime
    from one_touch_loader.api.repos.betting_repo import FIXTURE_SQL
    from one_touch_loader.loaders.probability_loader import (
        _fetch, latest_calculation_inputs, refresh_histories, store_model, store_run,
    )
    fixtures = _fetch(FIXTURE_SQL.replace('WHERE f.fixture_id=%s', 'WHERE st.season_id=%s'), (SEASON_ID,))
    histories = refresh_histories(CLUBELO_TEAMS, apply=apply)
    report = model_report()
    run, excluded = prepare_run(fixtures, histories, report, datetime.now(timezone.utc))
    previous = latest_calculation_inputs(SEASON_ID, METHOD)
    changed = previous is None or (previous['input_sha256'], previous['model_id']) != (
        run['input_sha256'], run['model_id'])
    if apply and changed:
        store_model(report)
        store_run(run)
    return {'apply': apply, 'changed': changed, 'markets': len(run['fixture_markets']),
            'missing_elo_fixture_ids': excluded, 'source_model_id': report['source_model_id']}
