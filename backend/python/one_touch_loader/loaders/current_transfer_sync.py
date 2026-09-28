"""최근 이적 변경과 외부 계약을 갱신하고, 주기적으로 전체 이력을 대조해요."""
from __future__ import annotations

from datetime import date, timedelta
from time import monotonic

from ..core.db import fetch_all, transaction
from ..core.player_membership import season_start_date
from ..core.sportmonks import SportmonksClient
from ..core.transfer_team_levels import load_senior_team_ids
from . import player_contracts_loader as contracts
from . import team_squad_members_loader as squads
from . import transfers_loader as transfers
from .transfers_loader import fetch_transfers_between


TRANSFER_COLUMNS = "transfer_id,player_id,from_team_id,to_team_id,type_id,amount,transfer_date"
SQL_CONTRACT_TRANSFERS = "SELECT transfer_id FROM player_contracts WHERE player_id=%s AND transfer_id IS NOT NULL"


def fetch_current_team_transfers(client, scope: list[dict], today: date) -> dict[int, list[dict]]:
    by_team = {item["team_id"]: [] for item in scope}
    start = min(season_start_date(item["season_name"]) for item in scope)
    for item in fetch_transfers_between(client, start, today):
        for team_id in {item["from_team_id"], item["to_team_id"]} & by_team.keys():
            by_team[team_id].append(item)
    return by_team


def changed_player_ids(payload: list[dict], stored: list[tuple], team_ids: set[int], player_ids: set[int]) -> set[int]:
    before = {row[0]: tuple(row) for row in stored}
    after = {}
    for item in payload:
        old = before.get(item["id"])
        if not (item["player_id"] in player_ids or item["from_team_id"] in team_ids or item["to_team_id"] in team_ids
                or (old is not None and (old[1] in player_ids or old[2] in team_ids or old[3] in team_ids))):
            continue
        # 부분 응답에는 이력의 연속성이 없으므로 행별 저장 값만 비교해요.
        for row in transfers.build_transfer_rows(item["player_id"], [item], set())["rows"]:
            after[row[0]] = row
    changed = set()
    for tid in before.keys() | after.keys():
        old, new = before.get(tid), after.get(tid)
        if old == new:
            continue
        rows = [row for row in (old, new) if row is not None]
        if any(row[1] in player_ids or row[2] in team_ids or row[3] in team_ids for row in rows):
            changed.update(row[1] for row in rows)
    return changed


def sync_player_history_and_contracts(client, player_id: int, senior_ids: set[int], *, history: bool, apply: bool) -> dict:
    payload = list(client.iter_transfers_by_player(player_id)) if history else []
    movement_rows = transfers.build_transfer_rows(player_id, payload, senior_ids)
    if movement_rows["repeated_movements"]:
        raise ValueError(f"Review transfer source for player={player_id}: repeated={movement_rows['repeated_movements']}")
    records = client.get_player_current_teams(player_id)
    contract_rows = contracts.build_player_contract_rows(player_id, records) if records is not None else None
    dependencies = transfers.prepare_contract_transfers(
        client, contract_rows["rows"] if contract_rows else [], {item["id"]: item for item in payload},
        player_histories={player_id: payload} if history else None,
    )
    retained = []
    history_ids = {row[0] for row in movement_rows["rows"]}
    if history and not apply:
        referenced = ({row[4] for row in contract_rows["rows"] if row[4] is not None}
                      if contract_rows is not None else
                      {row[0] for row in fetch_all(SQL_CONTRACT_TRANSFERS, (player_id,))})
        retained = sorted(referenced - history_ids)
    if apply:
        with transaction() as connection:
            with connection.cursor() as cursor:
                if history:
                    transfers.write_transfer_rows(cursor, movement_rows)
                for dependency in dependencies:
                    transfers.write_transfer_rows(cursor, dependency)
                if contract_rows is not None:
                    contracts.write_player_contract_rows(cursor, player_id, contract_rows)
                if history:
                    cursor.execute(SQL_CONTRACT_TRANSFERS, (player_id,))
                    # 현재 계약의 참조는 RESTRICT 외래 키예요. 이력 응답에 없어도 계약이 쓰는 행은 보존해요.
                    retained = sorted({row[0] for row in cursor.fetchall()} - history_ids)
                    transfers.delete_stale_player_transfers(cursor, player_id, sorted(history_ids | set(retained)))
    return {"player_id": player_id, "history_fetched": history, "transfers": len(movement_rows["rows"]),
            "contracts": len(contract_rows["rows"]) if contract_rows else 0,
            "contract_unavailable": records is None,
            "invalid_contract_intervals": contract_rows["invalid_intervals"] if contract_rows else [],
            "retained_contract_transfer_ids": retained,
            "unclassified_teams": movement_rows["unclassified_teams"]}


