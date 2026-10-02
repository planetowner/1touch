"""기존 출전 포지션 계산 결과를 선수·시즌당 한 번 저장해요."""
from __future__ import annotations

import argparse
from collections import defaultdict
from contextlib import closing, contextmanager
from datetime import datetime, timezone
import json

from ..core.db import get_conn, transaction
from ..core.fixture_states import COMPLETED_STATE_IDS
from ..core.player_appearances import APPEARED
from ..core.player_ranking import season_player_position_ids
from .player_rating_rankings_loader import _lock_rating_pool


def _fetch(cur, sql, params=()):
    cur.execute(sql, params)
    return cur.fetchall()


def refresh_season_positions(cur, season_name, *, player_ids=None, as_of=None, apply=True):
    if player_ids is not None and not player_ids:
        return 0
    positions = season_player_position_ids(
        lambda sql, params: _fetch(cur, sql, params), season_name,
        as_of or datetime.now(timezone.utc).replace(tzinfo=None), player_ids=player_ids,
    )
    rows = [(season_name, pid, position) for pid, position in positions.items() if position is not None]
    if apply:
        scope = '' if player_ids is None else f" AND player_id IN ({','.join(['%s'] * len(player_ids))})"
        # 출전 기록이 삭제되거나 포지션이 미제공으로 바뀌면 이전 계산값도 지워요.
        cur.execute('DELETE FROM player_season_positions WHERE season_name=%s' + scope,
                    (season_name, *(player_ids or ())))
        if rows:
            cur.executemany('''INSERT INTO player_season_positions
                (season_name,player_id,position_group_id) VALUES (%s,%s,%s)''', rows)
    return len(rows)


def _fixture_inputs(cur, fixture_ids):
    return _fetch(cur, f'''SELECT f.fixture_id,fl.team_id,fl.player_id,s.name AS season_name,
        f.state_id,f.starting_at,fl.match_position_id,fl.minutes_played,
        CASE WHEN {APPEARED} THEN 1 ELSE 0 END AS appeared
        FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
        JOIN seasons s ON s.season_id=st.season_id
        LEFT JOIN fixture_lineups fl ON fl.fixture_id=f.fixture_id
        WHERE f.fixture_id IN ({','.join(['%s'] * len(fixture_ids))})
        ORDER BY f.fixture_id,fl.team_id,fl.player_id''', tuple(fixture_ids))


@contextmanager
def refresh_positions_after_fixtures(connection, fixture_ids, *, records_changed=True):
    if not records_changed:
        yield
        return
    with connection.cursor(dictionary=True) as cur:
        # 기존 평점 갱신과 같은 잠금 순서를 써서 겹친 경기 수집도 차례대로 반영해요.
        _lock_rating_pool(cur)
        before = _fixture_inputs(cur, fixture_ids)
        yield
        after = _fixture_inputs(cur, fixture_ids)
        if before == after:
            return
        affected = defaultdict(set)
        # 교체 전 명단도 포함해야 삭제된 선수와 종료 취소된 경기의 계산값을 정리해요.
        for row in before + after:
            if row['player_id'] is not None and row['state_id'] in COMPLETED_STATE_IDS:
                affected[row['season_name']].add(row['player_id'])
        as_of = datetime.now(timezone.utc).replace(tzinfo=None)
        for season_name, player_ids in sorted(affected.items()):
            refresh_season_positions(cur, season_name, player_ids=sorted(player_ids), as_of=as_of)


def rebuild(*, season_name=None, apply=False):
    with (transaction() if apply else closing(get_conn())) as conn:
        if not apply:
            conn.start_transaction(readonly=True, consistent_snapshot=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                if apply:
                    _lock_rating_pool(cur)
                names = _fetch(cur, 'SELECT DISTINCT name FROM seasons WHERE (%s IS NULL OR name=%s) ORDER BY name',
                               (season_name, season_name))
                as_of = datetime.now(timezone.utc).replace(tzinfo=None)
                rows = [{"season_name": row['name'], "players": refresh_season_positions(
                    cur, row['name'], as_of=as_of, apply=apply)} for row in names]
                return {"applied": apply, "seasons": rows}
        finally:
            if not apply:
                conn.rollback()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--season-name')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    print(json.dumps(rebuild(season_name=args.season_name, apply=args.apply), ensure_ascii=False))


if __name__ == '__main__':
    main()
