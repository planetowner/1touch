"""종료 경기는 바로 확인하고, 아직 공개되지 않은 경기 자료는 5분 뒤 다시 확인해요."""
from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace

from ..api.db import fetch_all_dict
from ..core.fixture_states import COMPLETED_STATE_IDS, LIVE_STATE_IDS
from ..core.opta_schedule import COMPETITIONS as OPTA_COMPETITIONS
from ..core.understat import UNDERSTAT_LEAGUES
from . import live_fixtures_loader, opta_shots_loader, probability_refresh, standings_loader
from .understat_loader import refresh_understat
from .xg_standings_loader import build_xg_standings


RETRY_SECONDS = 300
STANDINGS_SECONDS = 30
PROBABILITY_SECONDS = 900


def fingerprint(value) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, default=str).encode()).hexdigest()


def fixture_result(fixture):
    # 진행 중 득점은 확정 결과 기반 계산을 다시 시작할 이유가 아니에요.
    completed = fixture['state_id'] in COMPLETED_STATE_IDS
    return [fixture[k] for k in ('fixture_id', 'starting_at', 'home_team_id', 'away_team_id')] + [
        2 if fixture['state_id'] in LIVE_STATE_IDS else fixture['state_id'],
        fixture['home_score'] if completed else None, fixture['away_score'] if completed else None,
        fixture.get('home_penalty_score') if completed else None,
        fixture.get('away_penalty_score') if completed else None,
    ]


def read_current_fixtures() -> list[dict]:
    return fetch_all_dict("""
        SELECT f.fixture_id,f.home_team_id,f.away_team_id,f.starting_at,f.state_id,
               f.home_score,f.away_score,f.home_penalty_score,f.away_penalty_score,
               s.season_id,s.competition_id,s.name AS season_name,
               x.fixture_id IS NOT NULL AS has_xg,
               shots.fixture_id IS NOT NULL AND analysis.fixture_id IS NOT NULL AS has_opta
        FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
        JOIN seasons s ON s.season_id=st.season_id
        LEFT JOIN fixture_expected_goals x ON x.fixture_id=f.fixture_id
        LEFT JOIN fixture_opta_shotmaps shots ON shots.fixture_id=f.fixture_id
        LEFT JOIN fixture_opta_analyses analysis ON analysis.fixture_id=f.fixture_id
        WHERE s.is_current=1 ORDER BY s.season_id,f.fixture_id
    """)


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding='utf-8')
    temporary.replace(path)


def _provider_refresh(task, fixtures, *, apply, output_dir):
    # 종료 상태만 저장됐어도 상세·실제 출전 명단은 늦을 수 있어 먼저 같은 저장 경로로 확인해요.
    payloads = live_fixtures_loader.refresh_completed_details(fixtures, apply=apply)
    completed = {p['id'] for p in payloads}
    selected = [f for f in fixtures if f['fixture_id'] in completed]
    if not selected:
        return set(), set()
    season, competition = selected[0]['season_name'], selected[0]['competition_id']
    if task == 'understat':
        if not apply:
            # 미리보기의 새 명단은 DB에 없어요. 적재까지 성공한 것처럼 ID 검증을 이어 가지 않아요.
            return set(), set()
        report = refresh_understat(season, [competition], fixture_ids=completed)
        if report['processed_fixture_ids']:
            result = build_xg_standings(season, [competition])
            if result['unavailable']:
                raise ValueError(f"xG standings inputs are unavailable: {result['unavailable']}")
        return set(report['processed_fixture_ids']), set(report['withheld_fixture_ids'])
    dates = [datetime.fromisoformat(str(f['starting_at'])).date() for f in selected]
    args = SimpleNamespace(apply=apply, dataset='both', competition_ids=[competition], season=season,
                           fixtures=selected, from_date=min(dates), to_date=max(dates),
                           refresh=any(f['has_opta'] for f in selected),
                           refresh_details=False, retry_report=None, retry_statuses=None, limit=None,
                           output_dir=output_dir)
    report = opta_shots_loader.sync_matches(args)
    if report['failed']:
        raise ValueError(f"Opta capture or identity validation failed: {report['failed']}")
    return {r['fixture_id'] for r in report['matches'] if r['status'] in ('stored', 'verified')}, set()


