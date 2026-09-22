"""저장된 전체 대진을 읽고 경기 상세 화면의 현재 적재 여부를 붙여요."""
from ..db import fetch_all_dict, fetch_one_dict
from ...core.db_json import decoded


def find_bracket_season(competition_id, season_id=None):
    condition = 'season_id=%s' if season_id is not None else 'is_current=1'
    params = (competition_id, season_id) if season_id is not None else (competition_id,)
    return fetch_one_dict(f"""SELECT season_id,competition_id,name FROM seasons
        WHERE competition_id=%s AND {condition} ORDER BY season_id DESC LIMIT 1""", params)


def get_bracket(season_id):
    row = fetch_one_dict('SELECT payload FROM tournament_brackets WHERE season_id=%s', (season_id,))
    if row is None:
        return None
    bracket = decoded(row['payload'])
    available = {r['fixture_id'] for r in fetch_all_dict("""SELECT f.fixture_id FROM fixtures f
        JOIN stages st ON st.stage_id=f.stage_id WHERE st.season_id=%s""", (season_id,))}
    for stage in bracket['stages']:
        for tie in stage['ties']:
            for fixture in tie['fixtures']:
                fixture['detail_available'] = fixture['fixture_id'] in available
    return bracket
