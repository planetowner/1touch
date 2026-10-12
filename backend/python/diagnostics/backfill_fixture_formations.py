"""보존한 Sportmonks 응답에서 누락 포메이션만 보충해요. --apply를 주면 저장해요."""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path

from one_touch_loader.core.db import fetch_all, transaction
from one_touch_loader.core.sportmonks import SportmonksClient
from one_touch_loader.loaders.fixture_details_loader import normalize_fixture_formations, SQL_INSERT_FORMATION


def backfill(snapshots: list[dict], *, apply: bool) -> dict:
    totals = Counter(fixtures=0, available=0, inserted=0, already_stored=0, unavailable=0)
    missing = []
    planned = []
    seen = set()
    # 전체 참가 팀을 먼저 대조해 다른 경기의 포메이션이 섞이면 저장 전에 멈춰요.
    for offset in range(0, len(snapshots), 50):
        group = snapshots[offset:offset + 50]
        ids = [item['fixture_id'] for item in group]
        if seen.intersection(ids) or len(set(ids)) != len(ids):
            raise ValueError('Duplicate fixture snapshot')
        seen.update(ids)
        marks = ','.join('%s' for _ in ids)
        fixtures = {fid: (home, away) for fid, home, away in fetch_all(
            f'SELECT fixture_id,home_team_id,away_team_id FROM fixtures WHERE fixture_id IN ({marks})', tuple(ids))}
        stored = {(fid, tid): formation for fid, tid, formation in fetch_all(
            f'SELECT fixture_id,team_id,formation FROM fixture_formations WHERE fixture_id IN ({marks})', tuple(ids))}
        for item in group:
            fid = item['fixture_id']
            home, away = fixtures[fid]
            participants = {p['location']: p['id'] for p in item['participants']}
            if participants != {'home': home, 'away': away}:
                raise ValueError(f'Fixture participants differ: {fid}')
            # 보존 원문도 일반 수집과 같은 경기별 팀 ID 정정을 거쳐요.
            payload = {'id': fid, 'formations': [dict(row) for row in item['formations']]}
            SportmonksClient._correct_fixture_teams(payload)
            source = normalize_fixture_formations(payload, fid)
            if len({row[1] for row in source}) != len(source) or any(row[1] not in (home, away) for row in source):
                raise ValueError(f'Formation participants differ: {fid}')
            by_team = {row[1]: row for row in source}
            for tid in (home, away):
                if (fid, tid) in stored:
                    totals['already_stored'] += 1
                elif tid in by_team:
                    planned.append(by_team[tid])
                    totals['available'] += 1
                else:
                    missing.append({'fixture_id': fid, 'team_id': tid})
                    totals['unavailable'] += 1
            totals['fixtures'] += 1

    if apply:
        for offset in range(0, len(planned), 100):
            with transaction() as connection, connection.cursor() as cursor:
                # 조회 중 라이브 수집이 채운 값은 덮어쓰지 않아요. 다른 상세 자료는 건드리지 않아요.
                cursor.executemany(SQL_INSERT_FORMATION + '\nON DUPLICATE KEY UPDATE formation=formation',
                                   planned[offset:offset + 100])
                totals['inserted'] += cursor.rowcount
            print(json.dumps({'apply': True, **totals, 'processed': min(offset + 100, len(planned))}), flush=True)
    return {'apply': apply, **totals, 'unavailable_teams': missing}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='fixture_id, participants, formations를 보존한 JSONL 파일')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    snapshots = [json.loads(line) for line in args.source.read_text(encoding='utf-8').splitlines() if line.strip()]
    print(json.dumps(backfill(snapshots, apply=args.apply)), flush=True)


if __name__ == '__main__':
    main()
