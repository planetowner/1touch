"""기존 Opta 원본의 자료 없음 기록을 복구해요. 기본은 조회이며 --apply만 상태 파일을 바꿔요."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil

from one_touch_loader.loaders import match_refresh as jobs
from one_touch_loader.loaders.opta_shots_loader import unavailable_evidence, source_context, scheduled_fixture
from one_touch_loader.loaders.opta_shots_store import load_known_ids


def plan_reconciliation(root, fixtures, known, state):
    changes = {}
    unmatched = set()
    examined = 0
    for path in sorted(root.rglob('schedule-*.json')):
        schedule = json.loads(path.read_text(encoding='utf-8'))
        candidates = [f for f in fixtures if f['competition_id'] == schedule['competition_id']
                      and f['season_name'] == schedule['season_name']
                      and f['state_id'] in jobs.COMPLETED_STATE_IDS]
        for match in schedule['matches']:
            external = match['external_fixture_id']
            raw_path = path.parent / f'{external}.raw.json'
            if not raw_path.is_file():
                continue
            raw = json.loads(raw_path.read_text(encoding='utf-8'))
            if not (raw.get('finished') is True and raw.get('available') is False
                    and raw.get('match_id') == external and unavailable_evidence(raw.get('evidence', {}))):
                continue
            examined += 1
            item = {'status': 'unavailable', 'external_fixture_id': external,
                    'checked_at_utc': raw['checked_at_utc'],
                    'source': source_context(match, schedule['competition_id'], schedule['season_name'])}
            source_key = jobs.opta_source_key(item)
            source_entry = jobs.opta_state_entry(None, item)
            latest = changes.get(source_key, {}).get('after', state.get(source_key, {}))
            if latest.get('attempted_at', 0) < source_entry['attempted_at']:
                changes[source_key] = {'before': state.get(source_key, {}), 'after': source_entry}
            fixture = scheduled_fixture(match, candidates, known)
            if fixture is None:
                unmatched.add(external)
                continue
            key = str(fixture['fixture_id'])
            previous = state.get(key, {})
            signature = jobs.fingerprint(jobs.fixture_result(fixture))
            # 이전 시도의 경기 결과와 같을 때만 복구해 정정된 경기나 완료 자료를 건너뛰지 않아요.
            if fixture['has_opta'] or previous.get('signature') != signature:
                continue
            if previous.get('status') in ('complete', 'withheld'):
                continue
            entry = jobs.opta_state_entry(fixture, item)
            latest = changes.get(key, {}).get('after', previous)
            if latest.get('status') != 'pending' and latest.get('attempted_at', 0) >= entry['attempted_at']:
                continue
            changes[key] = {'before': previous, 'after': entry}
    return {'examined': examined, 'unmatched_external_ids': sorted(unmatched), 'changes': changes}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state-dir', type=Path, default=Path(__file__).resolve().parents[2] / 'logs/match-refresh')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--apply', action='store_true')
    args = parser.parse_args(argv)
    path = args.state_dir / 'opta.json'
    state = json.loads(path.read_text(encoding='utf-8'))
    report = plan_reconciliation(args.state_dir / 'opta', jobs.read_current_fixtures(), load_known_ids(), state)
    if args.apply and report['changes']:
        # 수집 예약을 멈춘 뒤 실행해요. 원래 상태는 별도 사본으로 보관해 되돌릴 수 있게 해요.
        backup = path.with_name(f"opta.before-reconcile-{datetime.now(timezone.utc):%Y%m%dT%H%M%S%f}.json")
        shutil.copy2(path, backup)
        state.update({key: value['after'] for key, value in report['changes'].items()})
        jobs.save_state(path, state)
        report['backup'] = str(backup)
    print(json.dumps({'apply': args.apply, **report}, ensure_ascii=False))


if __name__ == '__main__':
    main()
