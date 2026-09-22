"""컵 대회의 대진·합산 진출팀·다음 라운드 연결을 같은 규칙으로 만들어요."""
from collections import defaultdict
import hashlib
import json

from .betting import match_outcome
from .cup_betting import CUP_COMPETITION_IDS, EUROPE_COMPETITION_IDS, utc_datetime
from .fixture_scores import CURRENT_SCORE_TYPE_ID, PENALTY_SCORE_TYPE_ID, score_pair
from .fixture_states import COMPLETED_STATE_IDS, LIVE_STATE_IDS


STAGE_ALIASES = {
    'Preliminary Round': 'preliminary', 'Knockout Round Play-offs': 'playoff',
    'Round 1': 'round1', '1st Round': 'round1', 'Round 2': 'round2', '2nd Round': 'round2',
    'Round 3': 'round3', '3rd Round': 'round3', 'Round 4': 'round4', '4th Round': 'round4',
    '5th Round': 'round5', 'Round of 32': 'round32', '16th Finals': 'round32',
    'Round of 16': 'round16', '8th Finals': 'round16',
    'Quarter-finals': 'quarterfinal', 'Quarterfinals': 'quarterfinal',
    'Semi-finals': 'semifinal', 'Final': 'final',
}
EUROPE_STAGES = ('playoff', 'round16', 'quarterfinal', 'semifinal', 'final')
STAGE_ORDER = {
    **dict.fromkeys(EUROPE_COMPETITION_IDS, EUROPE_STAGES),
    24: ('round1', 'round2', 'round3', 'round4', 'round5', 'quarterfinal', 'semifinal', 'final'),
    27: ('preliminary', 'round1', 'round2', 'round3', 'round16', 'quarterfinal', 'semifinal', 'final'),
    390: ('preliminary', 'round1', 'round2', 'round16', 'quarterfinal', 'semifinal', 'final'),
    570: ('preliminary', 'round1', 'round2', 'round32', 'round16', 'quarterfinal', 'semifinal', 'final'),
}


def stage_key(competition_id, stage):
    if competition_id in EUROPE_COMPETITION_IDS and stage['type_id'] != 224:
        return None
    # FA컵 예선 재경기가 type_id=224로 오는 실제 응답이 있어 단계 이름도 확인해요.
    if competition_id == 24 and ('Qualifying' in stage['name'] or 'Preliminary' in stage['name']):
        return None
    key = STAGE_ALIASES.get(stage['name'])
    if competition_id == 27 and key == 'round4':
        key = 'round16'
    if key not in STAGE_ORDER[competition_id]:
        raise ValueError(f"Unverified bracket stage: {competition_id}/{stage['name']}")
    return key


def _participant_key(slot):
    if slot['team_id'] is not None:
        return ('team', slot['team_id'])
    # 코파 이탈리아의 준결승은 팀 대신 'Winner Quarter-final 1' 같은 이름을 제공해요.
    # 이름까지 같은 TBC끼리는 어느 대진인지 확인할 수 없으므로 묶지 않아요.
    if slot['label'].startswith('Winner '):
        return ('placeholder', slot['label'])
    return None


