"""현재 DB 스쿼드의 계약 날짜를 수집해요. 실제 소속 이력은 이적 기록과 구분해요."""
from __future__ import annotations

import json
from datetime import date

from ..core.db import fetch_all, transaction
from ..core.sportmonks import SportmonksClient
from ..core.transfer_team_levels import VERIFIED_NON_SENIOR_TEAM_IDS
from ..core.transfer_windows import get_latest_transfer_window
from .team_squad_members_loader import load_squad_scope
from .teams_loader import SQL_UPSERT_TEAM, _team_row


SQL_SQUAD_PLAYERS = "SELECT player_id FROM team_squad_members WHERE team_id=%s AND season_id=%s"
SQL_INSERT_CONTRACT = """
INSERT INTO player_contracts (team_id, player_id, start_date, end_date, transfer_id)
VALUES (%s,%s,%s,%s,%s)
"""


def build_contract_rows(team_id: int, squad: list[dict], player_ids: set[int]) -> dict:
    # 계약 날짜는 공급자가 준 값만 사용해요. 이적일이나 다음 팀 입단일로 채우지 않아요.
    rows = []
    invalid = []
    missing_dates = []
    supplied_ids = set()
    for item in squad:
        player_id = item["player_id"]
        # 부상·Squad 화면과 같은 DB 명단을 사용해요. 공급자 명단으로 소속을 바꾸지 않아요.
        if player_id not in player_ids:
            continue
        supplied_ids.add(player_id)
        start = date.fromisoformat(item["start"]) if item["start"] is not None else None
        end = date.fromisoformat(item["end"]) if item["end"] is not None else None
        if start is not None and end is not None and start > end:
            # Becker·Jeong은 완전 이적 뒤에도 이전 임대 종료일이 남아 있었어요.
            # 어느 날짜를 고칠지 추정하지 않고 해당 계약 기간을 미제공으로 남겨요.
            invalid.append({"squad_id": item["id"], "player_id": player_id, "start": item["start"], "end": item["end"]})
            continue
        if start is None and end is None:
            missing_dates.append(player_id)
            continue
        # 시작·종료 중 한쪽만 제공돼도 그 값은 보존해요. 종료일로 이탈 여부를 계산하지 않아요.
        # 실제 116건은 계약 시작일과 연결된 이적 날짜가 달랐어요. 공급자 관계 ID만 연결해요.
        rows.append((team_id, player_id, start, end, item["transfer_id"]))
    return {
        "rows": rows, "invalid_intervals": invalid, "missing_dates": missing_dates,
        "missing_players": sorted(player_ids - supplied_ids),
    }


def refresh_current_contracts(team_ids: list[int] | None = None, *, check: bool = False) -> dict:
    scope = load_squad_scope(current_only=True, team_ids=team_ids)
    client = SportmonksClient()
    totals = {"teams": 0, "contracts": 0, "invalid_intervals": 0, "missing_dates": 0, "missing_players": 0}
    try:
        for index, target in enumerate(scope, 1):
            team_id, season_id = target["team_id"], target["season_id"]
            squad = client.get_team_squad(team_id)
            if check:
                player_ids = {row[0] for row in fetch_all(SQL_SQUAD_PLAYERS, (team_id, season_id))}
                result = build_contract_rows(team_id, squad, player_ids)
            else:
                # 명단 조회와 계약 교체를 함께 처리해 실패하면 기존 계약을 보존해요.
                with transaction() as conn:
                    with conn.cursor() as cursor:
                        cursor.execute(SQL_SQUAD_PLAYERS, (team_id, season_id))
                        result = build_contract_rows(team_id, squad, {row[0] for row in cursor.fetchall()})
                        cursor.execute("DELETE FROM player_contracts WHERE team_id=%s", (team_id,))
                        if result["rows"]:
                            cursor.executemany(SQL_INSERT_CONTRACT, result["rows"])
            totals["teams"] += 1
            totals["contracts"] += len(result["rows"])
            for key in ("invalid_intervals", "missing_dates", "missing_players"):
                totals[key] += len(result[key])
            print(f"[contracts {index}/{len(scope)}] team_id={team_id} contracts={len(result['rows'])} check={check}", flush=True)
            details = {key: result[key] for key in ("invalid_intervals", "missing_dates", "missing_players") if result[key]}
            if details:
                print(json.dumps({"team_id": team_id, **details}, ensure_ascii=False), flush=True)
    finally:
        client._session.close()
    return totals


