"""확정 이적 원문을 선수 단위로 저장하고, Club History에서 확인한 1군만 표시해요."""
from __future__ import annotations

import json
from datetime import date, timedelta

from ..core.db import fetch_all, transaction
from ..core.sportmonks import SportmonksClient
from ..core.transfer_source_rules import WITHHELD_PLAYER_MOVEMENTS
from ..core.transfer_team_levels import VERIFIED_NON_SENIOR_TEAM_IDS, load_senior_team_ids
from ..core.transfer_windows import get_latest_transfer_window
from .players_loader import insert_missing_player_profiles
from .team_squad_members_loader import load_squad_scope
from .teams_loader import SQL_UPSERT_TEAM, _team_row

SQL_UPSERT_TRANSFER = """
INSERT INTO transfers (transfer_id, player_id, from_team_id, to_team_id, type_id, amount, transfer_date)
VALUES (%s,%s,%s,%s,%s,%s,%s)
ON DUPLICATE KEY UPDATE player_id=VALUES(player_id), from_team_id=VALUES(from_team_id),
to_team_id=VALUES(to_team_id), type_id=VALUES(type_id), amount=VALUES(amount), transfer_date=VALUES(transfer_date)
"""
SQL_UPSERT_TYPE = """
INSERT INTO transfer_types (type_id, name) VALUES (%s,%s)
ON DUPLICATE KEY UPDATE name=VALUES(name)
"""


def build_transfer_rows(player_id: int, payload: list[dict], senior_ids: set[int]) -> dict:
    rows, teams, types, profiles, unclassified = [], {}, {}, {}, {}
    confirmed = sorted((item for item in payload if item["completed"] is True), key=lambda x: (x["date"], x["id"]))
    repeated_movements = []
    previous = None
    for item in confirmed:
        if item["player_id"] != player_id:
            raise ValueError(f"Transfer belongs to another player: {item['id']}")
        # 확인된 중복 ID는 공통 클라이언트에서 제외해요. 그 밖의 연속된 동일 이동은 선택하지 않고 보고해요.
        movement = (item["from_team_id"], item["to_team_id"])
        if previous is not None and item["type_id"] == previous["type_id"] and movement == (previous["from_team_id"], previous["to_team_id"]):
            pair = (previous["id"], item["id"])
            if pair != WITHHELD_PLAYER_MOVEMENTS.get(player_id):
                repeated_movements.append(list(pair))
        previous = item
        sides = []
        related_teams = []
        for key in ("fromteam", "toteam"):
            team = item[key]
            # 실제 TBC(260131)는 구단이 아니에요. 구단 간 이동의 원래 ID는 보존해요.
            if team is None or team["placeholder"]:
                sides.append(None)
            else:
                # 미분류 구단도 원래 관계는 보존해요. 2026-09-09 결정에 따라 화면에서만 제외해요.
                related_teams.append(_team_row(team, key))
                sides.append(team["id"])
                if team["id"] not in senior_ids and team["id"] not in VERIFIED_NON_SENIOR_TEAM_IDS:
                    unclassified[team["id"]] = team["name"]
        for team_row in related_teams:
            teams[team_row[0]] = team_row
        types[item["type_id"]] = item["type"]["name"]
        profiles[player_id] = item["player"]
        # amount의 NULL과 제공된 0을 구분해요. 통화 확인 전에는 EUR로 이름 붙이지 않아요.
        rows.append((item["id"], player_id, *sides, item["type_id"], item["amount"], date.fromisoformat(item["date"])))
    return {"rows": rows, "teams": list(teams.values()), "types": list(types.items()), "profiles": profiles,
            "unclassified_teams": unclassified, "repeated_movements": repeated_movements}


def replace_player_transfers(player_id: int, rows: dict) -> None:
    # 미분류·승인된 표시 보류 원문은 저장해요. 새로 발견한 충돌은 확인한 뒤 저장해요.
    if rows["repeated_movements"]:
        raise ValueError(f"Review transfer source for player={player_id}: repeated={rows['repeated_movements']}")
    with transaction() as conn:
        with conn.cursor() as cursor:
            if rows["teams"]:
                cursor.executemany(SQL_UPSERT_TEAM, rows["teams"])
            insert_missing_player_profiles(cursor, rows["profiles"])
            if rows["types"]:
                cursor.executemany(SQL_UPSERT_TYPE, rows["types"])
            if rows["rows"]:
                # 계약이 참조하는 기존 이적 ID를 삭제하지 않도록 먼저 갱신해요.
                cursor.executemany(SQL_UPSERT_TRANSFER, rows["rows"])
                ids = [row[0] for row in rows["rows"]]
                marks = ",".join("%s" for _ in ids)
                cursor.execute(f"DELETE FROM transfers WHERE player_id=%s AND transfer_id NOT IN ({marks})", (player_id, *ids))
            else:
                cursor.execute("DELETE FROM transfers WHERE player_id=%s", (player_id,))


