"""최근 분석·확률·하이라이트의 중복을 정리해요. 기본은 읽기 전용 점검이에요."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from one_touch_loader.core.highlight_storage import HIGHLIGHT_SELECT, candidate_from_row, write_candidates
from one_touch_loader.core.db_json import decoded
from one_touch_loader.core.highlights import utc_datetime
from one_touch_loader.core.probability_storage import split_run


SQL_ROOT = Path(__file__).resolve().parents[1] / 'one_touch_loader/sql'
OLD_TABLES = ('team_youtube_sources','team_youtube_playlists','team_highlights_cache',
              'probability_runs','clubelo_ratings','fixture_opta_shotmaps','fixture_opta_analyses','fixture_stat_types')
NEW_TABLES = ('highlight_channels','highlight_matches','highlight_videos','team_highlights','team_highlight_sync',
              'probability_team_results','clubelo_sources','fixture_opta_sources')


def query(connection, sql, params=()):
    with connection.cursor(dictionary=True) as cursor:
        cursor.execute(sql, params)
        return cursor.fetchall()


def load_plan(connection):
    old = {table: query(connection, f'SELECT * FROM {table}') for table in OLD_TABLES}
    sources = old['team_youtube_sources']
    if any(r['source_mode'] != 'verified_matches' or r['updated_at'] is None for r in sources):
        raise ValueError('Unmigrated YouTube source settings found')
    plan = {'checked': {r['team_id']: r['updated_at'] for r in sources}, 'candidates': {r['team_id']: [] for r in sources}}
    for row in old['team_highlights_cache']:
        if not row['match_key'] or not row['match_data'] or not row['video_data']:
            raise ValueError('Unverified highlight cache row found')
        value = {k: row[k] for k in ('video_id','title','thumbnail_url','published_at','source_type')}
        value.update(decoded(row['video_data']), match=decoded(row['match_data']))
        plan['candidates'][row['team_id']].append(value)
    opta_ids = {r['fixture_id']:r['external_fixture_id'] for r in query(connection, "SELECT fixture_id,external_fixture_id FROM fixture_external_ids WHERE provider='opta'")}
    plan['sources'] = {}
    for table in ('fixture_opta_shotmaps','fixture_opta_analyses'):
        for row in old[table]:
            fid, url = row['fixture_id'], row['source_url']
            if fid in plan['sources'] and plan['sources'][fid] != url:
                raise ValueError(f'Conflicting Opta source: {fid}')
            ids = parse_qs(urlparse(url).query)
            for parameter, column in (('matchId','external_fixture_id'),('competitionId','external_competition_id'),('seasonId','external_season_id')):
                if ids.get(parameter) != [row[column]]:
                    raise ValueError(f'Opta URL does not preserve identifiers: {fid}')
            if opta_ids.get(fid) != row['external_fixture_id']:
                raise ValueError(f'Missing Opta fixture relationship: {fid}')
            plan['sources'][fid] = url
    plan['elo_sources'] = {}
    mappings = {r['team_id']: r['external_team_id'] for r in query(connection, "SELECT team_id,external_team_id FROM team_external_ids WHERE provider='clubelo'")}
    for row in old['clubelo_ratings']:
        team = row['team_id']
        value = (row['source_sha256'], row['fetched_at'])
        if row['source_url'] != f'https://clubelo.com/{mappings[team]}' or (
                team in plan['elo_sources'] and plan['elo_sources'][team] != value):
            raise ValueError(f'Conflicting ClubElo source: {team}')
        plan['elo_sources'][team] = value
    plan['runs'] = []
    for row in old['probability_runs']:
        run = decoded(row['payload'])
        metadata, teams = split_run(run)
        if run['model_id'] != row['model_id'] or run['season_id'] != row['season_id']:
            raise ValueError(f'Probability header mismatch: {row["run_id"]}')
        plan['runs'].append((row['run_id'], metadata, teams))
    plan['stat_types'] = json.loads((SQL_ROOT.parent / 'core/player_stat_types.json').read_text(encoding='utf-8'))
    # 선수 통계 전체 행을 내려받지 않고 사전 누락 ID만 확인해요.
    missing = query(connection, '''SELECT DISTINCT p.stat_type_id FROM fixture_player_stats p
        LEFT JOIN fixture_stat_types t ON t.stat_type_id=p.stat_type_id WHERE t.stat_type_id IS NULL''')
    if {r['stat_type_id'] for r in missing} - {r['id'] for r in plan['stat_types']}:
        raise ValueError('Unverified player stat types found')
    plan['counts'] = {'team_video_links':len(old['team_highlights_cache']),
        'videos':len({r['video_id'] for r in old['team_highlights_cache']}),
        'matches':len({r['match_key'] for r in old['team_highlights_cache']}),
        'runs':len(plan['runs']), 'results':sum(len(teams) for _,_,teams in plan['runs']),
        'ratings':len(old['clubelo_ratings'])}
    return plan


def apply_plan(connection, plan):
    try:
        with connection.cursor() as cursor:
            write_candidates(cursor, list(plan['checked']), plan['candidates'], plan['checked'])
            cursor.executemany('INSERT INTO fixture_opta_sources (fixture_id,source_url) VALUES (%s,%s)', list(plan['sources'].items()))
            cursor.executemany('INSERT INTO clubelo_sources (team_id,source_sha256,fetched_at) VALUES (%s,%s,%s)',
                               [(team,*value) for team,value in plan['elo_sources'].items()])
            cursor.executemany('''INSERT INTO fixture_stat_types (stat_type_id,code,name) VALUES (%s,%s,%s)
                ON DUPLICATE KEY UPDATE code=VALUES(code),name=VALUES(name)''',
                [(r['id'],r['code'],r['name']) for r in plan['stat_types']])
            for run_id, metadata, teams in plan['runs']:
                for team_id, fixture_id, payload in teams:
                    cursor.execute('INSERT INTO probability_team_results (run_id,team_id,next_fixture_id,payload) VALUES (%s,%s,%s,%s)',
                                   (run_id,team_id,fixture_id,json.dumps(payload,ensure_ascii=False)))
                cursor.execute('UPDATE probability_runs SET payload=%s WHERE run_id=%s', (json.dumps(metadata,ensure_ascii=False),run_id))
        for key,table in (('team_video_links','team_highlights'),('videos','highlight_videos'),('matches','highlight_matches'),
                          ('runs','probability_runs'),('results','probability_team_results'),('ratings','clubelo_ratings')):
            count = query(connection, f'SELECT COUNT(*) AS n FROM {table}')[0]['n']
            if count != plan['counts'][key]:
                raise ValueError(f'Migration row count mismatch: {table}')
        # 행 수만 같고 값이 달라지는 이전은 허용하지 않아요. 기존 복사본을 지우기 전에 전부 대조해요.
        stored_runs = {r['run_id']: decoded(r['payload']) for r in query(connection, 'SELECT run_id,payload FROM probability_runs')}
        stored_results = {(r['run_id'],r['team_id']): (r['next_fixture_id'],decoded(r['payload']))
            for r in query(connection, 'SELECT * FROM probability_team_results')}
        for run_id, metadata, teams in plan['runs']:
            if stored_runs[run_id] != metadata or any(stored_results[run_id,team] != (fixture,payload) for team,fixture,payload in teams):
                raise ValueError(f'Probability values changed: {run_id}')
        def preserved_candidate(value):
            result = {k: value[k] for k in ('video_id','title','thumbnail_url','channel_id','channel_name',
                      'source_type','duration_seconds','region_restriction','embeddable')}
            result['published_at'] = utc_datetime(value['published_at'])
            # 이름은 ID가 가리키는 마스터로 통일하고 영상 선정에 사용한 값은 유지해요.
            result['match'] = {k: value['match'][k] for k in ('match_key','starting_at')}
            return result
        all_rows = query(connection, HIGHLIGHT_SELECT.replace('SELECT v.*', 'SELECT th.team_id,v.*')
                         .replace(' WHERE th.team_id=%s', ''))
        actual = {(r['team_id'],r['video_id']):preserved_candidate(candidate_from_row(r)) for r in all_rows}
        expected = {(team,v['video_id']):preserved_candidate(v) for team,values in plan['candidates'].items() for v in values}
        if actual != expected:
            raise ValueError('Highlight values changed during migration')
        connection.commit()
    except Exception:
        connection.rollback()
        raise


def verify_schema(connection, *, before):
    existing = {r['TABLE_NAME'] for r in query(connection, 'SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema=DATABASE()')}
    if before:
        if not set(OLD_TABLES) <= existing or set(NEW_TABLES) & existing:
            raise ValueError('Expected original schema; inspect a partial or previously completed migration before retrying')
    else:
        if not set(NEW_TABLES) <= existing or {'team_highlights_cache','team_youtube_sources','team_youtube_playlists'} & existing:
            raise ValueError('Incomplete relationship migration')
        for table, expected in (('clubelo_ratings',['team_id','rating_date','elo']),
                                ('fixture_opta_shotmaps',['fixture_id','collected_at']),
                                ('fixture_opta_analyses',['fixture_id','collected_at'])):
            columns = query(connection, 'SELECT COLUMN_NAME FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name=%s ORDER BY ordinal_position', (table,))
            if [r['COLUMN_NAME'] for r in columns] != expected:
                raise ValueError(f'Unexpected final columns: {table}')
        fks = query(connection, "SELECT constraint_name FROM information_schema.table_constraints WHERE table_schema=DATABASE() AND constraint_name='fk_fixture_player_stats_type'")
        if len(fks) != 1:
            raise ValueError('Player statistic type relationship is missing')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true')
    mode.add_argument('--verify', action='store_true', help='이전 후 스키마를 읽기 전용으로 확인해요.')
    args = parser.parse_args()
    from one_touch_loader.core.db import get_conn
    from diagnostics.run_minimal_migration import run_migration
    with get_conn() as connection:
        if args.verify:
            verify_schema(connection, before=False)
            print('Normalized schema verified. No data changed.')
            return
        verify_schema(connection, before=True)
        plan = load_plan(connection)
    print(json.dumps(plan['counts']), flush=True)
    if not args.apply:
        print('Read-only preflight complete. No operational data changed.')
        return
    # 기존 API와 수집 작업을 멈춘 상태에서 실행해야 변환 중 새 복사본이 생기지 않아요.
    def verify(*, before):
        with get_conn() as conn:
            verify_schema(conn, before=before)
    run_migration(name='recent_relations', tables=OLD_TABLES, sql_paths=(SQL_ROOT/'migrate_recent_relations.sql',),
                  verify_schema=verify, migrate_data=lambda conn: apply_plan(conn, plan),
                  finalize_sql_paths=(SQL_ROOT/'migrate_recent_relations_finalize.sql',))


if __name__ == '__main__':
    main()
