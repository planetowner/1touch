"""인자 없이 실행하면 조회만 해요. --apply가 있어야 알림을 생성하거나 발송해요."""
import argparse
import json

from .notification_schedule import run_schedule
from .notification_push import dispatch
from ..api.services.push_sender import PushError


def run_cli(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('task', choices=('schedule', 'push'))
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(argv)
    try:
        result = (run_schedule if args.task == 'schedule' else dispatch)(apply=args.apply)
    except PushError as error:
        parser.exit(1, json.dumps({'error': error.code}) + '\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    run_cli()
