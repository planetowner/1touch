"""UEFA 본선의 남은 리그페이즈와 추첨 전 녹아웃을 같은 규칙으로 계산해요."""
from dataclasses import dataclass
import math

import numpy as np
from scipy.optimize import minimize
from scipy.special import expit, gammaln

from .cup_betting import EUROPE_COMPETITION_IDS
from .fixture_states import COMPLETED_STATE_IDS, LIVE_STATE_IDS, UPCOMING_STATE_IDS


MODEL_METHOD = 'european_title_poisson_elo_v1'
OUTCOME_KIND = 'european_title_v1'
LEAGUE_GAMES = {2: 8, 5: 8, 2286: 6}
TITLE_EVENTS = {2: 'ucl_winner', 5: 'uel_winner', 2286: 'uecl_winner'}


@dataclass(frozen=True)
class ScoreModel:
    coefficients: tuple[float, float, float]

    def rates(self, difference, *, neutral=False, minutes=90):
        intercept, home_effect, strength_effect = self.coefficients
        delta = np.asarray(difference, dtype=float) / 400
        venue = np.where(neutral, 0, home_effect / 2)
        return (np.exp(intercept + venue + strength_effect * delta) * minutes / 90,
                np.exp(intercept - venue - strength_effect * delta) * minutes / 90)


def fit_scores(differences, scores, neutral) -> ScoreModel:
    differences, scores = np.asarray(differences, dtype=float), np.asarray(scores, dtype=float)
    if scores.shape != (len(differences), 2) or not len(scores) or (scores < 0).any():
        raise ValueError('Paired nonnegative full-time scores are required')
    side = np.tile([1, -1], len(scores))
    design = np.column_stack((np.ones(scores.size),
                              np.repeat(~np.asarray(neutral, dtype=bool), 2) * side / 2,
                              np.repeat(differences / 400, 2) * side))
    observed = scores.reshape(-1)

    def loss_gradient(coefficients):
        log_rate = design @ coefficients
        rate = np.exp(log_rate)
        return float(np.mean(rate - observed * log_rate)), design.T @ (rate - observed) / len(observed)

    fitted = minimize(loss_gradient, np.zeros(3), jac=True, method='BFGS')
    if not fitted.success or not np.isfinite(fitted.x).all():
        raise ValueError(f'Score model did not converge: {fitted.message}')
    return ScoreModel(tuple(float(x) for x in fitted.x))


def score_loss(model, differences, scores, neutral):
    home, away = model.rates(differences, neutral=np.asarray(neutral))
    rates, scores = np.column_stack((home, away)), np.asarray(scores)
    return float(np.mean(np.sum(rates - scores * np.log(rates) + gammaln(scores + 1), axis=1)))


def fit_penalties(differences, home_wins):
    # 동전 던지기 순서가 없으므로 홈 절편은 두지 않고 양 팀을 바꾸면 확률도 뒤집히게 해요.
    x, y = np.asarray(differences) / 400, np.asarray(home_wins, dtype=float)
    if not len(x) or len(x) != len(y) or not set(y) <= {0, 1}:
        raise ValueError('Completed penalty shoot-outs are required')
    def loss_gradient(coefficient):
        logit = x * coefficient[0]
        return float(np.mean(np.logaddexp(0, logit) - y * logit)), np.array([np.mean((expit(logit) - y) * x)])
    fitted = minimize(loss_gradient, [0.0], jac=True, method='BFGS')
    if not fitted.success or not np.isfinite(fitted.x).all():
        raise ValueError('Penalty model did not converge')
    return float(fitted.x[0])