def _sync(*, reconcile: bool, apply: bool) -> dict:
    started_at = monotonic()
    client = SportmonksClient()
    scope = squads.load_squad_scope(current_only=True)
    team_ids = {item["team_id"] for item in scope}
    current_players = squads.load_current_squad_player_ids(scope)
    today = date.today()
    season_start = min(season_start_date(item["season_name"]) for item in scope)
    stored_season = fetch_all(
        f"SELECT {TRANSFER_COLUMNS} FROM transfers WHERE transfer_date BETWEEN %s AND %s", (season_start, today),
    )
    related = {row[1] for row in stored_season if row[2] in team_ids or row[3] in team_ids}
    departures = {row[1] for row in stored_season if row[2] in team_ids} - current_players
    # 이적일은 수정 시각이 아니므로 최근 구간을 겹쳐 조회하고 주간 전체 대조로 보완해요.
    start = season_start if reconcile else today - timedelta(days=6)
    try:
        payload = fetch_transfers_between(client, start, today)
        # 날짜가 바뀐 기존 ID도 이전 값과 비교해요.
        ids = [item["id"] for item in payload]
        stored = fetch_all(
            f"SELECT {TRANSFER_COLUMNS} FROM transfers WHERE transfer_date BETWEEN %s AND %s", (start, today),
        )
        if ids:
            marks = ",".join("%s" for _ in ids)
            stored.extend(fetch_all(f"SELECT {TRANSFER_COLUMNS} FROM transfers WHERE transfer_id IN ({marks})", tuple(ids)))
        changed = changed_player_ids(payload, stored, team_ids, current_players | related)
        history_players = set(changed)
        if reconcile:
            # 범위 밖 과거 정정·삭제도 잡도록 현재 선수와 이번 시즌 이동 선수의 전체 이력을 확인해요.
            history_players.update(current_players | related)
            history_players.update(item["player_id"] for item in payload
                                   if item["completed"] is True and
                                   (item["from_team_id"] in team_ids or item["to_team_id"] in team_ids))
        selected = sorted(history_players | departures)
        senior_ids = load_senior_team_ids() if history_players else set()
        results = []
        mode = "transfer-reconciliation" if reconcile else "transfers"
        print(f"[current-season {mode}] changed={len(changed)} histories={len(history_players)} departures={len(departures)}", flush=True)
        for index, player_id in enumerate(selected, 1):
            before = client.request_count
            result = sync_player_history_and_contracts(
                client, player_id, senior_ids, history=player_id in history_players, apply=apply,
            )
            result["api_requests"] = client.request_count - before
            results.append(result)
            print(f"[current-season {mode} {index}/{len(selected)}] player_id={player_id} "
                  f"history={result['history_fetched']} transfers={result['transfers']} "
                  f"contracts={result['contracts']} unavailable={result['contract_unavailable']} "
                  f"requests={result['api_requests']}", flush=True)
        return {"mode": mode, "apply": apply, "start_date": str(start), "end_date": str(today),
                "received_transfers": len(payload), "changed_players": len(changed),
                "history_players": len(history_players), "departure_players": len(departures),
                "players": len(selected), "results": results,
                "api_requests": client.request_count, "pages": client.page_count,
                "elapsed_seconds": round(monotonic() - started_at, 2)}
    finally:
        client._session.close()


def sync_current_transfers(*, apply: bool = False) -> dict:
    return _sync(reconcile=False, apply=apply)


def reconcile_current_transfers(*, apply: bool = False) -> dict:
    return _sync(reconcile=True, apply=apply)