def _normalize(raw, teams, available_ids):
    participants = {p['meta']['location']: p for p in raw['participants']}
    slots = []
    for side in ('home', 'away'):
        p = participants[side]
        team_id = None if p['placeholder'] else p['id']
        if team_id is not None:
            teams[str(team_id)] = {'team_id': team_id, 'name': p['name'],
                                  'short_code': p['short_code'], 'logo': p['image_path']}
        slots.append({'slot': side, 'team_id': team_id, 'label': p['name'], 'source_tie_id': None})
    home, away = [s['team_id'] for s in slots]
    score, penalties = (None, None), (None, None)
    if home is not None and away is not None:
        if home == away:
            raise ValueError('A bracket fixture has the same team on both sides')
        score = score_pair(raw, home, away, CURRENT_SCORE_TYPE_ID)
        penalties = score_pair(raw, home, away, PENALTY_SCORE_TYPE_ID)
    leg = raw['leg']
    # 2025/26 예비 라운드는 처음으로 2차전제였지만 공급사는 20경기를 모두 1/1로 줬어요.
    # RFEF가 발표한 9/27 1차전·10/4 2차전 일정과 대조한 경기만 바로잡아요.
    # https://rfef.es/es/noticias/el-sueno-para-los-20-equipos-de-la-previa-ya-tiene-horarios
    if raw['season_id'] == 26557 and 19583084 <= raw['id'] <= 19583103:
        leg = '1/2' if raw['id'] <= 19583093 else '2/2'
    return {'fixture_id': raw['id'], 'home_team_id': home, 'away_team_id': away,
            'home_score': score[0], 'away_score': score[1],
            'home_penalty_score': penalties[0], 'away_penalty_score': penalties[1],
            'starting_at': utc_datetime(raw['starting_at']).isoformat() if raw['starting_at'] else None,
            'state_id': raw['state_id'], 'state': raw['state']['developer_name'],
            'leg': leg, 'source_leg': raw['leg'], 'detail_available': raw['id'] in available_ids,
            'slots': slots, 'aggregate_id': raw['aggregate_id'],
            'aggregate_winner': (raw['aggregate'] or {}).get('winner_participant_id')}


def _tie(fixtures, stage_id, key, issues):
    fixtures.sort(key=lambda f: (f['leg'], f['fixture_id']))
    first = fixtures[0]
    tie_id = f"fixture:{min(f['fixture_id'] for f in fixtures)}"
    slots = first['slots']
    expected = 1 if first['leg'] == '1/1' else 2
    complete_legs = [f['leg'] for f in fixtures] == (['1/1'] if expected == 1 else ['1/2', '2/2'])
    if not complete_legs:
        issues.append({'code': 'incomplete_legs', 'tie_id': tie_id})
    if len(fixtures) > 1:
        identities = [tuple(_participant_key(s) for s in f['slots']) for f in fixtures]
        if (len(fixtures) != 2 or identities[0] != identities[1][::-1]
                or (None in identities[0] and any(f['aggregate_id'] is None for f in fixtures))):
            raise ValueError(f'Conflicting two-leg participants: {tie_id}')
    winner, basis, totals = None, None, None
    completed = complete_legs and all(f['state_id'] in COMPLETED_STATE_IDS for f in fixtures)
    participants = [s['team_id'] for s in slots]
    if completed and None not in participants:
        scores_present = all(f[k] is not None for f in fixtures for k in ('home_score', 'away_score'))
        if scores_present:
            totals = [sum(f[f'{side}_score'] for f in fixtures for side in ('home', 'away')
                          if f[f'{side}_team_id'] == team) for team in participants]
            if expected == 1:
                outcome = match_outcome(first, draw_allowed=False)
                winner = home_or_away(first, outcome)
                basis = 'match_result' if winner is not None else None
            else:
                # 2차전의 경기 승자가 아니라 합산 점수·승부차기로 진출팀을 정해요.
                if totals[0] != totals[1]:
                    winner = participants[int(totals[1] > totals[0])]
                    basis = 'aggregate_score'
                else:
                    last = fixtures[-1]
                    hp, ap = last['home_penalty_score'], last['away_penalty_score']
                    if hp is not None and ap is not None and hp != ap:
                        winner = last['home_team_id'] if hp > ap else last['away_team_id']
                        basis = 'penalties'
        official = {f['aggregate_winner'] for f in fixtures if f['aggregate_winner'] in participants}
        if len(official) > 1 or (official and winner is not None and winner not in official):
            raise ValueError(f'Aggregate winner conflicts with scores: {tie_id}')
        if winner is None and official:
            winner, basis = official.pop(), 'provider_aggregate'
    legs = [{k: v for k, v in f.items() if k not in ('slots', 'aggregate_winner')} for f in fixtures]
    return {'tie_id': tie_id, 'stage_id': stage_id, 'stage_key': key,
            'format': 'single_match' if expected == 1 else 'two_leg', 'legs_complete': complete_legs,
            'slots': slots, 'fixtures': legs, 'aggregate_score': totals if expected == 2 else None,
            'winner_team_id': winner, 'winner_basis': basis,
            'status': 'completed' if winner is not None else 'live' if any(
                f['state_id'] in LIVE_STATE_IDS for f in fixtures) else 'unresolved' if completed else 'scheduled',
            'next_tie_id': None}


