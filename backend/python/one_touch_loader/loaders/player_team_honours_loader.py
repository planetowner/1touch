from __future__ import annotations

from typing import Dict, List, Tuple

from ..core.db import fetch_all, transaction
from ..core.sportmonks import SportmonksClient


SQL_SELECT_PLAYER = """
SELECT player_id
FROM players
WHERE player_id = %s
"""

SQL_DELETE_PLAYER_HONOURS = """
DELETE FROM player_team_honours
WHERE player_id = %s
"""

SQL_INSERT_PLAYER_HONOUR = """
INSERT INTO player_team_honours (
  player_id,
  team_id,
  competition_id,
  season_id
) VALUES (%s,%s,%s,%s)
"""

EXPECTED_RESULT_MAPPINGS = {
    (1, "Winner", 1),
    (2, "Runner-up", 2),
}


def _require_dict(value, field_name: str) -> Dict:
    if not isinstance(value, dict):
        raise ValueError(f"Missing or invalid object: {field_name}={value!r}")
    return value


def _require_list(value, field_name: str) -> List:
    if not isinstance(value, list):
        raise ValueError(f"Missing or invalid list: {field_name}={value!r}")
    return value


def _require_int(value, field_name: str) -> int:
    if type(value) is not int:
        raise ValueError(f"Missing or invalid integer: {field_name}={value!r}")
    return value


def _require_string(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string: {field_name}={value!r}")
    return value.strip()


def _winner_rows(payload: Dict, player_id: int) -> Tuple[List[Tuple], int]:
    trophies = _require_list(payload.get("trophies"), "player.trophies")
    rows: List[Tuple] = []
    for index, raw_item in enumerate(trophies):
        item = _require_dict(raw_item, f"trophies[{index}]")
        team_id = _require_int(item.get("team_id"), "trophy.team_id")
        # Sportmonks의 필드 이름은 league_id예요. 1Touch는 같은 값을
        # player_team_honours.competition_id에 저장해요.
        competition_id = _require_int(
            item.get("league_id"),
            "Sportmonks trophy.league_id",
        )
        season_id = _require_int(item.get("season_id"), "trophy.season_id")
        trophy_id = _require_int(item.get("trophy_id"), "trophy.trophy_id")
        trophy = _require_dict(item.get("trophy"), "trophy.trophy")

        result_mapping = (
            trophy_id,
            _require_string(trophy.get("name"), "trophy.trophy.name"),
            _require_int(trophy.get("position"), "trophy.trophy.position"),
        )
        if result_mapping not in EXPECTED_RESULT_MAPPINGS:
            raise ValueError(
                "Sportmonks trophy result mapping changed: "
                f"{result_mapping!r}"
            )
        if result_mapping[2] != 1:
            continue

        row = (player_id, team_id, competition_id, season_id)
        rows.append(row)

    return rows, len(trophies)


def refresh_player_team_honours(player_id: int) -> Dict[str, int]:
    if type(player_id) is not int:
        raise ValueError(f"player_id must be an integer: {player_id!r}")
    if not fetch_all(SQL_SELECT_PLAYER, (player_id,)):
        raise ValueError(f"players table does not contain player_id={player_id}")

    payload = SportmonksClient().get_player_with_trophies(player_id)
    rows, source_rows = _winner_rows(payload, player_id)

    with transaction() as connection:
        with connection.cursor() as cursor:
            cursor.execute(SQL_DELETE_PLAYER_HONOURS, (player_id,))
            if rows:
                cursor.executemany(SQL_INSERT_PLAYER_HONOUR, rows)

    result = {
        "player_id": player_id,
        "source_trophies": source_rows,
        "winning_honours": len(rows),
    }
    print(
        f"[player-team-honours] player {player_id}: "
        f"source_trophies={source_rows} winners={len(rows)}"
    )
    return result
