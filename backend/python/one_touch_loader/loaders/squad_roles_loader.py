"""경기별 결장과 DB 원본을 읽고, 명시적으로 실행할 때만 현재 역할을 저장해요."""
from __future__ import annotations

from contextlib import closing, contextmanager, nullcontext
from datetime import date, datetime, timezone
import json
from pathlib import Path

from ..core.db import get_conn, transaction
from ..core.fixture_states import COMPLETED_STATE_IDS
from ..core.sportmonks import SportmonksClient
from ..core.squad_roles import calculate_squad_roles
from .team_squad_members_loader import BIG5_COMPETITION_IDS, SPORTMONKS_DUPLICATE_PLAYER_IDS


CALIBRATION_PATH = Path(__file__).parents[1] / 'core' / 'squad_role_calibration.json'


def read_squad_role_inputs(as_of: datetime, *, connection=None, current_only: bool = False,
                           team_ids: list[int] | None = None) -> dict:
    leagues = ','.join(map(str, BIG5_COMPETITION_IDS))
    completed = ','.join(map(str, COMPLETED_STATE_IDS))
    # 경기 저장 안에서는 같은 연결을 사용해 방금 바뀐 결과를 읽고 함께 확정해요.
    with (closing(get_conn()) if connection is None else nullcontext(connection)) as conn:
        if connection is None:
            conn.start_transaction(readonly=True, consistent_snapshot=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                cur.execute(f"SELECT DISTINCT name FROM seasons WHERE is_current=1 AND competition_id IN ({leagues})")
                names = [r['name'] for r in cur.fetchall()]
                if len(names) != 1:
                    raise ValueError('Current five-league seasons must share one season name')
                current = names[0]
                year = int(current[:4])
                training = [f'{y}/{y+1}' for y in range(year-5, year)]
                cur.execute(f"""
                    SELECT season_id,competition_id,name AS season_name,is_current
                    FROM seasons WHERE competition_id IN ({leagues}) AND name BETWEEN %s AND %s
                """, (current if current_only else training[0], current))
                seasons = cur.fetchall()
                if len(seasons) != (5 if current_only else 30):
                    raise ValueError('Five completed seasons and the current season are required for all five leagues')
                ids = ','.join(str(r['season_id']) for r in seasons)
                team_sql = ','.join(str(int(team)) for team in team_ids) if team_ids else None
                fixture_scope = f'AND (f.home_team_id IN ({team_sql}) OR f.away_team_id IN ({team_sql}))' if team_sql else ''
                roster_scope = f'AND sm.team_id IN ({team_sql})' if team_sql else ''
                lineup_scope = f'AND fl.team_id IN ({team_sql})' if team_sql else ''
                cur.execute(f"""
                    SELECT st.season_id,f.fixture_id,f.starting_at,f.home_team_id,f.away_team_id
                    FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
                    JOIN rounds r ON r.round_id=f.round_id
                    WHERE st.season_id IN ({ids}) AND f.state_id IN ({completed})
                      AND r.name REGEXP '^[0-9]+$' AND f.starting_at<=%s {fixture_scope}
                    ORDER BY f.starting_at,f.fixture_id
                """, (as_of,))
                fixtures = cur.fetchall()
                cur.execute(f"""
                    SELECT sm.season_id,sm.team_id,sm.player_id,p.date_of_birth,p.display_name
                    FROM team_squad_members sm JOIN players p ON p.player_id=sm.player_id
                    WHERE sm.season_id IN ({ids}) {roster_scope}
                """)
                roster = cur.fetchall()
                cur.execute(f"""
                    SELECT st.season_id,fl.fixture_id,fl.team_id,fl.player_id,fl.lineup_type_id,
                           fl.minutes_played,fl.rating,p.date_of_birth,p.display_name
                    FROM fixture_lineups fl JOIN fixtures f ON f.fixture_id=fl.fixture_id
                    JOIN stages st ON st.stage_id=f.stage_id JOIN rounds r ON r.round_id=f.round_id
                    JOIN players p ON p.player_id=fl.player_id
                    WHERE st.season_id IN ({ids}) AND f.state_id IN ({completed})
                      AND r.name REGEXP '^[0-9]+$' AND f.starting_at<=%s {lineup_scope}
                """, (as_of,))
                lineups = cur.fetchall()
                # 출전 시간이 빠진 교체 선수를 미출전 후보로 세지 않도록 교체 기록을 확인해요.
                cur.execute(f"""
                    SELECT fe.fixture_id,fe.team_id,fe.player_id,fe.related_player_id
                    FROM fixture_events fe JOIN fixture_event_types et ON et.event_type_id=fe.event_type_id
                    JOIN fixtures f ON f.fixture_id=fe.fixture_id JOIN stages st ON st.stage_id=f.stage_id
                    WHERE st.season_id IN ({ids}) AND et.code='substitution' AND f.starting_at<=%s
                """, (as_of,))
                substitutions = cur.fetchall()
                player_ids = sorted({r['player_id'] for r in roster + lineups})
                player_sql = ','.join(map(str, player_ids)) or 'NULL'
                cur.execute(f"""
                    SELECT tr.transfer_id,tr.player_id,tr.from_team_id,tr.to_team_id,tr.type_id,tr.transfer_date,
                           ft.name AS from_team_name,ft.image_path AS from_team_image,
                           tt.name AS to_team_name,tt.image_path AS to_team_image
                    FROM transfers tr LEFT JOIN teams ft ON ft.team_id=tr.from_team_id
                    LEFT JOIN teams tt ON tt.team_id=tr.to_team_id
                    WHERE tr.transfer_date<=%s AND tr.player_id IN ({player_sql}) ORDER BY tr.transfer_date,tr.transfer_id
                """, (as_of.date(),))
                transfers = cur.fetchall()
        finally:
            if connection is None:
                conn.rollback()
    return dict(as_of=as_of, current_season=current, training_seasons=training, seasons=seasons,
                fixtures=fixtures, roster=roster, lineups=lineups, substitutions=substitutions,
                transfers=transfers)


def collect_fixture_absences(fixtures: list[dict], *, client=None, progress=None) -> list[dict]:
    client = client or SportmonksClient()
    result = []
    for offset in range(0, len(fixtures), 50):
        batch = fixtures[offset:offset+50]
        payloads = client.get_fixtures_batch([f['fixture_id'] for f in batch], include='sidelined.sideline')
        for fixture, payload in zip(batch, payloads):
            if payload['id'] != fixture['fixture_id']:
                raise ValueError('Absence fixture ID does not match the requested fixture')
            absences = []
            for item in payload['sidelined']:
                sideline = item['sideline']
                if (item['fixture_id'] != fixture['fixture_id']
                        or item['participant_id'] not in (fixture['home_team_id'], fixture['away_team_id'])
                        or sideline is None or item['sideline_id'] != sideline['id']
                        or (item['player_id'] is not None and item['player_id'] != sideline['player_id'])):
                    raise ValueError(f"Unverified absence identity in fixture {fixture['fixture_id']}")
                # 18538184는 바깥 선수 ID가 NULL이에요. 연결된 결장 ID의 원기록을 사용해요.
                # 18155726처럼 부상 원기록의 팀이 달라도, 경기별 참가팀을 소속 판단에 사용해요.
                player_id = sideline['player_id']
                absences.append(dict(team_id=item['participant_id'],
                                     player_id=SPORTMONKS_DUPLICATE_PLAYER_IDS.get(player_id, player_id),
                                     category=sideline['category'], sideline_id=sideline['id'],
                                     start_date=date.fromisoformat(sideline['start_date'])
                                     if sideline.get('start_date') is not None else None,
                                     end_date=date.fromisoformat(sideline['end_date'])
                                     if sideline.get('end_date') is not None else None))
            result.append(dict(fixture_id=fixture['fixture_id'], absences=absences))
        if progress:
            progress(min(offset+50, len(fixtures)), len(fixtures))
    return result


def save_current_squad_roles(rows: list[dict], *, connection=None) -> int:
    if not rows:
        return 0
    # UPDATE executemany는 선수마다 왕복해 초기 2,596명 저장에 수분이 걸려요. 같은 갱신을 한 문장으로 보내요.
    first = 'SELECT %s AS squad_role, %s AS team_id, %s AS season_id, %s AS player_id'
    values_sql = ' UNION ALL '.join([first] + ['SELECT %s,%s,%s,%s'] * (len(rows)-1))
    values = tuple(value for r in rows for value in (r['role'], r['team_id'], r['season_id'], r['player_id']))
    with (transaction() if connection is None else nullcontext(connection)) as conn:
        with conn.cursor() as cur:
            cur.execute(f"""
                UPDATE team_squad_members sm JOIN seasons s ON s.season_id=sm.season_id
                JOIN ({values_sql}) incoming ON incoming.team_id=sm.team_id
                  AND incoming.season_id=sm.season_id AND incoming.player_id=sm.player_id
                SET sm.squad_role=incoming.squad_role WHERE s.is_current=1
            """, values)
            return cur.rowcount


def _fixture_usage_snapshot(cur, fixture_id: int) -> tuple:
    cur.execute('SELECT state_id FROM fixtures WHERE fixture_id=%s', (fixture_id,))
    state = cur.fetchone()['state_id']
    cur.execute("""SELECT team_id, player_id, lineup_type_id, minutes_played, rating IS NULL AS missing_rating
        FROM fixture_lineups WHERE fixture_id=%s ORDER BY team_id, player_id""", (fixture_id,))
    lineups = cur.fetchall()
    cur.execute("""SELECT fe.team_id, fe.player_id, fe.related_player_id
        FROM fixture_events fe JOIN fixture_event_types et ON et.event_type_id=fe.event_type_id
        WHERE fe.fixture_id=%s AND et.code='substitution' ORDER BY fe.event_id""", (fixture_id,))
    return state, lineups, cur.fetchall()


def preview_squad_roles(*, connection=None, team_ids=None, as_of=None, recalibrate=False) -> dict:
    as_of = as_of or datetime.now(timezone.utc).replace(tzinfo=None)
    data = read_squad_role_inputs(as_of, connection=connection, current_only=not recalibrate, team_ids=team_ids)
    data['absences'] = collect_fixture_absences(data['fixtures'])
    model = None if recalibrate else json.loads(CALIBRATION_PATH.read_text(encoding='utf-8'))
    return calculate_squad_roles(data, model=model)


def refresh_current_squad_roles(*, connection=None, team_ids=None, as_of=None) -> dict:
    report = preview_squad_roles(connection=connection, team_ids=team_ids, as_of=as_of)
    report['updated_rows'] = save_current_squad_roles(report['players'], connection=connection)
    return report


@contextmanager
def refresh_squad_roles_after_fixture(connection, fixture_id: int, *,
                                       state_id: int | None = None, records_changed: bool = True):
    if not records_changed:
        yield
        return
    with connection.cursor(dictionary=True) as cur:
        completed = ','.join(map(str, COMPLETED_STATE_IDS))
        leagues = ','.join(map(str, BIG5_COMPETITION_IDS))
        # 두 팀의 현재 리그 역할만 갱신해요. 종료 취소도 기존 분모에서 경기를 빼야 해요.
        cur.execute(f"""SELECT f.home_team_id, f.away_team_id FROM fixtures f
            JOIN stages st ON st.stage_id=f.stage_id JOIN seasons s ON s.season_id=st.season_id
            JOIN rounds r ON r.round_id=f.round_id
            WHERE f.fixture_id=%s AND s.is_current=1 AND s.competition_id IN ({leagues})
              AND r.name REGEXP '^[0-9]+$'
              AND (f.state_id IN ({completed}) OR %s IN ({completed})) FOR UPDATE""", (fixture_id, state_id))
        scope = cur.fetchone()
        before = _fixture_usage_snapshot(cur, fixture_id) if scope is not None else None
        yield
        # 종료 후 반복 수신한 동일 명단은 공급자를 다시 조회하거나 역할을 다시 쓰지 않아요.
        if scope is not None and before != _fixture_usage_snapshot(cur, fixture_id):
            refresh_current_squad_roles(connection=connection,
                                        team_ids=sorted({scope['home_team_id'], scope['away_team_id']}))


def collect_squad_role_absences(data: dict, *, cache: dict | None = None,
                               refresh_training: bool = False, client=None, progress=None) -> tuple[list, dict]:
    cache = cache or {}
    previous = cache.get('historical_absences', {}) if (
        not refresh_training and cache.get('absence_cache_version') == 1
        and cache.get('current_season') == data['current_season']) else {}
    training_ids = {s['season_id'] for s in data['seasons'] if s['season_name'] in data['training_seasons']}
    history, records, pending = {}, {}, []
    fixture_keys = {}
    for fixture in data['fixtures']:
        fid = str(fixture['fixture_id'])
        key = [fixture['season_id'], fixture['home_team_id'], fixture['away_team_id'],
               fixture['starting_at'].isoformat()]
        fixture_keys[fid] = key
        saved = previous.get(fid)
        if fixture['season_id'] in training_ids and saved is not None and saved['fixture_key'] == key:
            # 현재 시즌은 매번 조회하고, 완료된 학습 시즌의 결장 응답만 재사용해요.
            record = dict(saved['record'], absences=[dict(row, **{
                field: date.fromisoformat(row[field]) if isinstance(row.get(field), str) else row.get(field)
                for field in ('start_date', 'end_date')}) for row in saved['record']['absences']])
            records[fid] = record
            history[fid] = {**saved, 'record': record}
        else:
            pending.append(fixture)
    reused = len(history)
    fetched = collect_fixture_absences(pending, client=client, progress=progress) if pending else []
    records.update({str(row['fixture_id']): row for row in fetched})
    for fixture in pending:
        fid = str(fixture['fixture_id'])
        if fixture['season_id'] in training_ids:
            history[fid] = dict(fixture_key=fixture_keys[fid], record=records[fid], checked_at=data['as_of'].isoformat())
    # 부상이 시즌 경계를 넘을 수 있어 과거·현재 응답을 함께 계산기에 넘겨요.
    absences = [records[str(f['fixture_id'])] for f in data['fixtures']]
    return absences, dict(absence_cache_version=1, current_season=data['current_season'],
                         historical_absences=history, historical_fixtures_reused=reused,
                         absence_fixtures_fetched=len(pending))