def disciplinary_points(events, team_ids):
    """선수·팀 관계자를 포함해 경고 1점, 퇴장 3점을 합산해요."""
    actors, seen, unidentified_yellows = {}, set(), set()
    for event in events:
        if event['id'] in seen:
            raise ValueError('Duplicate disciplinary event')
        seen.add(event['id'])
        if event.get('rescinded') or event['type_id'] not in (19, 20, 21):
            continue
        team = event['participant_id']
        if team not in team_ids:
            raise ValueError('Disciplinary event has no fixture participant')
        actor = (('coach', event['coach_id']) if event.get('coach_id') else
                 ('player', event['player_id']) if event.get('player_id') else
                 ('name', event['player_name']) if event.get('player_name') else ('event', event['id']))
        if actor[0] == 'event' and event['type_id'] == 19:
            unidentified_yellows.add(team)
        counts = actors.setdefault((team, actor), {19: 0, 20: 0, 21: 0})
        counts[event['type_id']] += 1
    totals = {team: 0 for team in team_ids}
    for (team, _), counts in actors.items():
        # 2024/25 원본에는 첫 경고의 대상이 비어 있는 경기가 있어요. 같은 사람인지 추측하지 않아요.
        if counts[21] and not counts[19] and team in unidentified_yellows:
            raise ValueError('Cannot link the first yellow card to the second-yellow dismissal')
        # 두 번째 경고 퇴장은 첫 경고를 포함해 3점이에요. 원본에 첫 경고가 없어도 3점으로 계산해요.
        totals[team] += (3 if counts[21] else counts[19]) + counts[20] * 3
    return totals


def coefficient_priority(team_ids, coefficients):
    keys = []
    for team in team_ids:
        row = coefficients[str(team)]
        annual = row['season_coefficients']
        if len(annual) != 5 or row['coefficient'] != max(sum(annual), row['association_floor']):
            raise ValueError('Invalid verified UEFA coefficient')
        # Annex D.8: 최근 시즌부터 비교하고, 협회 계수와 직전 국내 리그 순위를 적용해요.
        # 이 시즌 참가국의 협회 20% 하한은 서로 달라 원래 협회 계수의 비교 순서가 같아요.
        keys.append((row['coefficient'], *reversed(annual), row['association_floor'],
                     -row['domestic_position'] if row['domestic_position'] is not None else 0))
    if len(set(keys)) != len(keys):
        raise ValueError('UEFA coefficient tie needs the last domestic positions or an official decision')
    ordered = {key: position for position, key in enumerate(sorted(keys))}
    return np.array([ordered[key] for key in keys])


def league_order(points, goals_for, goals_against, away_goals, wins, away_wins,
                 discipline, opponents, coefficient):
    """Article 18의 열 가지 동률 기준을 순서대로 적용해요."""
    gd = goals_for - goals_against
    opposite_points, opposite_gd, opposite_goals = points @ opponents, gd @ opponents, goals_for @ opponents
    coefficient = np.broadcast_to(coefficient, points.shape)
    return np.lexsort((-coefficient, discipline, -opposite_goals, -opposite_gd, -opposite_points,
                       -away_wins, -wins, -away_goals, -goals_for, -gd, -points), axis=1)


def tie_winners(second_home, other, elos, model, penalty_coefficient, rng, *, final=False, played_margin=None):
    """진출팀은 합산 점수로 정해요. 개별 경기 베팅의 승자 규칙과 별개예요."""
    difference = elos[second_home] - elos[other]
    home_rate, away_rate = model.rates(difference, neutral=final)
    margin = rng.poisson(home_rate) - rng.poisson(away_rate)
    if played_margin is not None:
        margin += played_margin
    elif not final:
        # 1차전은 반대 팀의 홈이에요. 원정 다득점 규칙은 적용하지 않아요.
        first_home, first_away = model.rates(-difference)
        margin += rng.poisson(first_away) - rng.poisson(first_home)
    tied = margin == 0
    if tied.any():
        # 같은 포아송 득점 과정에서 연장 30분의 노출 시간을 사용해요.
        extra_home, extra_away = model.rates(difference[tied], neutral=final, minutes=30)
        margin[tied] = rng.poisson(extra_home) - rng.poisson(extra_away)
    tied = margin == 0
    if tied.any():
        probability = expit(penalty_coefficient * difference[tied] / 400)
        margin[tied] = np.where(rng.random(tied.sum()) < probability, 1, -1)
    return np.where(margin > 0, second_home, other)


