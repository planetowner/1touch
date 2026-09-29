"""팀별 베팅 개방·한 시간 전 알림과 경기 전 확정 선발을 수집해요."""
from datetime import timedelta

from ..api.db import fetch_all_dict, transaction
from ..api.repos import betting_repo as betting, notifications_repo as notifications
from ..api.services.community_periods import utc_now
from ..core.notifications import NotificationEvent
from ..core.sportmonks import SportmonksClient
from .live_fixtures_loader import read_live_fixture_batches, store_live_fixture


def scheduled_events(fixture, now, prediction):
    start = fixture['starting_at']
    if start is None or fixture['state_id'] not in (1, 16) or start <= now:
        return []
    fid = fixture['fixture_id']
    payload = {'fixture_id': fid, 'starting_at': start.isoformat(), 'destination': f'/match/{fid}',
               'home_team': fixture['home_team_name'], 'away_team': fixture['away_team_name']}
    subjects = (fixture['home_team_id'], fixture['away_team_id'])
    events = []
    if betting.market_unavailable_reason(fixture, now, prediction) is None:
        events.append(NotificationEvent(f'fixture:{fid}:bets:{start.isoformat()}', 'team_new_bets',
                                        subjects, payload, start, fid))
    due = start - timedelta(hours=1)
    # 중단 후 경기가 임박해서 재개됐을 때 지난 1시간 전 알림을 뒤늦게 보내지 않아요.
    if due <= now < due + timedelta(minutes=5):
        events.append(NotificationEvent(f'fixture:{fid}:reminder:{start.isoformat()}', 'team_match_reminder',
                                        subjects, payload, due + timedelta(minutes=5), fid))
    return events


def run_schedule(*, apply=False):
    now = utc_now()
    rows = fetch_all_dict('''SELECT fixture_id FROM fixtures WHERE state_id IN (1,16)
        AND starting_at>%s AND starting_at<=%s ORDER BY fixture_id''', (now, now + timedelta(hours=24)))
    event_count = 0
    pregame = {}
    for item in rows:
        with transaction() as conn, conn.cursor(dictionary=True) as cur:
            fixture = notifications.read_one(cur, betting.FIXTURE_SQL + (' FOR UPDATE' if apply else ''), (item['fixture_id'],))
            cur.execute('SELECT team_id,name FROM teams WHERE team_id IN (%s,%s)', (fixture['home_team_id'], fixture['away_team_id']))
            names = {r['team_id']: r['name'] for r in cur.fetchall()}
            fixture.update(home_team_name=names[fixture['home_team_id']], away_team_name=names[fixture['away_team_id']])
            prediction = betting._prediction(lambda sql, params: notifications.read_one(cur, sql, params), fixture, now)
            events = scheduled_events(fixture, now, prediction)
            event_count += len(events)
            if apply:
                for event in events:
                    notifications.enqueue(cur, event, now)
            if fixture['starting_at'] is not None and now < fixture['starting_at'] <= now + timedelta(hours=1):
                pregame[fixture['fixture_id']] = fixture
    # livescores에는 시작 15분 전부터 나타나요. 한 시간 전 확정 명단은 같은 배치 API로 보충해요.
    client = SportmonksClient(timeout=20) if pregame else None
    lineups = 0
    # 응답을 기다리는 동안 다른 라이브 수집이 끝날 수 있어 요청 직전 시각으로 순서를 정해요.
    sampled_at = utc_now()
    for raw in read_live_fixture_batches(client, list(pregame)):
        payload = client.correct_fixture_details(raw)
        saved = pregame[payload['id']]
        lineups += len(payload['lineups'])
        if apply:
            store_live_fixture(payload, saved['home_team_id'], saved['away_team_id'], sampled_at, notify=True)
    return {'apply': apply, 'fixtures': len(rows), 'scheduled_candidates': event_count, 'lineups': lineups}
