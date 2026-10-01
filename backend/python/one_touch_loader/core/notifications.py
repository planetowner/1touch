"""알림 종류별 입력만 나누고 설정·중복 식별·메시지 규칙은 함께 사용해요."""
from dataclasses import dataclass
from datetime import datetime, timedelta
import json
from pathlib import Path

from .fixture_states import COMPLETED_STATE_IDS
from .identity import canonical_sportmonks_player_id


DEFAULTS = {
    'community': {'post_reactions': True, 'post_comments': True},
    'team': {'new_bets': True, 'match_reminder': False, 'kickoff': True,
             'half_time': True, 'full_time': True, 'goal': True, 'substitution': False},
    'player': {'starting_xi': True, 'substitute': True, 'goal': True, 'assist': True,
               'yellow_card': False, 'red_card': False, 'injury': False},
}
KINDS = {
    'post_reaction': ('community', 'post_reactions'),
    'post_comment': ('community', 'post_comments'),
    **{f'team_{key}': ('team', key) for key in DEFAULTS['team']},
    **{f'player_{key}': ('player', key) for key in DEFAULTS['player']},
}


@dataclass(frozen=True)
class NotificationEvent:
    key: str
    kind: str
    subjects: tuple[int, ...]
    payload: dict
    expires_at: datetime
    fixture_id: int | None = None
    post_id: int | None = None
    comment_id: int | None = None
    actor_id: int | None = None

    @property
    def scope(self):
        return KINDS[self.kind][0]

    @property
    def setting(self):
        return KINDS[self.kind][1]


def fixture_events(fixture: dict, now: datetime) -> list[NotificationEvent]:
    """같은 공급자 이벤트는 다시 받아도 같은 알림 키를 만들어요."""
    fid = fixture['id']
    teams = {p['meta']['location']: p for p in fixture['participants']}
    names = {p['id']: p['name'] for p in fixture['participants']}
    base = {'home_team': teams['home']['name'], 'away_team': teams['away']['name'],
            'fixture_id': fid, 'destination': f'/match/{fid}'}
    result = []

    def add(kind, key, subjects, data):
        subjects = tuple(subject for subject in subjects if subject is not None)
        if kind.startswith('player_'):
            subjects = tuple(canonical_sportmonks_player_id(subject) for subject in subjects)
        if subjects:
            result.append(NotificationEvent(f'fixture:{fid}:{key}', kind, subjects,
                                            {**base, **data}, now + timedelta(minutes=5), fid))

    # 확정 명단만 선발 알림으로 보내요. 예상 명단과 경기 후 재수집은 제외해요.
    confirmed = any(m['type_id'] == 572 and m['values'].get('confirmed') is True
                    for m in fixture.get('metadata', []))
    if fixture['state_id'] in (1, 16) and confirmed:
        for lineup in fixture['lineups']:
            if lineup['type_id'] == 11 and lineup['player_id'] is not None:
                add('player_starting_xi', f"starting:{lineup['player_id']}", [lineup['player_id']],
                    {'player': lineup['player_name'], 'team': names[lineup['team_id']]})

    for event in fixture['events']:
        if event.get('rescinded') is True:
            continue
        key = f"event:{event['id']}"
        code = event['type']['code']
        data = {'team': names.get(event['participant_id'], ''), 'player': event['player_name'] or '',
                'minute': str(event['minute']) + (f"+{event['extra_minute']}" if event['extra_minute'] else ''),
                'score': event.get('result') or ''}
        if code in ('goal', 'owngoal', 'penalty'):
            add('team_goal', key + ':team_goal', [event['participant_id']], data)
            # 자책골·승부차기는 선수의 일반 득점·도움으로 알리지 않아요.
            if code != 'owngoal':
                add('player_goal', key + ':goal', [event['player_id']], data)
                if code == 'goal':
                    add('player_assist', key + ':assist', [event['related_player_id']],
                        {**data, 'player': event['related_player_name'] or ''})
        elif code == 'substitution':
            # Sportmonks와 기존 경기 화면에서 player는 투입, related_player는 교체 아웃이에요.
            add('team_substitution', key + ':team_sub', [event['participant_id']],
                {**data, 'in_player': event['player_name'] or '', 'out_player': event['related_player_name'] or ''})
            add('player_substitute', key + ':sub', [event['player_id']], data)
            if event.get('injured') is True:
                add('player_injury', key + ':injury', [event['related_player_id']],
                    {**data, 'player': event['related_player_name'] or ''})
        elif code in ('yellowcard', 'redcard', 'yellowredcard'):
            kind = 'player_yellow_card' if code == 'yellowcard' else 'player_red_card'
            add(kind, key + ':' + kind, [event['player_id']], data)
    return result


def state_event(fixture: dict, previous_state: int, now: datetime) -> NotificationEvent | None:
    current = fixture['state_id']
    kind = ('kickoff' if current == 2 and previous_state in (1, 16) else
            'half_time' if current == 3 and previous_state != 3 else
            'full_time' if current in COMPLETED_STATE_IDS and previous_state not in COMPLETED_STATE_IDS else None)
    if kind is None:
        return None
    teams = {p['meta']['location']: p for p in fixture['participants']}
    scores = {s['participant_id']: s['score']['goals'] for s in fixture['scores'] if s['type_id'] == 1525}
    home, away = teams['home'], teams['away']
    score = f"{scores[home['id']]}–{scores[away['id']]}" if home['id'] in scores and away['id'] in scores else ''
    fid = fixture['id']
    return NotificationEvent(f'fixture:{fid}:state:{kind}', 'team_' + kind, (home['id'], away['id']),
                             {'fixture_id': fid, 'home_team': home['name'], 'away_team': away['name'],
                              'score': score, 'destination': f'/match/{fid}'}, now + timedelta(minutes=5), fid)


# messages.dart의 번역 원본에서 생성한 파일을 배포에 포함해요.
_MESSAGE_TEMPLATES = json.loads(Path(__file__).with_name('notification_messages.json').read_text(encoding='utf-8'))['messages']
MATCH_REMINDER_LEAD_TIME = timedelta(hours=1)


def message(kind: str, data: dict, locale: str) -> dict:
    language = locale.replace('_', '-').split('-')[0].lower()
    if language not in ('ko', 'ja', 'zh'):
        language = 'en'
    arguments = {key: data.get(key, '') for key in ('home_team', 'away_team', 'team', 'player', 'minute',
                                                   'score', 'in_player', 'out_player', 'comment_preview')}
    arguments['author_name'] = data.get('display_name') or data.get('username', '')
    arguments['match'] = f"{arguments['home_team']} vs {arguments['away_team']}"
    arguments['minutes_until_kickoff'] = data.get('minutes_until_kickoff', int(MATCH_REMINDER_LEAD_TIME.total_seconds() // 60))
    return {part: template.format_map(arguments) for part, template in _MESSAGE_TEMPLATES[kind][language].items()}
