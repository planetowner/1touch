"""일반·짧은 표시 이름은 언어별로 같은 DB 카탈로그를 사용해요."""
from .db import fetch_all

NAME_COLUMNS = {
    "teams": ("team_id", "name_ko"),
    "players": ("player_id", "display_name_ko"),
}
LOCALE_COLUMNS = {
    'en': ('name', 'display_name', 'short_name', 'short_name', 'name', 'name'),
    'ko': ('name_ko', 'display_name_ko', 'short_name_ko', 'short_name_ko', 'name_ko', 'name_ko'),
    # 팀은 현재 name_ja·name_zh를 써요. short_name_ja·short_name_zh가 생기면 팀의 짧은 이름(None)을 교체해요.
    'ja': ('name_ja', 'display_name_ja', None, 'short_name_ja', 'name_ja', 'name_ja'),
    'zh': ('name_zh', 'display_name_zh', None, 'short_name_zh', 'name_zh', 'name_zh'),
}


def korean_names() -> dict[str, dict[str, str]]:
    catalogs = {kind: (kind, *columns) for kind, columns in NAME_COLUMNS.items()}
    catalogs["team_short_names"] = ("teams", "team_id", "short_name_ko")
    catalogs["coaches"] = ("coaches", "coach_id", "name_ko")
    return _read_catalogs(catalogs)


def localized_names(locale: str) -> dict[str, dict[str, str]]:
    team, player, team_short, player_short, country, coach = LOCALE_COLUMNS[locale]
    # 번역이 없는 언어는 빈 목록을 보내 화면에서 원문 이름을 쓰게 해요.
    catalogs = {'teams': ('teams', 'team_id', team), 'players': ('players', 'player_id', player),
                'team_short_names': ('teams', 'team_id', team_short),
                'player_short_names': ('players', 'player_id', player_short),
                'competitions': ('competitions', 'competition_id', team),
                'countries': ('countries', 'country_id', country),
                'coaches': ('coaches', 'coach_id', coach)}
    return _read_catalogs(catalogs)


def _read_catalogs(catalogs):
    return {kind: {} if column is None else {str(identifier): name for identifier, name in fetch_all(
        f'SELECT {identifier},{column} FROM {table} WHERE {column} IS NOT NULL ORDER BY {identifier}')}
        for kind, (table, identifier, column) in catalogs.items()}


def korean_name_search(column: str, query: str) -> tuple[str, str]:
    # 검색과 일치도 정렬에서 같은 공백 제거 규칙을 써요. column에는 고정된 DB 열 이름만 넣어요.
    return f"LOWER(REGEXP_REPLACE({column}, '[[:space:]]', ''))", "".join(query.casefold().split())


def korean_name_ids(kind: str, query: str) -> tuple[int, ...]:
    identifier, column = NAME_COLUMNS[kind]
    columns = [column, "short_name_ko"] if kind == "teams" else [column]
    searches = [korean_name_search(name, query) for name in columns]
    if not searches[0][1]:
        return ()
    # 사용자 검색어는 SQL 식별자에 넣지 않고, 공백을 뺀 문자열로 비교해요.
    conditions = " OR ".join(f"LOCATE(%s, {expression}) > 0" for expression, _ in searches)
    return tuple(row[0] for row in fetch_all(
        f"SELECT {identifier} FROM {kind} WHERE ({conditions}) ORDER BY {identifier}",
        tuple(needle for _, needle in searches)))
