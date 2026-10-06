"""감독 신원 교정과 한국어 이름 보완을 미리 확인해요. DB 백업 후 --apply로 반영해요."""
from __future__ import annotations

import argparse
from contextlib import closing
from copy import deepcopy
import json
from pathlib import Path

from one_touch_loader.core.sportmonks import (
    SPORTMONKS_COACH_NAME_OVERRIDES,
    SPORTMONKS_FIXTURE_COACH_ID_OVERRIDES,
)


PREVIOUS_NAMES = {
    29935: 'Jovan Pop Zlatanov',
    457103: 'Jessy Deminguet',
    462010: 'Djair',
}
# Deminguet 선수의 번역만 비워요. 이미 다른 이름으로 교정한 값과 한국어는 보존해요.
INVALID_TRANSLATIONS = {457103: {'name_ja': 'ジェシー・デミンゲット', 'name_zh': '杰西·德明盖特'}}
KOREAN_SEED_PATH = Path(__file__).with_name('coach_names.ko-individual.json')


def reviewed_korean_rows():
    from diagnostics.migrate_coach_names import SPECS
    from diagnostics.migrate_sportmonks_names import reviewed_rows
    return reviewed_rows(seed_path=KOREAN_SEED_PATH, specs=SPECS, locales=('ko',))['coaches']


def snapshot(cursor, reviewed, *, lock=False):
    suffix = ' FOR UPDATE' if lock else ''
    ids = sorted(set(PREVIOUS_NAMES) | {key[2] for key in SPORTMONKS_FIXTURE_COACH_ID_OVERRIDES}
                 | set(SPORTMONKS_FIXTURE_COACH_ID_OVERRIDES.values())
                 | {row['coach_id'] for row in reviewed})
    cursor.execute('SELECT * FROM coaches WHERE coach_id IN (' + ','.join(['%s'] * len(ids))
                   + ') ORDER BY coach_id' + suffix, tuple(ids))
    columns = [column[0] for column in cursor.description]
    coaches = {row[0]: dict(zip(columns, row)) for row in cursor.fetchall()}
    if set(coaches) != set(ids):
        raise ValueError('Expected coach records are missing')
    fixtures = {}
    for fixture_id, team_id, _ in SPORTMONKS_FIXTURE_COACH_ID_OVERRIDES:
        cursor.execute('SELECT fixture_id,team_id,coach_id FROM fixture_coaches '
                       'WHERE fixture_id=%s AND team_id=%s' + suffix, (fixture_id, team_id))
        rows = cursor.fetchall()
        if len(rows) != 1:
            raise ValueError(f'Expected fixture coach is missing: {fixture_id}/{team_id}')
        fixtures[(fixture_id, team_id)] = rows[0][2]
    return {'coaches': coaches, 'fixtures': fixtures}


def expected_snapshot(before, reviewed):
    after = deepcopy(before)
    for coach_id, old_name in PREVIOUS_NAMES.items():
        new_name = SPORTMONKS_COACH_NAME_OVERRIDES[coach_id]
        coach = after['coaches'][coach_id]
        if coach['name'] not in (old_name, new_name):
            raise ValueError(f'Coach identity changed: {coach_id}')
        coach['name'] = new_name
        for column, invalid in INVALID_TRANSLATIONS.get(coach_id, {}).items():
            if coach[column] == invalid:
                coach[column] = None
    # 검증한 Carlos의 기존 행으로 연결하며 Jefferson의 인물 정보는 바꾸지 않아요.
    for (fixture_id, team_id, old_id), new_id in SPORTMONKS_FIXTURE_COACH_ID_OVERRIDES.items():
        key = (fixture_id, team_id)
        if after['fixtures'][key] not in (old_id, new_id):
            raise ValueError(f'Fixture coach changed: {fixture_id}/{team_id}')
        after['fixtures'][key] = new_id
    # 모든 표기안에 같은 신원 확인·빈칸 보완 규칙을 적용해요. 기존 한국어는 보존해요.
    for row in reviewed:
        coach_id = row['coach_id']
        coach = after['coaches'][coach_id]
        if coach['name'] != row['identity']['name']:
            raise ValueError(f'Coach identity changed: {coach_id}')
        if not (coach['name_ko'] or '').strip():
            coach['name_ko'] = row['ko']
    return after


def repair(conn, *, apply=False):
    reviewed = reviewed_korean_rows()
    conn.start_transaction(readonly=not apply)
    try:
        with conn.cursor() as cursor:
            before = snapshot(cursor, reviewed, lock=apply)
            after = expected_snapshot(before, reviewed)
            changes = []
            for coach_id, coach in after['coaches'].items():
                for column in ('name', 'name_ko', 'name_ja', 'name_zh'):
                    previous = before['coaches'][coach_id][column]
                    value = coach[column]
                    if value == previous:
                        continue
                    changes.append({'table': 'coaches', 'coach_id': coach_id, 'column': column,
                                    'before': previous, 'after': value})
                    if apply:
                        cursor.execute(f'UPDATE coaches SET {column}=%s WHERE coach_id=%s', (value, coach_id))
            for (fixture_id, team_id), new_id in after['fixtures'].items():
                old_id = before['fixtures'][(fixture_id, team_id)]
                if old_id != new_id:
                    changes.append({'table': 'fixture_coaches', 'fixture_id': fixture_id, 'team_id': team_id,
                                    'before': old_id, 'after': new_id})
                    if apply:
                        cursor.execute('UPDATE fixture_coaches SET coach_id=%s WHERE fixture_id=%s AND team_id=%s',
                                       (new_id, fixture_id, team_id))
            if apply and snapshot(cursor, reviewed) != after:
                raise ValueError('Coach repair verification failed')
        if apply:
            conn.commit()
        else:
            conn.rollback()
        return {'applied': apply, 'change_count': len(changes), 'changes': changes}
    except Exception:
        conn.rollback()
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    from one_touch_loader.core.db import get_conn
    with closing(get_conn()) as conn:
        print(json.dumps(repair(conn, apply=args.apply), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
