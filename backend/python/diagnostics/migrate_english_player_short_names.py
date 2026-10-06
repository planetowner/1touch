"""영어 짧은 이름을 정리하되, 소문자로 시작하는 복합 성은 이니셜을 유지해요."""
import argparse
from contextlib import closing
import json
import re

from diagnostics.migrate_football_names import migrate_data as save_names
from diagnostics.migrate_player_short_names import SEED_PATH
from one_touch_loader.core.db import fetch_all, get_conn


# 영어 DB에서 확인한 '한 글자 + 마침표 + 공백'만 제거해 복합 성을 보존해요.
ENGLISH_INITIAL = re.compile(r'^[A-Za-zÀ-ž]\. (.+)$')


def name_changes(rows, reviewed_names=None):
    reviewed_names = reviewed_names or {}
    changes = []
    for player_id, short_name in rows:
        match = ENGLISH_INITIAL.fullmatch(short_name or '')
        if not match:
            # 이미 제거한 이니셜은 선수 ID와 당시 성이 일치할 때만 복원해요.
            match = ENGLISH_INITIAL.fullmatch(reviewed_names.get(player_id) or '')
            if not match or match[1] != short_name:
                continue
        family = match[1]
        # de Jong, van Dijk, ter Stegen처럼 소문자로 시작하는 복합 성은 예외예요.
        after = match[0] if family[0].islower() and ' ' in family else family
        if after != short_name:
            changes.append({'player_id': player_id, 'before': short_name, 'after': after})
    return changes


def migrate_data(conn, changes):
    # 공통 저장 함수가 영어 외의 컬럼을 보존하고, 조회 후 값이 바뀌면 롤백해요.
    save_names(
        conn,
        names={'players': {row['player_id']: row['after'] for row in changes}},
        columns={'players': ('player_id', 'short_name')},
        expected_before={'players': {row['player_id']: row['before'] for row in changes}},
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(argv)
    reviewed = json.loads(SEED_PATH.read_text(encoding='utf-8'))['entities']['players']
    changes = name_changes(
        fetch_all('SELECT player_id,short_name FROM players ORDER BY player_id'),
        {row['player_id']: row['en'] for row in reviewed},
    )
    print(json.dumps({'updates': len(changes), 'examples': changes[:10]}, ensure_ascii=False), flush=True)
    if not args.apply or not changes:
        return
    with closing(get_conn()) as conn:
        migrate_data(conn, changes)
    print(json.dumps({'updated': len(changes)}, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
