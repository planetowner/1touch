"""기존 라이브·알림·정산 함수를 테스트 컨테이너에서 실행해요."""
import argparse
import json
import time

from . import require_test_database

INTERVALS = {'live': 15, 'notifications': 15, 'refresh': 900}


def run(task, *, apply, scheduled):
    require_test_database()
    if task == 'live':
        from one_touch_loader.loaders.live_fixtures_loader import refresh_live_fixtures
        return refresh_live_fixtures(apply=apply)
    if task == 'notifications':
        from one_touch_loader.loaders.notification_schedule import run_schedule
        from one_touch_loader.loaders.notification_push import dispatch
        from one_touch_loader.loaders.betting_loader import run_cli
        if scheduled:
            run_schedule(apply=apply)
        run_cli(['--apply'] if apply else [])
        return dispatch(apply=apply)
    from .seed import sync
    from .predictions import refresh
    if scheduled:
        sync(apply=apply)
    return refresh(apply=apply)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('task', choices=INTERVALS)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--loop', action='store_true')
    args = parser.parse_args()
    # 세 작업을 별도 컨테이너로 실행해 일정·Elo 조회가 라이브 수집을 막지 않아요.
    scheduled_at = time.monotonic() + 3600 if args.task == 'refresh' else 0
    while True:
        now = time.monotonic()
        scheduled = now >= scheduled_at
        print(json.dumps(run(args.task, apply=args.apply, scheduled=scheduled), default=str), flush=True)
        if scheduled:
            scheduled_at = now + (60 if args.task == 'notifications' else 3600)
        if not args.loop:
            return
        time.sleep(INTERVALS[args.task])


if __name__ == '__main__':
    main()