def home_or_away(fixture, outcome):
    return fixture['home_team_id'] if outcome == 'home_win' else fixture['away_team_id'] if outcome == 'away_win' else None


def build_bracket(*, competition_id, season_id, season_name, fixtures, fetched_at,
                  available_fixture_ids=(), provider_edges=()):
    if competition_id not in CUP_COMPETITION_IDS:
        raise ValueError('Unsupported bracket competition')
    # FA컵 본선 재경기·예전 원정 다득점을 현재 시즌 규칙으로 계산하지 않아요.
    if int(season_name[:4]) < 2024:
        raise ValueError('Brackets support seasons from 2024/2025')
    stages, teams, issues, seen = {}, {}, [], set()
    available = set(available_fixture_ids)
    for raw in fixtures:
        if raw['season_id'] != season_id or raw['league_id'] != competition_id:
            raise ValueError('Fixture does not belong to the requested season')
        if raw['id'] in seen:
            raise ValueError('Duplicate bracket fixture')
        seen.add(raw['id'])
        key = stage_key(competition_id, raw['stage'])
        if key is None:
            continue
        stage = stages.setdefault(raw['stage_id'], {'stage_id': raw['stage_id'], 'key': key,
            'name': raw['stage']['name'], 'order': STAGE_ORDER[competition_id].index(key), 'raw': []})
        if raw['leg'] not in ('1/1', '1/2', '2/2'):
            raise ValueError('Unverified bracket leg format')
        stage['raw'].append(_normalize(raw, teams, available))
    # 2026/27 코파 이탈리아는 Final의 sort_order가 1이에요. 검증한 단계 순서를 사용해요.
    ordered = sorted(stages.values(), key=lambda s: s['order'])
    if len({s['order'] for s in ordered}) != len(ordered):
        raise ValueError('Ambiguous bracket stage order')
    for stage in ordered:
        groups = defaultdict(list)
        for f in stage.pop('raw'):
            ids = tuple(_participant_key(s) for s in f['slots'])
            group = ('fixture', f['fixture_id'])
            if f['leg'] != '1/1':
                if f['aggregate_id'] is not None:
                    group = ('aggregate', f['aggregate_id'])
                elif None not in ids and ids[0] != ids[1]:
                    group = ('participants', tuple(sorted(ids)))
            groups[group].append(f)
        stage['ties'] = sorted((_tie(fs, stage['stage_id'], stage['key'], issues) for fs in groups.values()),
                               key=lambda t: t['tie_id'])
    ties = {t['tie_id']: t for s in ordered for t in s['ties']}
    fixture_ties = {f['fixture_id']: t for t in ties.values() for f in t['fixtures']}
    edges = []

    def connect(parent, child, slot, source):
        if (parent['next_tie_id'] not in (None, child['tie_id'])
                or slot['source_tie_id'] not in (None, parent['tie_id'])
                or (parent['next_tie_id'] is not None and slot['source_tie_id'] != parent['tie_id'])):
            raise ValueError('Conflicting bracket progression')
        if slot['source_tie_id'] is not None:
            return
        parent['next_tie_id'], slot['source_tie_id'] = child['tie_id'], parent['tie_id']
        edges.append({'from_tie_id': parent['tie_id'], 'to_tie_id': child['tie_id'],
                      'to_slot': slot['slot'], 'source': source})

    for previous, following in zip(ordered, ordered[1:]):
        if following['order'] != previous['order'] + 1:
            issues.append({'code': 'missing_stage', 'stage_id': previous['stage_id']})
            continue
        entrants = defaultdict(list)
        for child in following['ties']:
            for slot in child['slots']:
                if slot['team_id'] is not None:
                    entrants[slot['team_id']].append((child, slot))
        for parent in previous['ties']:
            if parent['winner_team_id'] is None and parent['legs_complete'] and all(
                    f['state_id'] in COMPLETED_STATE_IDS for f in parent['fixtures']):
                advanced = [s['team_id'] for s in parent['slots'] if s['team_id'] in entrants]
                if len(advanced) == 1 and len(entrants[advanced[0]]) == 1:
                    parent.update(winner_team_id=advanced[0], winner_basis='next_round_entry', status='completed')
            matches = entrants.get(parent['winner_team_id'], [])
            if len(matches) == 1:
                connect(parent, *matches[0], 'results')
            elif len(matches) > 1:
                raise ValueError('Winner appears in multiple next-round ties')

    for edge in provider_edges:
        if edge['parent_outcome'] != 'winner':
            raise ValueError('Only winner progression is supported in these competitions')
        parent, child = fixture_ties[edge['parent_fixture_id']], fixture_ties[edge['child_fixture_id']]
        if STAGE_ORDER[competition_id].index(child['stage_key']) != STAGE_ORDER[competition_id].index(parent['stage_key']) + 1:
            raise ValueError('Provider edge skips or reverses a stage')
        leg = next(f for f in child['fixtures'] if f['fixture_id'] == edge['child_fixture_id'])
        side = edge['child_slot']
        if side not in ('home', 'away'):
            raise ValueError('Invalid child slot')
        # API 슬롯은 1차전 기준이에요. 공급사가 2차전 슬롯을 주면 반대로 연결해요.
        slot = child['slots'][int((side == 'away') != (leg['leg'] == '2/2'))]
        if parent['winner_team_id'] is not None and slot['team_id'] not in (None, parent['winner_team_id']):
            raise ValueError('Provider edge conflicts with confirmed entrant')
        connect(parent, child, slot, 'provider_bracket')
    final = next((s for s in ordered if s['key'] == 'final'), None)
    if final and len(final['ties']) != 1:
        raise ValueError('Ambiguous final')
    champion = final['ties'][0]['winner_team_id'] if final else None
    unresolved = [t['tie_id'] for t in ties.values() if t['stage_key'] != 'final' and t['next_tie_id'] is None]
    unknown_slots = any(s['team_id'] is None and s['source_tie_id'] is None for t in ties.values() for s in t['slots'])
    result = {'competition_id': competition_id, 'season_id': season_id, 'season_name': season_name,
              'scope': 'main_knockout' if competition_id in (*EUROPE_COMPETITION_IDS, 24) else 'cup',
              'source': 'sportmonks', 'fetched_at': utc_datetime(fetched_at).isoformat(),
              'status': 'not_published' if not ties else 'completed' if champion else 'in_progress',
              'path_status': 'complete' if final and not unresolved and not issues and not unknown_slots else 'partial' if ties else 'not_published',
              'champion_team_id': champion, 'stages': ordered, 'teams': teams, 'edges': edges,
              'unlinked_tie_ids': unresolved, 'issues': issues}
    # 수집 시각과 상세 화면 적재 여부는 경기·대진 변경 여부에 영향을 주지 않아요.
    fingerprint = json.loads(json.dumps(result))
    fingerprint.pop('fetched_at')
    for stage in fingerprint['stages']:
        for tie in stage['ties']:
            for fixture in tie['fixtures']:
                fixture.pop('detail_available')
    result['input_sha256'] = hashlib.sha256(json.dumps(fingerprint, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    return result
