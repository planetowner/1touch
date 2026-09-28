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


def fetch_transfers_between(client, start: date, end: date) -> list[dict]:
    """전체 페이지를 받은 뒤에만 응답에 없는 이적을 비교해요."""
    by_id = {}
    while start <= end:
        # 공급자 날짜 조회는 한 요청 구간이 최대 31일이에요.
        chunk_end = min(start + timedelta(days=30), end)
        print(f"[transfers range] start={start} end={chunk_end} fetching", flush=True)
        received = 0
        for received, item in enumerate(client.iter_transfers_between_dates(start, chunk_end), 1):
            by_id[item["id"]] = item
            if received % 1000 == 0:
                print(f"[transfers range] start={start} end={chunk_end} received={received}", flush=True)
        print(f"[transfers range] start={start} end={chunk_end} received={received} complete", flush=True)
        start = chunk_end + timedelta(days=1)
    return list(by_id.values())


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
            write_transfer_rows(cursor, rows)
            delete_stale_player_transfers(cursor, player_id, [row[0] for row in rows["rows"]])


def write_transfer_rows(cursor, rows: dict) -> None:
    """부분 응답도 저장할 수 있지만 기존 이력을 삭제하지는 않아요."""
    if rows["teams"]:
        cursor.executemany(SQL_UPSERT_TEAM, rows["teams"])
    insert_missing_player_profiles(cursor, rows["profiles"])
    if rows["types"]:
        cursor.executemany(SQL_UPSERT_TYPE, rows["types"])
    if rows["rows"]:
        cursor.executemany(SQL_UPSERT_TRANSFER, rows["rows"])


def delete_stale_player_transfers(cursor, player_id: int, transfer_ids: list[int]) -> None:
    """선수의 전체 이력을 끝까지 확인한 경우에만 호출해요."""
    if transfer_ids:
        marks = ",".join("%s" for _ in transfer_ids)
        cursor.execute(f"DELETE FROM transfers WHERE player_id=%s AND transfer_id NOT IN ({marks})", (player_id, *transfer_ids))
    else:
        cursor.execute("DELETE FROM transfers WHERE player_id=%s", (player_id,))


def prepare_contract_transfers(client, contract_rows: list[tuple], available: dict[int, dict] | None = None,
                               *, player_histories: dict[int, list[dict]] | None = None) -> list[dict]:
    """계약의 외래 키를 쓰기 트랜잭션 전에 준비해요. 이력 교체와는 별개예요."""
    required = {row[4]: row[1] for row in contract_rows if row[4] is not None}
    if not required:
        return []
    marks = ",".join("%s" for _ in required)
    existing = dict(fetch_all(f"SELECT transfer_id,player_id FROM transfers WHERE transfer_id IN ({marks})", tuple(required)))
    for tid, pid in existing.items():
        if pid != required[tid]:
            raise ValueError(f"Contract transfer belongs to another player: transfer_id={tid}")
    prepared = []
    missing = required.keys() - existing.keys()
    for pid in sorted({required[tid] for tid in missing}):
        # 계약 때문에 최근 행만 먼저 저장하면 변경 비교에서 같다고 판단해 과거 이력 수집이 빠져요.
        # 새 계약 이적을 준비할 때 전체 이력도 함께 받아 이 순서 의존성을 없애요.
        payload = (player_histories or {}).get(pid)
        history_ready = payload is not None
        if payload is None:
            payload = list(client.iter_transfers_by_player(pid))
        by_id = {item["id"]: item for item in payload}
        history_ids = set(by_id)
        for tid in sorted(tid for tid in missing if required[tid] == pid):
            raw = by_id.get(tid) or (available or {}).get(tid)
            if raw is None:
                raw = client.get_transfer(tid)
            if raw is None or raw["player_id"] != pid or raw["completed"] is not True:
                raise ValueError(f"Unresolved contract transfer: transfer_id={tid}, player_id={pid}")
            by_id[tid] = raw
        # 호출자가 전체 이력을 이미 준비했다면 빠진 계약 참조만 추가로 저장해요.
        selected = [item for tid, item in by_id.items() if not history_ready or tid not in history_ids]
        rows = build_transfer_rows(pid, selected, set())
        if rows["repeated_movements"]:
            raise ValueError(f"Review transfer source for player={pid}: repeated={rows['repeated_movements']}")
        if rows["rows"]:
            prepared.append(rows)
    return prepared


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
        for item in fetch_transfers_between(client, start, end):
            if item["completed"] is not True:
                continue
            for team_id in (item["from_team_id"], item["to_team_id"]):
                window = windows.get(team_id)
                if window is not None and window["start_date"] <= date.fromisoformat(item["date"]) <= window["end_date"]:
                    selected.add(item["player_id"])
    finally:
        client._session.close()
    # 최근 행만 저장하면 Club History가 잘리므로 해당 선수의 전체 이력을 같은 경로로 수집해요.
    return collect_player_transfers(sorted(selected), check=check)


def refresh_team_transfers(team_id: int, *, check: bool = False) -> dict:
    return refresh_current_transfers([team_id], check=check)
