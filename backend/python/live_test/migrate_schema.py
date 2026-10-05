"""기존 테스트 DB에 최신 API가 사용하는 감독 이름·채팅 구조를 추가해요."""
import argparse
from pathlib import Path

from . import require_test_database


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    require_test_database()

    from diagnostics.migrate_coach_names import SPECS
    from diagnostics.migrate_sportmonks_names import verify_schema
    from diagnostics.migrate_fixture_chat_aliases import main as migrate_chat
    from one_touch_loader.core.db import execute

    # 운영과 같은 컬럼 정의·검증을 쓰고, 출처가 없는 감독 번역은 채우지 않아요.
    ready = verify_schema(before=True, specs=SPECS, locales=('ja', 'zh'))
    print(f'Coach language schema ready: {ready}', flush=True)
    if args.apply and not ready:
        sql = Path(__file__).parents[1] / 'one_touch_loader/sql/migrate_coach_names_ja_zh.sql'
        execute(sql.read_text(encoding='utf-8'))
        verify_schema(before=False, specs=SPECS, locales=('ja', 'zh'))
    migrate_chat()


if __name__ == '__main__':
    main()