def refresh(task: str, *, state_path: Path, apply: bool = False, now=None) -> dict:
    now = now or datetime.now(timezone.utc)
    stamp = now.timestamp()
    state = json.loads(state_path.read_text(encoding='utf-8')) if state_path.is_file() else {}
    fixtures = read_current_fixtures()
    result = {'task': task, 'apply': apply, 'attempted': 0, 'completed': 0, 'pending': 0, 'failures': []}
    dirty = False

    def checkpoint(key, value):
        nonlocal dirty
        state[key] = value
        dirty = True

    def flush():
        nonlocal dirty
        if apply and dirty:
            save_state(state_path, state)
            dirty = False

    if task in ('understat', 'opta'):
        supported = UNDERSTAT_LEAGUES if task == 'understat' else OPTA_COMPETITIONS
        groups = defaultdict(list)
        for fixture in fixtures:
            if fixture['competition_id'] not in supported or fixture['state_id'] not in COMPLETED_STATE_IDS:
                continue
            key = str(fixture['fixture_id'])
            previous = state.get(key, {})
            signature = fingerprint(fixture_result(fixture))
            same = previous.get('signature') == signature
            if same and previous.get('status') in ('complete', 'withheld'):
                continue
            if fixture['has_xg' if task == 'understat' else 'has_opta'] and not previous:
                # 최초 실행 때 이미 검증한 현재 시즌 자료를 다시 수집하지 않아요.
                checkpoint(key, {'signature': signature, 'status': 'complete'})
                continue
            if same and stamp - previous.get('attempted_at', 0) < RETRY_SECONDS:
                continue
            groups[fixture['season_id']].append(fixture)
        for selected in groups.values():
            for fixture in selected:
                checkpoint(str(fixture['fixture_id']), {'signature': fingerprint(fixture_result(fixture)),
                           'status': 'pending', 'attempted_at': stamp})
            # 한 경기마다 전체 상태 파일을 다시 쓰지 않아요. 원격 수집 직전에 묶어서 저장해요.
            flush()
            result['attempted'] += len(selected)
            try:
                complete, withheld = _provider_refresh(task, selected, apply=apply,
                    output_dir=state_path.parent / 'opta' / now.strftime('%Y%m%dT%H%M%S%f'))
                for fixture in selected:
                    key = str(fixture['fixture_id'])
                    status = 'complete' if fixture['fixture_id'] in complete else (
                        'withheld' if fixture['fixture_id'] in withheld else 'pending')
                    checkpoint(key, {**state[key], 'status': status})
                    result['completed'] += int(status in ('complete', 'withheld'))
                    result['pending'] += int(status == 'pending')
            except Exception as error:
                result['pending'] += len(selected)
                result['failures'].append({'season_id': selected[0]['season_id'], 'error': str(error)})
        flush()
        return result

    groups = defaultdict(list)
    for fixture in fixtures:
        groups[fixture['season_id']].append(fixture)
    if task == 'standings':
        for season_id, selected in groups.items():
            competition = selected[0]['competition_id']
            if competition not in standings_loader.BIG5_COMPETITION_IDS:
                continue
            signature = fingerprint([fixture_result(f) for f in selected])
            live = any(f['state_id'] in LIVE_STATE_IDS for f in selected)
            for is_live in (False, True) if live else (False,):
                key = f'{season_id}:{is_live}'
                previous = state.get(key, {})
                interval = STANDINGS_SECONDS if is_live else 3600
                changed = previous.get('signature') != signature
                if not changed and stamp - previous.get('attempted_at', 0) < interval:
                    continue
                try:
                    result['attempted'] += 1
                    standings_loader.refresh_current_table(season_id, competition, live=is_live,
                                                          clear_live=not live, apply=apply)
                    checkpoint(key, {'signature': signature, 'attempted_at': stamp})
                    result['completed'] += 1
                except Exception as error:
                    result['failures'].append({'season_id': season_id, 'live': is_live, 'error': str(error)})
        flush()
        return result

    signature = fingerprint([fixture_result(f) for f in fixtures])
    previous = state.get('probability', {})
    if (previous.get('signature') == signature
            and stamp - previous.get('attempted_at', 0) < PROBABILITY_SECONDS):
        return result
    # 원본이 실패한 동안 15초마다 원격 요청을 반복하지 않아요. 새 결과가 생기면 바로 다시 확인해요.
    attempt = state.get('probability_attempt', {})
    if attempt.get('signature') == signature and stamp - attempt.get('attempted_at', 0) < RETRY_SECONDS:
        return result
    checkpoint('probability_attempt', {'signature': signature, 'attempted_at': stamp})
    flush()
    try:
        result['attempted'] = 1
        report = probability_refresh.refresh(apply=apply)
        result['probability'] = report
        # 검증된 대진을 기다리는 시즌을 계산 완료로 감추지 않아요.
        pending = [item for item in report['europe']['competitions']
                   if item['status'] not in ('updated', 'unchanged')]
        result['pending'] = len(pending)
        if not pending:
            checkpoint('probability', {'signature': signature, 'attempted_at': stamp})
            result['completed'] = 1
    except Exception as error:
        result['failures'].append({'error': str(error)})
    flush()
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('task', choices=('standings', 'understat', 'opta', 'probability'))
    parser.add_argument('--state-dir', type=Path, default=Path(__file__).resolve().parents[3] / 'logs/match-refresh')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args(argv)
    result = refresh(args.task, state_path=args.state_dir / f'{args.task}.json', apply=args.apply)
    print(json.dumps(result, ensure_ascii=False, default=str))
    return int(bool(result['failures']))


if __name__ == '__main__':
    raise SystemExit(main())
