"""선수 순위의 일별 마지막 상태를 보관해요. HTTP API는 이번에 바꾸지 않아요."""
import argparse
from contextlib import closing
from datetime import datetime, timezone
import json
from pathlib import Path

from ..core.cup_betting import utc_datetime
from ..core.player_rank_changes import compare_rankings, ranking_fingerprint
from ..core.player_ranking import season_player_positions
from ..core.player_rating_percentile import RATING_COMPETITION_IDS


LEAGUES = ','.join(map(str, RATING_COMPETITION_IDS))


def _fetch(cur, sql, params=()):
    cur.execute(sql, params)
    return cur.fetchall()


def current_ranking_inputs(cur, observed_at):
    seasons = _fetch(cur, f"""SELECT season_id,competition_id,name AS season_name FROM seasons
        WHERE is_current=1 AND competition_id IN ({LEAGUES}) ORDER BY competition_id""")
    if len(seasons) != len(RATING_COMPETITION_IDS) or {s['competition_id'] for s in seasons} != set(RATING_COMPETITION_IDS):
        raise ValueError('All five current league seasons are required for ranking history')
    names = {s['season_name'] for s in seasons}
    if len(names) != 1:
        raise ValueError('Current league seasons do not match')
    season_name = names.pop()
    rows = _fetch(cur, f"""SELECT sc.season_id,sc.competition_id,sc.player_id,sc.rating_sum,sc.rated_matches
        FROM player_rating_scores sc JOIN seasons s ON s.season_id=sc.season_id
        WHERE s.is_current=1 AND s.competition_id IN ({LEAGUES})
        ORDER BY sc.season_id,sc.player_id""")
    positions = season_player_positions(lambda sql, params: _fetch(cur, sql, params), season_name,
                                        utc_datetime(observed_at).replace(tzinfo=None))
    return season_name, [{**r, 'position': positions.get(r['player_id'])} for r in rows]


def capture_current_ranking(cur, *, observed_at=None):
    """호출자가 평점 공통 잠금을 잡고, 점수와 같은 트랜잭션에서 호출해요."""
    observed = utc_datetime(observed_at or datetime.now(timezone.utc))
    season_name, rows = current_ranking_inputs(cur, observed)
    day, stamp = observed.date(), observed.replace(tzinfo=None)
    fingerprint = ranking_fingerprint(season_name, rows)
    cur.execute('''SELECT snapshot_id,input_sha256 FROM player_ranking_snapshots
        WHERE season_name=%s AND snapshot_date=%s''', (season_name, day))
    existing = cur.fetchone()
    if existing and existing['input_sha256'] == fingerprint:
        # 같은 순위의 반복 수집은 행을 지우고 다시 쓰지 않고 마지막 확인 시각만 갱신해요.
        cur.execute('UPDATE player_ranking_snapshots SET observed_at=%s WHERE snapshot_id=%s',
                    (stamp, existing['snapshot_id']))
        return {'status': 'unchanged', 'season_name': season_name, 'snapshot_date': day.isoformat(),
                'rows': len(rows), 'input_sha256': fingerprint}
    cur.execute('''INSERT INTO player_ranking_snapshots
        (season_name,snapshot_date,observed_at,input_sha256) VALUES (%s,%s,%s,%s)
        ON DUPLICATE KEY UPDATE observed_at=VALUES(observed_at),input_sha256=VALUES(input_sha256)''',
        (season_name, day, stamp, fingerprint))
    cur.execute('SELECT snapshot_id FROM player_ranking_snapshots WHERE season_name=%s AND snapshot_date=%s',
                (season_name, day))
    snapshot_id = cur.fetchone()['snapshot_id']
    cur.execute('DELETE FROM player_ranking_snapshot_rows WHERE snapshot_id=%s', (snapshot_id,))
    if rows:
        cur.executemany('''INSERT INTO player_ranking_snapshot_rows
            (snapshot_id,season_id,competition_id,player_id,rating_sum,rated_matches,position)
            VALUES (%s,%s,%s,%s,%s,%s,%s)''', [
                (snapshot_id, r['season_id'], r['competition_id'], r['player_id'], r['rating_sum'],
                 r['rated_matches'], r['position']) for r in rows])
    return {'status': 'updated', 'season_name': season_name, 'snapshot_date': day.isoformat(),
            'rows': len(rows), 'input_sha256': fingerprint}


def read_changes(cur, *, competition_id=None, position=None, observed_at=None):
    observed = utc_datetime(observed_at or datetime.now(timezone.utc))
    season_name, current = current_ranking_inputs(cur, observed)
    cur.execute('''SELECT snapshot_id,snapshot_date,observed_at FROM player_ranking_snapshots
        WHERE season_name=%s AND snapshot_date<%s ORDER BY snapshot_date DESC LIMIT 1''',
        (season_name, observed.date()))
    baseline = cur.fetchone()
    # 갱신이 없는 휴식일은 마지막으로 저장한 순위가 이어져요. 과거 날짜의 행을 새로 만들지 않아요.
    previous = None if baseline is None else _fetch(cur, '''SELECT season_id,competition_id,player_id,
        rating_sum,rated_matches,position FROM player_ranking_snapshot_rows WHERE snapshot_id=%s''',
        (baseline['snapshot_id'],))
    result = compare_rankings(current, previous, season_name=season_name, as_of=observed,
                              competition_id=competition_id, position=position)
    return {**result, 'as_of': observed.isoformat(),
            'previous_snapshot_date': str(baseline['snapshot_date']) if baseline else None,
            'previous_observed_at': utc_datetime(baseline['observed_at']).isoformat() if baseline else None}


def run(*, command, apply=False, competition_id=None, position=None, limit=20):
    from ..core.db import get_conn, transaction
    from .player_rating_rankings_loader import _lock_rating_pool
    if command not in ('capture', 'changes') or (command != 'capture' and apply):
        raise ValueError('Only capture supports --apply')
    if limit < 1:
        raise ValueError('A positive limit is required')
    with (transaction() if apply else closing(get_conn())) as conn:
        if not apply:
            conn.start_transaction(readonly=True, consistent_snapshot=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                if apply:
                    _lock_rating_pool(cur)
                    result = capture_current_ranking(cur)
                elif command == 'capture':
                    season_name, rows = current_ranking_inputs(cur, datetime.now(timezone.utc))
                    result = {'status': 'preview', 'season_name': season_name, 'rows': len(rows),
                              'input_sha256': ranking_fingerprint(season_name, rows)}
                else:
                    result = read_changes(cur, competition_id=competition_id, position=position)
                    result['items'] = result['items'][:limit]
                return {**result, 'applied': apply}
        finally:
            if not apply:
                conn.rollback()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('capture', 'changes'))
    parser.add_argument('--competition-id', type=int, choices=RATING_COMPETITION_IDS)
    parser.add_argument('--position', choices=('GK', 'DF', 'MF', 'FW'))
    parser.add_argument('--limit', type=int, default=20)
    parser.add_argument('--output', type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--apply', action='store_true')
    args = parser.parse_args(argv)
    if args.command == 'capture' and (args.competition_id is not None or args.position is not None):
        parser.error('Capture always records all leagues and positions together')
    result = run(command=args.command, apply=args.apply, competition_id=args.competition_id,
                 position=args.position, limit=args.limit)
    rendered = json.dumps(result, ensure_ascii=False, default=str, indent=2)
    if args.output:
        args.output.write_text(rendered + '\n', encoding='utf-8')
    print(rendered)


if __name__ == '__main__':
    main()