def simulate_bracket_title(*, bracket, team_ids, elos, model, penalty_coefficient, simulations, seed):
    """확정된 경로와 종료 경기 결과를 유지하며 남은 UEFA 대진만 계산해요."""
    if bracket['competition_id'] not in EUROPE_COMPETITION_IDS or bracket['path_status'] != 'complete':
        raise ValueError('The verified knockout path through the final is required')
    if simulations < 1 or len(team_ids) != len(set(team_ids)):
        raise ValueError('Unique participants and a positive simulation count are required')
    if set(elos) != set(team_ids) or not np.isfinite(list(elos.values())).all():
        raise ValueError('Verified current Elo is required for every participant')
    index = {team: i for i, team in enumerate(team_ids)}
    strengths = np.array([elos[t] for t in team_ids])
    rng, winners = np.random.default_rng(seed), {}
    champion = None
    for stage in bracket['stages']:
        for tie in stage['ties']:
            if tie['winner_team_id'] is not None:
                winner = np.full(simulations, index[tie['winner_team_id']])
            else:
                if not tie['legs_complete']:
                    raise ValueError('The complete tie schedule is required')
                participants = []
                for slot in tie['slots']:
                    if slot['source_tie_id']:
                        values = winners[slot['source_tie_id']]
                        if slot['team_id'] is not None and not np.all(values == index[slot['team_id']]):
                            raise ValueError('An unresolved parent conflicts with a confirmed entrant')
                    elif slot['team_id'] is not None:
                        values = np.full(simulations, index[slot['team_id']])
                    else:
                        raise ValueError('An unresolved bracket slot has no verified parent')
                    participants.append(values)
                legs = tie['fixtures']
                if any(f['state_id'] not in (*COMPLETED_STATE_IDS, *UPCOMING_STATE_IDS, *LIVE_STATE_IDS) for f in legs):
                    raise ValueError('The knockout phase has a live or unresolved fixture')
                if legs[-1]['state_id'] in COMPLETED_STATE_IDS:
                    raise ValueError('A completed tie has no verified winner')
                final = stage['key'] == 'final'
                if tie['format'] != ('single_match' if final else 'two_leg'):
                    raise ValueError('Unverified UEFA knockout format')
                played_margin = None
                if len(legs) == 2 and legs[0]['state_id'] in COMPLETED_STATE_IDS:
                    first = legs[0]
                    if first['home_score'] is None or first['away_score'] is None:
                        raise ValueError('A completed first-leg score is missing')
                    played_margin = first['away_score'] - first['home_score']
                # 슬롯은 1차전 기준이므로 두 경기 대진의 2차전 홈은 두 번째 슬롯이에요.
                home, away = participants if final else participants[::-1]
                winner = tie_winners(home, away, strengths, model, penalty_coefficient, rng,
                                     final=final, played_margin=played_margin)
            winners[tie['tie_id']] = winner
            if stage['key'] == 'final':
                champion = winner
    if champion is None:
        raise ValueError('The final is missing')
    return title_estimates(team_ids, champion, simulations)


def title_estimates(team_ids, winner, simulations):
    counts = np.bincount(winner, minlength=len(team_ids))
    return {team: {'probability': float(counts[i] / simulations), 'wins': int(counts[i]),
                   'sampling_standard_error_pp': 100 * math.sqrt((counts[i] / simulations) * (1 - counts[i] / simulations) / simulations)}
            for i, team in enumerate(team_ids)}


def simulate_knockout(order, elos, model, penalty_coefficient, rng):
    n = len(order)
    sides = np.empty((n, 2, 24), dtype=int)
    # 각 순위 쌍의 두 팀은 추첨으로 서로 다른 브래킷 면에 배치돼요.
    for rank in range(0, 24, 2):
        flip = rng.integers(0, 2, size=n)
        sides[:, 0, rank] = order[np.arange(n), rank + flip]
        sides[:, 1, rank] = order[np.arange(n), rank + 1 - flip]
    finalists = []
    for side in (0, 1):
        # Annex B: 5/6-3/4와 7/8-1/2가 각각 8강에서 만나요.
        direct = sides[:, side, [4, 2, 6, 0]]
        seeded = sides[:, side, [10, 12, 8, 14]]
        unseeded = sides[:, side, [20, 18, 22, 16]]
        playoff = tie_winners(seeded, unseeded, elos, model, penalty_coefficient, rng)
        last16 = tie_winners(direct, playoff, elos, model, penalty_coefficient, rng)
        # 상위 시드 팀이 탈락해도 이 경로의 2차전 홈 권한은 승리 팀이 이어받아요.
        quarters = tie_winners(last16[:, [1, 3]], last16[:, [0, 2]], elos, model, penalty_coefficient, rng)
        finalists.append(tie_winners(quarters[:, 1], quarters[:, 0], elos, model, penalty_coefficient, rng))
    return tie_winners(finalists[0], finalists[1], elos, model, penalty_coefficient, rng, final=True)