def collect_player_contracts(player_ids: list[int], *, check: bool = False) -> dict:
    client = SportmonksClient()
    selected = sorted(set(player_ids))
    totals = {"players": 0, "contracts": 0, "invalid_intervals": [], "unavailable_players": []}
    try:
        for index, player_id in enumerate(selected, 1):
            records = client.get_player_current_teams(player_id)
            totals["players"] += 1
            if records is None:
                # 43393은 공급자가 선수 자체를 조회 불가로 응답했어요. 계약이 없다는 뜻이 아니에요.
                # 기존 계약은 보존하고 확인하지 못한 선수 ID를 남겨요.
                totals["unavailable_players"].append(player_id)
                print(f"[contracts {index}/{len(selected)}] player_id={player_id} unavailable=True check={check}", flush=True)
                continue
            teams, contracts = [], []
            for item in records:
                team = item["team"]
                # 선수 단건 teams에는 국가대표도 있었어요. 현재 구단 계약만 선택해요.
                if team["type"] == "national" or team["placeholder"] or team["id"] in VERIFIED_NON_SENIOR_TEAM_IDS:
                    continue
                # 구단 분류는 Club History 표시 기준이에요. 출발 선수의 확인된 계약을 버리지 않아요.
                result = build_contract_rows(team["id"], [item], {player_id})
                teams.append(_team_row(team, "contract.team"))
                contracts.extend(result["rows"])
                totals["invalid_intervals"].extend(result["invalid_intervals"])
            if not check:
                with transaction() as conn:
                    with conn.cursor() as cursor:
                        if teams:
                            cursor.executemany(SQL_UPSERT_TEAM, teams)
                        cursor.execute("DELETE FROM player_contracts WHERE player_id=%s", (player_id,))
                        if contracts:
                            cursor.executemany(SQL_INSERT_CONTRACT, contracts)
            totals["contracts"] += len(contracts)
            print(f"[contracts {index}/{len(selected)}] player_id={player_id} contracts={len(contracts)} check={check}", flush=True)
    finally:
        client._session.close()
    return totals


def refresh_departure_contracts(*, check: bool = False) -> dict:
    scope = load_squad_scope(current_only=True)
    current_players = {row[0] for row in fetch_all("""
        SELECT DISTINCT sm.player_id FROM team_squad_members sm JOIN seasons s ON s.season_id=sm.season_id
        WHERE s.is_current=1 AND s.competition_id IN (8,82,301,384,564)
    """)}
    player_ids = set()
    as_of = date.today()
    for competition_id in sorted({row["competition_id"] for row in scope}):
        window = get_latest_transfer_window(competition_id, as_of)
        if window is None:
            raise ValueError(f"Set verified transfer window first: competition_id={competition_id}")
        team_ids = [row["team_id"] for row in scope if row["competition_id"] == competition_id]
        marks = ",".join("%s" for _ in team_ids)
        player_ids.update(row[0] for row in fetch_all(f"""
            SELECT DISTINCT player_id FROM transfers WHERE from_team_id IN ({marks})
              AND transfer_date BETWEEN %s AND %s
        """, (*team_ids, window["start_date"], min(as_of, window["end_date"]))))
    # Big 5 안에서 옮긴 선수는 현재 스쿼드 수집이 처리해요. 외부로 떠난 선수는 도착팀의 계약이 필요해요.
    return collect_player_contracts(sorted(player_ids - current_players), check=check)
