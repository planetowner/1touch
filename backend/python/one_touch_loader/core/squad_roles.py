"""출전 가능한 리그 시간의 사용량으로 스쿼드 역할을 계산해요."""
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import date
from math import log

import numpy as np
from sklearn.mixture import GaussianMixture
from threadpoolctl import threadpool_limits

from .player_membership import build_club_history
from .transfer_source_rules import WITHHELD_PLAYER_MOVEMENTS


USAGE_ROLES = ('sporadic', 'rotation', 'important', 'crucial')
PROSPECT_MAX_AGE = 21
MODEL_SEED = 20260920


def age_at(birth_date: date, reference_date: date) -> int:
    return reference_date.year - birth_date.year - (
        (reference_date.month, reference_date.day) < (birth_date.month, birth_date.day))


def build_usage_rows(data: dict) -> list[dict]:
    seasons = {r['season_id']: r for r in data['seasons']}
    fixtures = {r['fixture_id']: r for r in data['fixtures'] if r['starting_at'] <= data['as_of']}
    by_team = defaultdict(list)
    for fixture in fixtures.values():
        for team in (fixture['home_team_id'], fixture['away_team_id']):
            by_team[(fixture['season_id'], team)].append(fixture)
    roster_keys = {(r['season_id'], r['team_id'], r['player_id']) for r in data['roster']}
    candidates = { (r['season_id'], r['team_id'], r['player_id']): r for r in data['roster'] }
    lineups, starters = {}, Counter()
    for row in data['lineups']:
        if row['fixture_id'] not in fixtures:
            continue
        lineups[(row['fixture_id'], row['team_id'], row['player_id'])] = row
        starters[(row['fixture_id'], row['team_id'])] += row['lineup_type_id'] == 11
        # 시즌 말 스쿼드에서 빠진 이적 선수도 그 구단에서 뛴 학습 표본에 포함해요.
        candidates.setdefault((row['season_id'], row['team_id'], row['player_id']), row)
    substituted = set()
    for event in data['substitutions']:
        for field in ('player_id', 'related_player_id'):
            substituted.add((event['fixture_id'], event['team_id'], event[field]))
    absences = defaultdict(set)
    injury_periods = defaultdict(dict)
    covered = set()
    for fixture in data['absences']:
        if fixture['fixture_id'] not in fixtures:
            continue
        covered.add(fixture['fixture_id'])
        for row in fixture['absences']:
            absences[(fixture['fixture_id'], row['team_id'], row['player_id'])].add(row['category'])
            if row['category'] == 'injury' and row.get('start_date') is not None:
                periods = injury_periods[(row['team_id'], row['player_id'])]
                start = row['start_date']
                confirmed_through = fixtures[fixture['fixture_id']]['starting_at'].date()
                if row.get('end_date') is not None:
                    confirmed_through = min(confirmed_through, row['end_date'])
                # 더 용처럼 경기별 연결이 빠져도, 같은 부상의 시작일부터 결장 확인일까지는 제외해요.
                # 종료일을 넘긴 연결도 있어, 종료일과 마지막 결장 확인일 중 이른 날까지만 사용해요.
                previous = periods.get(row['sideline_id'], (start, confirmed_through))
                periods[row['sideline_id']] = (start, max(previous[1], confirmed_through))
    movements = defaultdict(list)
    for row in data['transfers']:
        if row['transfer_date'] <= data['as_of'].date():
            movements[row['player_id']].append(row)
    teams = {team for _, team in by_team}
    spells = {player: build_club_history(sorted(rows, key=lambda r: (r['transfer_date'], r['transfer_id'])), teams)
              for player, rows in movements.items()}
    result = []
    for (season_id, team_id, player_id), player in sorted(candidates.items()):
        season = seasons[season_id]
        games = by_team[(season_id, team_id)]
        # 생일이 지난 선수의 유망주 판정은 시즌 시작일이 아닌 이번 계산일의 만 나이를 써요.
        age = age_at(player['date_of_birth'], data['as_of'].date()) if player['date_of_birth'] is not None else None
        item = dict(season_id=season_id, season_name=season['season_name'], competition_id=season['competition_id'],
                    team_id=team_id, player_id=player_id, player_name=player['display_name'],
                    current_roster=bool(season['is_current']) and (season_id, team_id, player_id) in roster_keys,
                    age=age, minutes_played=0, available_matches=0, excluded_matches=0,
                    injury_period_matches=0, lineup_absence_conflicts=0, usage_rate=None, unavailable_reason=None)
        own_spells = [s for s in spells.get(player_id, []) if s['team_id'] == team_id]
        if player_id in WITHHELD_PLAYER_MOVEMENTS or not own_spells:
            item['unavailable_reason'] = 'membership_unavailable'
        elif not games:
            item['unavailable_reason'] = 'no_completed_matches'
        for game in games if item['unavailable_reason'] is None else []:
            day = game['starting_at'].date()
            key = (game['fixture_id'], team_id, player_id)
            lineup = lineups.get(key)
            known = any(s['start_date'] is not None and s['start_date'] <= day
                        and (s['end_date'] is None or day < s['end_date']) for s in own_spells)
            unknown = any(s['start_date'] is None and (s['end_date'] is None or day < s['end_date'])
                          for s in own_spells)
            if unknown or (lineup is not None and not known):
                item['unavailable_reason'] = 'membership_dates_unavailable'
                break
            if not known:
                continue
            if game['fixture_id'] not in covered:
                item['unavailable_reason'] = 'absence_data_unavailable'
                break
            if starters[(game['fixture_id'], team_id)] != 11:
                item['unavailable_reason'] = 'incomplete_lineups'
                break
            categories = absences[key]
            if categories - {'injury', 'suspended', 'doubtful'}:
                item['unavailable_reason'] = 'absence_category_unavailable'
                break
            in_injury_period = any(start <= day <= end for start, end in
                                  injury_periods[(team_id, player_id)].values())
            unavailable = bool(categories & {'injury', 'suspended'}) or in_injury_period
            if unavailable and lineup is None:
                item['excluded_matches'] += 1
                item['injury_period_matches'] += int(in_injury_period and not categories & {'injury', 'suspended'})
                continue
            # 경기 전 결장 목록과 실제 명단이 겹치면, 실제 선발·벤치 명단을 우선해요.
            item['lineup_absence_conflicts'] += int(unavailable)
            item['available_matches'] += 1
            if lineup is not None:
                minutes = lineup['minutes_played']
                if minutes is None and (lineup['lineup_type_id'] == 11 or lineup['rating'] is not None or key in substituted):
                    item['unavailable_reason'] = 'minutes_unavailable'
                    break
                if minutes is not None and not 0 <= minutes <= 90:
                    item['unavailable_reason'] = 'invalid_minutes'
                    break
                item['minutes_played'] += minutes or 0
        item['available_minutes'] = 90 * item['available_matches']
        if item['unavailable_reason'] is None:
            if item['available_minutes']:
                item['usage_rate'] = item['minutes_played'] / item['available_minutes']
            else:
                item['unavailable_reason'] = 'no_available_matches'
        result.append(item)
    return result