def simulate_title(*, competition_id, team_ids, fixtures, elos, coefficients, discipline,
                   model, penalty_coefficient, card_samples, simulations, seed):
    if competition_id not in EUROPE_COMPETITION_IDS or len(team_ids) != 36 or len(set(team_ids)) != 36:
        raise ValueError('The complete UEFA league-phase membership is required')
    if simulations < 1:
        raise ValueError('A positive simulation count is required')
    index = {team: i for i, team in enumerate(team_ids)}
    if set(elos) != set(team_ids) or not np.isfinite(list(elos.values())).all():
        raise ValueError('Verified current Elo is required for every participant')
    opponents = np.zeros((36, 36), dtype=int)
    homes, aways = np.zeros(36, dtype=int), np.zeros(36, dtype=int)
    for fixture in fixtures:
        h, a = index[fixture['home_team_id']], index[fixture['away_team_id']]
        opponents[h, a] += 1
        opponents[a, h] += 1
        homes[h] += 1
        aways[a] += 1
    expected = LEAGUE_GAMES[competition_id] // 2
    if (not (homes == expected).all() or not (aways == expected).all()
            or (opponents > 1).any() or np.diag(opponents).any()
            or len({f['fixture_id'] for f in fixtures}) != len(fixtures)):
        raise ValueError('The complete verified UEFA league-phase schedule is required')
    cards = np.asarray(card_samples, dtype=int)
    if cards.ndim != 2 or cards.shape[1] != 2 or not len(cards) or (cards < 0).any():
        raise ValueError('Observed disciplinary point pairs are required')
    priority = coefficient_priority(team_ids, coefficients)
    rng = np.random.default_rng(seed)
    points, gf, ga, ag, wins, aw = [np.zeros((simulations, 36), dtype=int) for _ in range(6)]
    dp = np.zeros((simulations, 36), dtype=int)
    strengths = np.array([elos[t] for t in team_ids])
    for fixture in fixtures:
        h, a = index[fixture['home_team_id']], index[fixture['away_team_id']]
        if fixture['state_id'] == 5:
            if fixture['home_score'] is None or fixture['away_score'] is None:
                raise ValueError('A completed league-phase score is missing')
            home, away = np.full(simulations, fixture['home_score']), np.full(simulations, fixture['away_score'])
            observed = discipline[fixture['fixture_id']]
            hp, ap = observed[fixture['home_team_id']], observed[fixture['away_team_id']]
        elif fixture['state_id'] in (*UPCOMING_STATE_IDS, *LIVE_STATE_IDS):
            # 다른 경기의 종료 결과를 반영하되 진행 중 점수는 아직 확정하지 않아요.
            hr, ar = model.rates(strengths[h] - strengths[a])
            home, away = rng.poisson(hr, size=simulations), rng.poisson(ar, size=simulations)
            sampled = cards[rng.integers(0, len(cards), size=simulations)]
            hp, ap = sampled[:, 0], sampled[:, 1]
        else:
            raise ValueError('The league phase has a live or unresolved fixture')
        wh, wa, draw = home > away, home < away, home == away
        points[:, h] += wh * 3 + draw
        points[:, a] += wa * 3 + draw
        gf[:, h] += home
        gf[:, a] += away
        ga[:, h] += away
        ga[:, a] += home
        ag[:, a] += away
        wins[:, h] += wh
        wins[:, a] += wa
        aw[:, a] += wa
        dp[:, h] += hp
        dp[:, a] += ap
    order = league_order(points, gf, ga, ag, wins, aw, dp, opponents, priority)
    winner = simulate_knockout(order, strengths, model, penalty_coefficient, rng)
    return title_estimates(team_ids, winner, simulations)
