"""대회 전체 대진을 수집해요. --apply를 지정해야 DB에 저장해요."""
import argparse
from datetime import datetime, timezone
from pathlib import Path

from ..core.cup_betting import CUP_COMPETITION_IDS, utc_datetime
from ..core.sportmonks import SportmonksClient
from ..core.tournament_bracket import build_bracket
from .probability_loader import _dump, _fetch, _read


INCLUDE = 'participants;stage;round;aggregate;scores;state'


def read_seasons(season_ids=None):
    where = 'is_current=1'
    params = CUP_COMPETITION_IDS
    if season_ids:
        where = 'season_id IN (' + ','.join('%s' for _ in season_ids) + ')'
        params += tuple(season_ids)
    marks = ','.join('%s' for _ in CUP_COMPETITION_IDS)
    rows = _fetch(f"""SELECT season_id,competition_id,name AS season_name FROM seasons
        WHERE competition_id IN ({marks}) AND {where}
        ORDER BY competition_id,season_id""", params)
    if season_ids and {r['season_id'] for r in rows} != set(season_ids):
        raise ValueError('One or more bracket seasons were not found')
    return rows


def store_brackets(brackets):
    from ..core.db import transaction
    with transaction() as conn:
        with conn.cursor() as cursor:
            cursor.executemany("""INSERT INTO tournament_brackets (season_id,input_sha256,payload,fetched_at)
                VALUES (%s,%s,%s,%s) ON DUPLICATE KEY UPDATE
                input_sha256=VALUES(input_sha256),payload=VALUES(payload),fetched_at=VALUES(fetched_at)""",
                [(b['season_id'], b['input_sha256'], _dump(b),
                  utc_datetime(b['fetched_at']).replace(tzinfo=None)) for b in brackets])


def collect(*, season_ids=None):
    seasons = read_seasons(season_ids)
    client = SportmonksClient()
    brackets = []
    for season in seasons:
        raw = list(client.iter_fixtures_by_season(season['season_id'], include=INCLUDE))
        provider = client.get_season_bracket(season['season_id'])
        existing = _fetch("""SELECT f.fixture_id FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
            WHERE st.season_id=%s""", (season['season_id'],))
        brackets.append(build_bracket(**season, fixtures=raw, fetched_at=datetime.now(timezone.utc),
            available_fixture_ids=[r['fixture_id'] for r in existing], provider_edges=provider['edges']))
    return brackets


def refresh(*, apply=False, season_ids=None):
    brackets = collect(season_ids=season_ids)
    if apply and brackets:
        store_brackets(brackets)
    return brackets


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--season-id', type=int, action='append')
    parser.add_argument('--input-json', type=Path, help='검증용 build_bracket 입력 목록이에요. DB에는 저장하지 않아요.')
    parser.add_argument('--output', type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args(argv)
    if args.input_json:
        if args.apply or args.season_id:
            raise ValueError('Offline inputs are only for read-only validation')
        brackets = [build_bracket(**record) for record in _read(args.input_json)]
    else:
        brackets = refresh(apply=args.apply, season_ids=args.season_id)
    if args.output:
        args.output.write_text(_dump(brackets) + '\n', encoding='utf-8')
    print(_dump({'applied': args.apply, 'seasons': [{k: b[k] for k in (
        'season_id', 'competition_id', 'status', 'path_status', 'input_sha256', 'issues')} for b in brackets]}))


if __name__ == '__main__':
    main()
