"""Sandro Lima의 이전 Opta·VAR 연결을 현재 공급자 ID로 옮겨요. 기본은 조회예요."""
from __future__ import annotations

import argparse
from contextlib import closing
from copy import deepcopy
import json

from one_touch_loader.core.identity import canonical_sportmonks_player_id
from one_touch_loader.loaders.opta_shots_store import DATASETS


OLD_PLAYER_ID = 37640040
PLAYER_ID = canonical_sportmonks_player_id(OLD_PLAYER_ID)
OPTA_ID = '7v3gbz56454fadpqntuay5l91'
# 실제 남아 있는 연결만 옮겨요. 이전 프로필·Sportmonks 원본 ID는 보존해요.
SCOPES = (
    ('player_external_ids', 'provider=%s AND external_player_id=%s', ('opta', OPTA_ID)),
    ('fixture_events', 'fixture_id=%s AND event_id=%s AND team_id=%s', (19788665, 157569490, 132649)),
    *((spec[1], 'fixture_id=%s AND team_id=%s', (19788649, 132649)) for spec in DATASETS.values()),
)


def snapshot(cursor, *, lock=False):
    result = {}
    for table, scope, params in SCOPES:
        cursor.execute(f'SELECT * FROM {table} WHERE ({scope}) AND player_id IN (%s,%s) ORDER BY 1'
                       + (' FOR UPDATE' if lock else ''), (*params, OLD_PLAYER_ID, PLAYER_ID))
        columns = [column[0] for column in cursor.description]
        result[table] = [dict(zip(columns, row)) for row in cursor.fetchall()]
    return result


def repair(conn, *, apply=False):
    conn.start_transaction(readonly=not apply)
    try:
        with conn.cursor() as cursor:
            suffix = ' FOR UPDATE' if apply else ''
            cursor.execute('SELECT player_id,display_name,date_of_birth FROM players '
                           'WHERE player_id IN (%s,%s)' + suffix, (OLD_PLAYER_ID, PLAYER_ID))
            profiles = cursor.fetchall()
            if ({row[0] for row in profiles} != {OLD_PLAYER_ID, PLAYER_ID}
                    or any(row[1] != 'Sandro Lima' or str(row[2]) != '1990-10-28' for row in profiles)):
                raise ValueError('Sandro Lima profiles differ from the verified evidence')
            cursor.execute('SELECT player_id FROM player_external_ids '
                           'WHERE provider=%s AND external_player_id=%s' + suffix, ('opta', OPTA_ID))
            if cursor.fetchall() not in ([(OLD_PLAYER_ID,)], [(PLAYER_ID,)]):
                raise ValueError('Opta identity differs from the verified evidence')
            before = snapshot(cursor, lock=apply)
            expected = deepcopy(before)
            changes = {}
            for table, scope, params in SCOPES:
                changes[table] = sum(row['player_id'] == OLD_PLAYER_ID for row in before[table])
                for row in expected[table]:
                    row['player_id'] = PLAYER_ID
                if apply and changes[table]:
                    cursor.execute(f'UPDATE {table} SET player_id=%s WHERE ({scope}) AND player_id=%s',
                                   (PLAYER_ID, *params, OLD_PLAYER_ID))
            # 선수 연결 외의 시각·좌표·도움·이벤트 내용까지 원본과 같아야 커밋해요.
            if apply and snapshot(cursor) != expected:
                raise ValueError('Sandro Lima repair verification failed')
        conn.commit() if apply else conn.rollback()
        return {'applied': apply, 'from_player_id': OLD_PLAYER_ID, 'to_player_id': PLAYER_ID,
                'changes': changes, 'before': before}
    except Exception:
        conn.rollback()
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    from one_touch_loader.core.db import get_conn
    with closing(get_conn()) as conn:
        print(json.dumps(repair(conn, apply=args.apply), ensure_ascii=False, indent=2, default=str))


if __name__ == '__main__':
    main()
