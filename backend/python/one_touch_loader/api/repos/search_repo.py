from ...core.football_names import korean_name_ids
from ..db import fetch_all_dict
from .fixtures_repo import search_fixtures
from .player_detail_repo import list_player_comparison_candidates


def search(query: str, limit: int) -> dict:
    query = query.strip()
    if not query:
        return {"players": [], "teams": [], "fixtures": []}
    team_ids = korean_name_ids("teams", query)
    localized = (" OR t.team_id IN (" + ",".join(["%s"] * len(team_ids)) + ")") if team_ids else ""
    teams = fetch_all_dict(f"""SELECT t.team_id,t.name,t.short_name,t.short_code,t.image_path FROM teams t
        WHERE EXISTS (SELECT 1 FROM team_seasons ts JOIN seasons s ON s.season_id=ts.season_id
            JOIN competitions c ON c.competition_id=s.competition_id
            WHERE ts.team_id=t.team_id AND s.is_current=1 AND s.competition_id IN (8,82,301,384,564)
            AND (t.name LIKE %s OR t.short_name LIKE %s OR t.short_code LIKE %s OR c.name LIKE %s {localized}))
        ORDER BY t.name,t.team_id LIMIT %s""", (f"%{query}%",) * 4 + (*team_ids, limit))
    return {
        "players": list_player_comparison_candidates(query, limit=limit),
        "teams": teams,
        "fixtures": search_fixtures(query, team_ids=team_ids, limit=limit),
    }
