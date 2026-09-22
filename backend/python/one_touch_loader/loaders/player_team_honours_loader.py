from __future__ import annotations

import argparse
from collections import defaultdict
from functools import lru_cache
import json
from pathlib import Path
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
  season_id,
  team_name,
  team_image_path,
  competition_name,
  season_name
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
"""

SQL_HONOUR_METADATA = """
SELECT h.player_id,h.team_id,h.competition_id,h.season_id,
       COALESCE(c.name,h.competition_name) AS competition_name,
       COALESCE(s.name,h.season_name) AS season_name
FROM player_team_honours h
LEFT JOIN competitions c ON c.competition_id=h.competition_id
LEFT JOIN seasons s ON s.season_id=h.season_id
ORDER BY h.player_id,h.team_id,h.competition_id,h.season_id
"""

SQL_FILL_COMPETITION_NAME = """
UPDATE player_team_honours SET competition_name=%s
WHERE player_id=%s AND team_id=%s AND competition_id=%s AND season_id=%s
  AND competition_name IS NULL
"""

EXPECTED_RESULT_MAPPINGS = {
    (1, "Winner", 1),
    (2, "Runner-up", 2),
}


@lru_cache(maxsize=1)
def _honour_catalog():
    path = Path(__file__).parents[1] / "core/honour_competition_names.json"
    return json.loads(path.read_text(encoding="utf-8"))


def _competition_name(competition_id, supplied_name):
    # 구독 밖의 대회는 선수 우승 응답에서도 league=null이에요.
    # 공식 공개 목록에서 같은 ID로 확인한 이름만 보완하고, 시즌은 추정하지 않아요.
    if supplied_name is not None:
        return supplied_name
    entry = _honour_catalog()["competitions"].get(str(competition_id))
    return entry["name"] if entry else None


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

        # 수집 대상 밖의 과거 대회는 마스터에 없어요. 제공된 표시 정보만 우승 기록에 보존해요.
        def metadata(field, expected_id, key):
            value = item.get(field)
            if value is None:
                return None
            value = _require_dict(value, f"trophy.{field}")
            if value.get("id") != expected_id:
                raise ValueError(f"trophy.{field} id mismatch")
            result = value.get(key)
            if result is None:
                return None
            return _require_string(result, f"trophy.{field}.{key}")

        row = (player_id, team_id, competition_id, season_id,
               metadata("team", team_id, "name"), metadata("team", team_id, "image_path"),
               _competition_name(competition_id, metadata("league", competition_id, "name")),
               metadata("season", season_id, "name"))
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


def prepare_metadata_updates(rows):
    """기존 우승을 유지하면서 보완할 대회명과 아직 필요한 시즌 정보를 정리해요."""
    updates = []
    missing_competitions = defaultdict(int)
    missing_seasons = {}
    missing_names_before = 0
    for row in rows:
        competition_id = row["competition_id"]
        name = _competition_name(competition_id, row["competition_name"])
        if row["competition_name"] is None:
            missing_names_before += 1
            if name is not None:
                entry = _honour_catalog()["competitions"][str(competition_id)]
                updates.append({key: row[key] for key in (
                    "player_id", "team_id", "competition_id", "season_id")} | {
                        "competition_name": name,
                        "source_url": _honour_catalog()["sources"][entry["source"]]})
            else:
                missing_competitions[competition_id] += 1
        if row["season_name"] is None:
            key = (competition_id, row["season_id"])
            pending = missing_seasons.setdefault(key, {
                "competition_id": competition_id, "competition_name": name,
                "season_id": row["season_id"], "affected_honours": 0})
            pending["affected_honours"] += 1
    return {
        "summary": {
            "honours_scanned": len(rows),
            "missing_competition_names_before": missing_names_before,
            "competition_names_to_fill": len(updates),
            "projected_missing_competition_names": sum(missing_competitions.values()),
            "missing_season_names": sum(r["affected_honours"] for r in missing_seasons.values()),
            "unresolved_competition_ids": len(missing_competitions),
            "unresolved_season_ids": len(missing_seasons),
        },
        "updates": updates,
        "unresolved_competitions": [
            {"competition_id": cid, "affected_honours": count}
            for cid, count in sorted(missing_competitions.items())],
        "unresolved_seasons": [missing_seasons[key] for key in sorted(missing_seasons)],
    }


def _read_honour_metadata():
    fields = ("player_id", "team_id", "competition_id", "season_id", "competition_name", "season_name")
    return [dict(zip(fields, row)) for row in fetch_all(SQL_HONOUR_METADATA)]


def fill_missing_competition_names(*, apply=False):
    plan = prepare_metadata_updates(_read_honour_metadata())
    plan.update(applied=apply, updated_rows=0)
    if apply and plan["updates"]:
        # 표시 정보만 채워요. 우승 행의 추가·삭제나 기존 이름 덮어쓰기는 하지 않아요.
        with transaction() as connection:
            with connection.cursor() as cursor:
                cursor.executemany(SQL_FILL_COMPETITION_NAME, [
                    (r["competition_name"], r["player_id"], r["team_id"], r["competition_id"], r["season_id"])
                    for r in plan["updates"]])
                plan["updated_rows"] = cursor.rowcount
    if apply:
        plan["observed_after"] = prepare_metadata_updates(_read_honour_metadata())["summary"]
    return plan


def main(argv=None):
    parser = argparse.ArgumentParser(description="선수 우승 이력의 빈 대회명을 보완하고 미확인 시즌을 보고해요.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--apply", action="store_true")
    parser.add_argument("--output", type=Path, help="변경 대상과 미확인 ID 목록을 JSON으로 저장해요.")
    args = parser.parse_args(argv)
    result = fill_missing_competition_names(apply=args.apply)
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: result[key] for key in ("applied", "updated_rows", "summary", "observed_after")
                      if key in result}, ensure_ascii=False))


if __name__ == "__main__":
    main()
