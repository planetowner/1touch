"""계산 이력을 실행·팀 관계로 나누고 표시 정보는 원본에서 연결해요."""
from copy import deepcopy
from datetime import datetime, timezone
from .db_json import decoded


def split_run(run):
    metadata = {k: v for k, v in run.items() if k not in {'teams','model_id','season_id','as_of','competition_id','season_name'}}
    rows = []
    for key, value in sorted(run.get('teams', {}).items(), key=lambda item: int(item[0])):
        team = deepcopy(value)
        for field in ('team_id','team_name','short_code','cards'):
            team.pop(field, None)
        next_id = None
        if team.get('what_if'):
            fixture = team['what_if'].pop('fixture')
            next_id = fixture['fixture_id']
            team['what_if']['probabilities'] = fixture['probabilities']
        rows.append((int(key), next_id, team))
    return metadata, rows


TEAM_SELECT = '''SELECT tr.team_id,tr.next_fixture_id,tr.payload,t.name AS team_name,
    f.home_team_id,f.away_team_id,f.starting_at,rd.name AS round_name
    FROM probability_team_results tr JOIN teams t ON t.team_id=tr.team_id
    LEFT JOIN fixtures f ON f.fixture_id=tr.next_fixture_id LEFT JOIN rounds rd ON rd.round_id=f.round_id
    WHERE tr.run_id=%s'''


def restore_team(row):
    team = decoded(row['payload'])
    team.update(team_id=row['team_id'], team_name=row['team_name'])
    if team.get('what_if'):
        team['what_if']['fixture'] = {
            'fixture_id': row['next_fixture_id'], 'home_team_id': row['home_team_id'],
            'away_team_id': row['away_team_id'], 'starting_at': str(row['starting_at']),
            'round_name': row['round_name'], 'probabilities': team['what_if'].pop('probabilities'),
        }
    return team


def restore_run(row, teams):
    run = decoded(row['payload'])
    as_of = row['as_of']
    if isinstance(as_of, str):
        as_of = datetime.fromisoformat(as_of.replace('Z', '+00:00'))
    run.update(model_id=row['model_id'], season_id=row['season_id'], competition_id=row['competition_id'],
               season_name=row['season_name'], as_of=as_of.replace(tzinfo=timezone.utc).isoformat().replace('+00:00','Z'),
               teams={str(t['team_id']): restore_team(t) for t in teams})
    return run


def load_run(fetch, run_id, team_id=None):
    rows = fetch('''SELECT r.*,s.competition_id,s.name AS season_name
        FROM probability_runs r JOIN seasons s ON s.season_id=r.season_id WHERE run_id=%s''', (run_id,))
    if not rows:
        return None
    suffix, params = ('', (run_id,)) if team_id is None else (' AND tr.team_id=%s', (run_id, team_id))
    return restore_run(rows[0], fetch(TEAM_SELECT + suffix, params))
