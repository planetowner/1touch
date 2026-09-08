from __future__ import annotations

import json
import sys
from pathlib import Path

from dotenv import load_dotenv


BACKEND_ROOT = Path(__file__).resolve().parents[2]
PYTHON_ROOT = BACKEND_ROOT / "python"
PACKAGE_ROOT = PYTHON_ROOT / "one_touch_loader"

sys.path.insert(0, str(PYTHON_ROOT))
load_dotenv(BACKEND_ROOT / ".env")


BIG5_COMPETITION_IDS = {8, 82, 301, 384, 564}


def verify_python_sources() -> int:
    paths = sorted(PACKAGE_ROOT.rglob("*.py"))
    for path in paths:
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
    return len(paths)


def verify_write_contract() -> dict:
    from one_touch_loader.cli import _parse_competition_ids
    from one_touch_loader.loaders.players_loader import (
        SQL_UPSERT_PLAYER,
        SQL_UPSERT_SPORTMONKS_PLAYER_ID,
    )
    from one_touch_loader.loaders.team_squad_members_loader import (
        SQL_UPSERT_SQUAD_MEMBER,
    )

    if "INSERT INTO players" not in SQL_UPSERT_PLAYER:
        raise AssertionError("Player loader does not write players")
    if "INSERT INTO player_external_ids" not in SQL_UPSERT_SPORTMONKS_PLAYER_ID:
        raise AssertionError("Player loader does not write Sportmonks external IDs")
    if "INSERT INTO team_squad_members" not in SQL_UPSERT_SQUAD_MEMBER:
        raise AssertionError("Squad loader does not write team_squad_members")

    players_loader_source = (
        PACKAGE_ROOT / "loaders" / "players_loader.py"
    ).read_text(encoding="utf-8")
    if "sm.get_player_or_none(player_id)" not in players_loader_source:
        raise AssertionError("Player loader does not fetch profiles by player ID")
    if "_upsert_reconstructed_players" in players_loader_source:
        raise AssertionError("Player loader still writes embedded squad rows directly")

    forbidden_squad_columns = {
        "squad_role",
        "leadership_role",
        "captain",
    }
    written_forbidden_columns = sorted(
        column
        for column in forbidden_squad_columns
        if column in SQL_UPSERT_SQUAD_MEMBER
    )
    if written_forbidden_columns:
        raise AssertionError(
            "Squad loader writes 1Touch-owned fields: "
            f"{written_forbidden_columns!r}"
        )

    competition_ids = _parse_competition_ids(["8", "82", "301", "8"])
    if competition_ids != [8, 82, 301]:
        raise AssertionError(
            f"Unexpected multiple competition IDs: {competition_ids!r}"
        )

    try:
        _parse_competition_ids(["8,"])
    except ValueError:
        pass
    else:
        raise AssertionError("Comma-separated competition IDs must be rejected")

    return {
        "players_command_writes": ["players", "player_external_ids"],
        "squads_command_writes": ["team_squad_members"],
        "squad_roles_preserved": True,
        "player_profile_source": "/v3/football/players/{player_id}",
        "squad_profile_fallback": "missing top-level data only",
        "multiple_competition_ids": True,
        "competition_id_separator": "space",
    }


def verify_scope() -> dict:
    from one_touch_loader.loaders.team_squad_members_loader import load_squad_scope

    all_scope = load_squad_scope()
    selected_scope = load_squad_scope(
        season_name="2017/2018",
        competition_id=8,
    )

    all_keys = {
        (int(item["team_id"]), int(item["season_id"]))
        for item in all_scope
    }
    if len(all_keys) != len(all_scope):
        raise AssertionError("Big 5 squad scope contains duplicate team seasons")

    unexpected_competitions = sorted(
        {
            int(item["competition_id"])
            for item in all_scope
        }
        - BIG5_COMPETITION_IDS
    )
    if unexpected_competitions:
        raise AssertionError(
            f"Squad scope contains non-Big 5 competitions: {unexpected_competitions}"
        )

    unsupported_seasons = sorted(
        {
            str(item["season_name"])
            for item in all_scope
            if int(str(item["season_name"])[:4]) < 2017
        }
    )
    if unsupported_seasons:
        raise AssertionError(
            f"Squad scope contains seasons before 2017/2018: {unsupported_seasons}"
        )

    if any(
        item["season_name"] != "2017/2018"
        or int(item["competition_id"]) != 8
        for item in selected_scope
    ):
        raise AssertionError("Selected squad scope escaped its league season")

    current_count = sum(bool(item["is_current"]) for item in all_scope)
    return {
        "all_team_seasons": len(all_scope),
        "historical_team_seasons": len(all_scope) - current_count,
        "current_team_seasons": current_count,
        "selected_2017_2018_premier_league_teams": len(selected_scope),
        "competition_ids": sorted(BIG5_COMPETITION_IDS),
    }


def main() -> None:
    result = {
        "compiled_python_files": verify_python_sources(),
        "write_contract": verify_write_contract(),
        "scope": verify_scope(),
        "commands": {
            "teams": [
                "teams all",
                "teams <season_name> <competition_id> [competition_id ...]",
            ],
            "players": [
                "players all",
                "players <season_name> <competition_id> [competition_id ...]",
            ],
            "squads": [
                "squads all",
                "squads <season_name> <competition_id> [competition_id ...]",
            ],
        },
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print("Player and squad collection contract verification passed.")


if __name__ == "__main__":
    main()
