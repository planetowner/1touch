"""일반·짧은 표시 이름은 언어별로 같은 DB 카탈로그를 사용해요."""
from .db import fetch_all

NAME_COLUMNS = {
    "teams": ("team_id", "name_ko"),
    "players": ("player_id", "display_name_ko"),
}
LOCALE_COLUMNS = {
    'en': ('name', 'display_name', 'short_name', 'short_name'),
    'ko': ('name_ko', 'display_name_ko', 'short_name_ko', 'short_name_ko'),
    'ja': ('name_ja', 'display_name_ja', None, 'short_name_ja'),
    'zh': ('name_zh', 'display_name_zh', None, 'short_name_zh'),
}


def korean_names() -> dict[str, dict[str, str]]:
    catalogs = {kind: (kind, *columns) for kind, columns in NAME_COLUMNS.items()}
    catalogs["team_short_names"] = ("teams", "team_id", "short_name_ko")
    return _read_catalogs(catalogs)


def localized_names(locale: str) -> dict[str, dict[str, str]]:
    team, player, team_short, player_short = LOCALE_COLUMNS[locale]
    # 일본어·중국어 팀 짧은 이름은 아직 적재한 값이 없어 빈 목록으로 응답해요.
    catalogs = {'teams': ('teams', 'team_id', team), 'players': ('players', 'player_id', player),
                'team_short_names': ('teams', 'team_id', team_short),
                'player_short_names': ('players', 'player_id', player_short)}
    return _read_catalogs(catalogs)


def _read_catalogs(catalogs):
    return {kind: {} if column is None else {str(identifier): name for identifier, name in fetch_all(
        f'SELECT {identifier},{column} FROM {table} WHERE {column} IS NOT NULL ORDER BY {identifier}')}
        for kind, (table, identifier, column) in catalogs.items()}


def korean_name_ids(kind: str, query: str) -> tuple[int, ...]:
    needle = "".join(query.casefold().split())
    if not needle:
        return ()
    identifier, column = NAME_COLUMNS[kind]
    columns = [column, "short_name_ko"] if kind == "teams" else [column]
    # 사용자 검색어는 SQL 식별자에 넣지 않고, 공백을 뺀 문자열로 비교해요.
    conditions = " OR ".join(
        f"LOCATE(%s, LOWER(REGEXP_REPLACE({name}, '[[:space:]]', ''))) > 0" for name in columns)
    return tuple(row[0] for row in fetch_all(
        f"SELECT {identifier} FROM {kind} WHERE ({conditions}) ORDER BY {identifier}",
        (needle,) * len(columns)))