def fit_usage_model(rows: list[dict]) -> dict:
    values = sorted(r['usage_rate'] for r in rows if r['usage_rate'] is not None)
    if len(set(values)) < 4:
        raise ValueError('At least four distinct verified usage rates are required')
    # 공통 분산을 쓰면 출전 비중이 늘 때 역할이 낮아지는 역전 없이 세 경계가 생겨요.
    with threadpool_limits(limits=1):
        model = GaussianMixture(n_components=4, covariance_type='tied',
                                n_init=10, max_iter=500, random_state=MODEL_SEED)
        model.fit(np.asarray(values).reshape(-1, 1))
    if not model.converged_:
        raise ValueError('Squad role GMM did not converge')
    order = np.argsort(model.means_[:, 0])
    means, weights = model.means_[order, 0], model.weights_[order]
    variances = np.repeat(model.covariances_[0, 0], 4)
    boundaries = []
    for i in range(3):
        boundary = (means[i]+means[i+1])/2 + variances[i]*log(weights[i]/weights[i+1])/(means[i+1]-means[i])
        boundaries.append(float(boundary))
    if not 0 < boundaries[0] < boundaries[1] < boundaries[2] < 1:
        raise ValueError('The fitted data does not support four ordered usage bands')
    return dict(method='four_component_gaussian_mixture', covariance_type='tied',
                means=means.tolist(), weights=weights.tolist(), variances=variances.tolist(),
                boundaries=boundaries, sample_count=len(values), seed=MODEL_SEED)


def classify_usage(row: dict, model: dict) -> dict:
    result = dict(row, role=None, probabilities=None)
    usage = row['usage_rate']
    if usage is None:
        return result
    means, weights, variances = [np.asarray(model[key]) for key in ('means', 'weights', 'variances')]
    scores = np.log(weights) - .5*np.log(variances) - .5*(usage-means)**2/variances
    probabilities = np.exp(scores-scores.max())
    probabilities /= probabilities.sum()
    role = USAGE_ROLES[int(np.argmax(probabilities))]
    if role == 'sporadic':
        if row['age'] is None:
            result['unavailable_reason'] = 'birth_date_unavailable'
            return result
        if row['age'] <= PROSPECT_MAX_AGE:
            role = 'prospect'
    result.update(role=role, probabilities=dict(zip(USAGE_ROLES, probabilities.tolist())))
    return result


def calculate_squad_roles(data: dict, *, model: dict | None = None) -> dict:
    rows = build_usage_rows(data)
    training = [r for r in rows if r['season_name'] in data['training_seasons']]
    if model is None:
        model = fit_usage_model(training)
        model.update(training_seasons=data['training_seasons'], applies_to_season=data['current_season'])
        # 시즌별 경계는 학습 안정성 진단이에요. 경기마다 과거 시즌을 다시 학습하지 않아요.
        stability = {season: fit_usage_model([r for r in training if r['season_name'] == season])
                     for season in data['training_seasons']}
    else:
        if model['applies_to_season'] != data['current_season']:
            raise ValueError('Recalibrate squad roles for the current season before applying them')
        stability = {}
    current = [classify_usage(r, model) for r in rows if r['current_roster']]
    return dict(as_of=data['as_of'].isoformat(), model=model, season_stability=stability,
                training_unavailable=dict(Counter(r['unavailable_reason'] for r in training if r['usage_rate'] is None)),
                role_counts=dict(Counter(r['role'] or 'unavailable' for r in current)),
                current_unavailable=dict(Counter(r['unavailable_reason'] for r in current if r['role'] is None)),
                players=current)
