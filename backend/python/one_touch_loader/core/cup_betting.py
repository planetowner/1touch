"""컵 베팅의 경기 형식과 예측 입력을 한곳에서 정해요."""
from datetime import datetime, timezone

from .fixture_states import COMPLETED_STATE_IDS

CUP_COMPETITION_IDS = (2, 5, 2286, 24, 27, 390, 570)
EUROPE_COMPETITION_IDS = (2, 5, 2286)
MODEL_METHOD = 'cup_final_result_elo_v1'
SINGLE_ROUNDS = {
    '1st Round', '2nd Round', '3rd Round', '4th Round', '5th Round',
    'Round 1', 'Round 2', 'Round 3', 'Round 4', 'Round of 32', '16th Finals',
    'Round of 16', '8th Finals', 'Quarter-finals', 'Quarterfinals', 'Final',
}


def utc_datetime(value):
    parsed = value if isinstance(value, datetime) else datetime.fromisoformat(str(value).replace('Z', '+00:00'))
    return parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed.astimezone(timezone.utc)


def fixture_context(fixture):
    return {**{key: fixture[key] for key in (
        'fixture_id', 'home_team_id', 'away_team_id', 'stage_type_id', 'stage_name', 'leg', 'aggregate_id')},
        'starting_at': utc_datetime(fixture['starting_at']).isoformat()}


def aggregate_index(fixtures):
    index = {}
    for fixture in fixtures:
        if fixture['aggregate_id'] is not None and fixture['leg'] == '1/2':
            index.setdefault(fixture['aggregate_id'], []).append(fixture)
    return index


def match_format(fixture, first_legs, *, as_of):
    """확인된 형식만 반환해요. 2차전은 1차전이 끝나야 무승부 가능 여부를 알아요."""
    competition, stage = fixture['competition_id'], fixture['stage_name']
    leg = fixture['leg']
    if competition not in CUP_COMPETITION_IDS:
        return None
    if competition in EUROPE_COMPETITION_IDS and fixture['stage_type_id'] == 223:
        return {'draw_allowed': True, 'first_leg': None}
    if fixture['stage_type_id'] not in (224, 225):
        return None
    if competition in EUROPE_COMPETITION_IDS:
        single = stage in ('Final', 'Preliminary Round - Semi-finals', 'Preliminary Round - Final')
    elif competition == 24:
        if stage not in SINGLE_ROUNDS | {'Semi-finals', '3rd Round Replays', '4th Round Replays'}:
            return None
        single = True
    else:
        if stage not in SINGLE_ROUNDS | {'Semi-finals'}:
            return None
        single = stage != 'Semi-finals'
    if single:
        if leg != '1/1':
            return None
        # FA컵 본선 재경기는 2024/25부터 폐지됐어요. 과거 학습 결과도 당시 규칙을 따라요.
        replay_possible = competition == 24 and fixture['season_name'] == '2023/2024' and stage in (
            '3rd Round', '4th Round')
        return {'draw_allowed': replay_possible, 'first_leg': None}
    # 실제 UEFA 예선에 leg='1/1' 오기재가 있어 이 값만 보고 단판으로 판단하지 않아요.
    if leg == '1/2':
        return {'draw_allowed': True, 'first_leg': None}
    if leg != '2/2':
        return None
    candidates = first_legs.get(fixture['aggregate_id'], [])
    if len(candidates) != 1:
        return None
    first = candidates[0]
    if (first['season_id'] != fixture['season_id'] or
            first['home_team_id'] != fixture['away_team_id'] or first['away_team_id'] != fixture['home_team_id'] or
            first['state_id'] not in COMPLETED_STATE_IDS or
            first['home_score'] is None or first['away_score'] is None or
            utc_datetime(first['starting_at']) >= min(utc_datetime(fixture['starting_at']), as_of)):
        return None
    # 1차전 동점이면 2차전의 동점은 연장·승부차기로 해소돼요. 합산 승자를 베팅 결과로 쓰지는 않아요.
    return {'draw_allowed': first['home_score'] != first['away_score'],
            'first_leg': {key: first[key] for key in ('fixture_id', 'home_score', 'away_score')}}
