"""기존 프록시에 테스트 경로 한 개만 붙이거나 제거해요."""
import argparse
from pathlib import Path

BEGIN = '\t# BEGIN ONETOUCH LIVE TEST\n'
END = '\t# END ONETOUCH LIVE TEST\n'
BLOCK = BEGIN + '''\thandle_path /live-test/* {
\t\t@live_test_internal path /docs /docs/* /redoc /openapi.json /v1/ready
\t\trespond @live_test_internal 404
\t\treverse_proxy onetouch-live-test-api:8000
\t}
''' + END


def update(source, enable):
    if BEGIN in source:
        before, remainder = source.split(BEGIN, 1)
        _, after = remainder.split(END, 1)
        source = before + after
    if enable:
        anchor = '\treverse_proxy onetouch-dev-api-1:8000\n'
        if anchor not in source:
            raise ValueError('The existing API proxy route was not found')
        source = source.replace(anchor, BLOCK + anchor, 1)
    return source


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('add', 'remove'))
    parser.add_argument('path', type=Path)
    args = parser.parse_args()
    args.path.write_text(update(args.path.read_text(), args.mode == 'add'))