def collect_player_transfers(player_ids: list[int], *, check: bool = False) -> dict:
    senior_ids = load_senior_team_ids()
    selected = sorted(set(player_ids))
    totals = {"players": 0, "transfers": 0, "review_players": [], "unclassified_teams": {}, "withheld_players": []}
    client = SportmonksClient()
    try:
        for index, player_id in enumerate(selected, 1):
            rows = build_transfer_rows(player_id, list(client.iter_transfers_by_player(player_id)), senior_ids)
            totals["unclassified_teams"].update(rows["unclassified_teams"])
            if player_id in WITHHELD_PLAYER_MOVEMENTS:
                totals["withheld_players"].append(player_id)
            review = {"player_id": player_id, "repeated_movements": rows["repeated_movements"]}
            if rows["repeated_movements"]:
                totals["review_players"].append(review)
                print(json.dumps(review, ensure_ascii=False), flush=True)
            if not check:
                replace_player_transfers(player_id, rows)
            totals["players"] += 1
            totals["transfers"] += len(rows["rows"])
            print(f"[transfers {index}/{len(selected)}] player_id={player_id} transfers={len(rows['rows'])} withheld={player_id in WITHHELD_PLAYER_MOVEMENTS} check={check}", flush=True)
    finally:
        client._session.close()
    return totals


def collect_transfers_for_season(season_name: str, competition_ids: list[int], *, check: bool = False) -> dict:
    scope = [row for competition_id in competition_ids for row in load_squad_scope(season_name, competition_id)]
    player_ids = set()
    for row in scope:
        player_ids.update(item[0] for item in fetch_all(
            "SELECT player_id FROM team_squad_members WHERE team_id=%s AND season_id=%s", (row["team_id"], row["season_id"])))
    # 시즌은 수집할 선수 범위예요. 선택된 선수의 이적 이력은 연도로 자르지 않아요.
    return collect_player_transfers(sorted(player_ids), check=check)


def set_transfer_window(season_name: str, competition_id: int, window_name: str, start: date, end: date) -> None:
    if window_name not in ("summer", "winter") or start > end:
        raise ValueError("Expected summer/winter and start <= end")
    season_id = load_squad_scope(season_name, competition_id)[0]["season_id"]
    # 각국 등록 기간이 달라요. 확정된 날짜만 입력하고 최신 여부는 시작일로 구해요.
    with transaction() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO transfer_windows (season_id, window_name, start_date, end_date) VALUES (%s,%s,%s,%s)
                ON DUPLICATE KEY UPDATE start_date=VALUES(start_date), end_date=VALUES(end_date)
            """, (season_id, window_name, start, end))


def refresh_current_transfers(team_ids: list[int] | None = None, *, check: bool = False) -> dict:
    scope = load_squad_scope(current_only=True, team_ids=team_ids)
    windows = {}
    by_competition = {}
    for row in scope:
        competition_id = row["competition_id"]
        if competition_id not in by_competition:
            by_competition[competition_id] = get_latest_transfer_window(competition_id, date.today())
        window = by_competition[competition_id]
        if window is None:
            raise ValueError(f"Set verified transfer window first: competition_id={row['competition_id']}")
        windows[row["team_id"]] = window
    selected = set()
    start = min(row["start_date"] for row in windows.values())
    end = min(date.today(), max(row["end_date"] for row in windows.values()))
    client = SportmonksClient()
    try:
        # 기존 31일 조회 범위를 유지하고 팀마다 같은 구간을 반복 요청하지 않아요.
        while start <= end:
            chunk_end = min(start + timedelta(days=30), end)
            for item in client.iter_transfers_between_dates(start, chunk_end):
                if item["completed"] is not True:
                    continue
                for team_id in (item["from_team_id"], item["to_team_id"]):
                    window = windows.get(team_id)
                    if window is not None and window["start_date"] <= date.fromisoformat(item["date"]) <= window["end_date"]:
                        selected.add(item["player_id"])
            start = chunk_end + timedelta(days=1)
    finally:
        client._session.close()
    # 최근 행만 저장하면 Club History가 잘리므로 해당 선수의 전체 이력을 같은 경로로 수집해요.
    return collect_player_transfers(sorted(selected), check=check)


def refresh_team_transfers(team_id: int, *, check: bool = False) -> dict:
    return refresh_current_transfers([team_id], check=check)
