"""현재 시즌의 참가 정보·일정·선수·스쿼드를 각 데이터에 맞는 주기로 동기화해요."""
from __future__ import annotations

from datetime import date
from time import monotonic

from ..core.db import fetch_all, transaction
from ..core.sportmonks import SportmonksClient
from . import fixtures_loader as fixtures
from . import players_loader as players
from . import player_contracts_loader as contracts
from . import transfers_loader as transfer_loader
from . import seasons_loader as seasons
from . import team_squad_members_loader as squads
from . import teams_loader as teams
from .team_seasons_loader import SQL_UPSERT_TEAM_SEASON
from .current_transfer_sync import fetch_current_team_transfers


def _metrics(client: SportmonksClient, started_at: float) -> dict:
    return {
        "api_requests": client.request_count,
        "pages": client.page_count,
        "elapsed_seconds": round(monotonic() - started_at, 2),
    }


def _metadata_scope(client: SportmonksClient) -> list[seasons.SeasonRow]:
    by_competition = {}
    current = {}
    competition_ids = seasons._load_competition_ids()
    for index, competition_id in enumerate(competition_ids, 1):
        print(f"[current-season metadata {index}/{len(competition_ids)}] competition_id={competition_id}", flush=True)
        payload = client.get_league_with_seasons(competition_id)
        rows = seasons._season_rows(competition_id, payload.get("seasons"))
        current_rows = [row for row in rows if row[3]]
        if len(current_rows) != 1:
            raise ValueError(f"Expected one current season for competition_id={competition_id}: {current_rows}")
        current[competition_id] = current_rows[0]
        by_competition[competition_id] = rows

    scope = {row[0]: row for row in current.values()}
    for cup_id, base_id in teams.CUP_BASE_COMPETITION_IDS.items():
        # 시즌 전환일이 대회마다 달라도 컵은 이름이 같은 자국 리그를 기준으로 해요.
        cup = current[cup_id]
        base_rows = [row for row in by_competition[base_id] if row[2] == cup[2]]
        if len(base_rows) != 1:
            raise ValueError(f"Expected base-league season for cup={cup_id}, season={cup[2]!r}")
        scope[base_rows[0][0]] = base_rows[0]
    return sorted(scope.values(), key=lambda row: (row[1], row[0]))


def sync_current_season_metadata(*, apply: bool = False) -> dict:
    started_at = monotonic()
    client = SportmonksClient()
    scope = _metadata_scope(client)
    team_rows = {}
    memberships = set()
    results = []
    for season_id, competition_id, name, is_current in scope:
        if competition_id in teams.CUP_BASE_COMPETITION_IDS:
            # 네 컵의 참가팀은 대상 경기에서만 발견해 전체 컵 참가팀이 유입되지 않게 해요.
            continue
        rows, details = teams._collect_all_season_participants(client, {"id": season_id})
        team_rows.update(rows)
        memberships.update((team_id, season_id) for team_id in rows)
        result = {"season_id": season_id, "competition_id": competition_id,
                  "season_name": name, "is_current": is_current,
                  "selected_team_count": len(rows), **details}
        results.append(result)
        print(f"[current-season metadata] season_id={season_id} teams={len(rows)}", flush=True)

    if apply:
        # 모든 응답을 검증한 뒤 현재 시즌 표시와 참가 정보를 한 번에 전환해요.
        with transaction() as connection:
            with connection.cursor() as cursor:
                cursor.executemany(
                    "UPDATE seasons SET is_current=0 WHERE competition_id=%s AND is_current=1 AND season_id<>%s",
                    [(row[1], row[0]) for row in scope if row[3]],
                )
                cursor.executemany(seasons.SQL_UPSERT_SEASON, scope)
                if team_rows:
                    cursor.executemany(teams.SQL_UPSERT_TEAM, [team_rows[key] for key in sorted(team_rows)])
                    cursor.executemany(SQL_UPSERT_TEAM_SEASON, sorted(memberships))

    return {"mode": "metadata", "apply": apply, "seasons": len(scope),
            "teams": len(team_rows), "memberships": len(memberships),
            "results": results, **_metrics(client, started_at)}


def sync_current_season_fixtures(*, apply: bool = False) -> dict:
    started_at = monotonic()
    client = SportmonksClient()
    scope = fixtures._load_scope(None, None, current_only=True)
    results = []
    for index, season in enumerate(scope, 1):
        season_started_at = monotonic()
        requests_before, pages_before = client.request_count, client.page_count
        print(f"[current-season fixtures {index}/{len(scope)}] season_id={season[0]} fetching", flush=True)
        result = fixtures._collect_and_upsert(
            client, season, set(), (index, len(scope)),
            sync_participants=True, apply=apply,
        )
        result.update({"api_requests": client.request_count - requests_before,
                       "pages": client.page_count - pages_before,
                       "elapsed_seconds": round(monotonic() - season_started_at, 2)})
        results.append(result)
        print(f"[current-season fixtures] season_id={season[0]} "
              f"requests={result['api_requests']} pages={result['pages']} "
              f"seconds={result['elapsed_seconds']}", flush=True)
    return {"mode": "fixtures", "apply": apply, "seasons": len(scope),
            "results": results, **_metrics(client, started_at)}


def _existing_player_ids(player_ids) -> set[int]:
    if not player_ids:
        return set()
    placeholders = ",".join("%s" for _ in player_ids)
    return {int(row[0]) for row in fetch_all(
        f"SELECT player_id FROM players WHERE player_id IN ({placeholders})",
        tuple(sorted(player_ids)),
    )}


def _known_position_ids() -> set[int]:
    position_ids = {int(row[0]) for row in fetch_all(players.SQL_SELECT_POSITION_IDS)}
    if not position_ids:
        raise ValueError("positions table is empty")
    return position_ids


def sync_current_squads(*, apply: bool = False) -> dict:
    started_at = monotonic()
    client = SportmonksClient()
    scope = squads.load_squad_scope(current_only=True)
    known_positions = _known_position_ids()
    today = date.today()
    print(f"[current-season squads] fetching shared season transfers for {len(scope)} teams", flush=True)
    transfers_by_team = fetch_current_team_transfers(client, scope, today)
    transfer_requests = client.request_count
    new_player_rows = {}
    results = []
    for index, item in enumerate(scope, 1):
        team_id, season_id = int(item["team_id"]), int(item["season_id"])
        print(f"[current-season squads {index}/{len(scope)}] team_id={team_id} fetching", flush=True)
        requests_before = client.request_count
        # 이적 보정 규칙은 유지하고, 같은 시즌 응답을 팀별로 나눠 전체 이력 중복 조회를 줄여요.
        transfers = transfers_by_team[team_id]
        squad, result = squads.reconstruct_team_season_squad(client, item, transfers, today)
        profiles = {}
        for squad_index, squad_item in enumerate(squad):
            # 조회 모드에서도 실제 저장과 같은 등번호·포지션 검증을 거쳐요.
            squads._normalize_squad_item(squad_item, team_id, season_id, squad_index)
            profile = players._audit_squad_observation(squad_item, item, squad_index)
            profiles[int(profile["player_id"])] = profile

        # 팀 명단에 처음 등장했어도 다른 팀·과거 시즌에서 저장한 선수면 조회를 생략해요.
        missing_ids = profiles.keys() - _existing_player_ids(profiles)
        for player_id in sorted(missing_ids):
            if player_id not in new_player_rows:
                raw = client.get_player_or_none(player_id)
                embedded = [profiles[player_id]]
                primary = (players._audit_direct_player_profile(raw, player_id) if raw is not None
                           else players._merge_embedded_player_profiles(player_id, embedded))
                new_player_rows[player_id] = players._build_player_row(
                    primary, embedded, known_positions,
                    "player_endpoint" if raw is not None else "squad_profile",
                )[0]

        contract_rows = contracts.build_contract_rows(team_id, squad, set(profiles))
        dependencies = transfer_loader.prepare_contract_transfers(
            client, contract_rows["rows"], {row["id"]: row for row in transfers},
        )
        result.update(selected_players=len(profiles), missing_players=len(missing_ids),
                      stored_players=0, squad_members=0, deleted_stale=0,
                      contracts=len(contract_rows["rows"]), stored_contracts=0,
                      invalid_contract_intervals=contract_rows["invalid_intervals"],
                      missing_contract_dates=contract_rows["missing_dates"])
        if apply:
            # 같은 응답의 명단·계약을 함께 저장하고 계약이 참조하는 이적을 먼저 준비해요.
            with transaction() as connection:
                with connection.cursor() as cursor:
                    players._write_player_rows(
                        cursor, [new_player_rows[pid] for pid in sorted(missing_ids)], update_existing=True,
                    )
                    # 이미 저장한 세부 포지션은 유지하고 스쿼드에서 확인한 누락 값만 채워요.
                    position_rows = [(profile["position_id"], pid) for pid, profile in profiles.items()
                                     if profile["position_id"] in known_positions]
                    if position_rows:
                        cursor.executemany(
                            "UPDATE players SET position_id=%s WHERE player_id=%s AND position_id IS NULL",
                            position_rows,
                        )
                    result.update(squads._write_squad_snapshot(cursor, team_id, season_id, squad))
                    for dependency in dependencies:
                        transfer_loader.write_transfer_rows(cursor, dependency)
                    contracts.write_team_contract_rows(cursor, team_id, contract_rows["rows"])
            result["stored_players"] = len(missing_ids)
            result["stored_contracts"] = len(contract_rows["rows"])
        result["api_requests"] = client.request_count - requests_before
        results.append(result)
        print(f"[current-season squads {index}/{len(scope)}] team_id={team_id} "
              f"selected={len(profiles)} missing={len(missing_ids)} "
              f"stored={result['squad_members']} deleted={result['deleted_stale']} "
              f"requests={result['api_requests']}", flush=True)

    return {"mode": "squads", "apply": apply, "teams": len(scope),
            "transfer_api_requests": transfer_requests,
            "profile_fetches": len(new_player_rows),
            "stored_players": sum(r["stored_players"] for r in results),
            "stored_squad_members": sum(r["squad_members"] for r in results),
            "stored_contracts": sum(r["stored_contracts"] for r in results),
            "results": results, **_metrics(client, started_at)}


def _sync_existing_profiles(profiles, *, mode: str, total: int, apply: bool) -> dict:
    known_positions = _known_position_ids() if total else set()
    selected = stored = 0
    unavailable_ids = []
    for index, (player_id, raw) in enumerate(profiles, 1):
        if raw is None:
            # 단건 조회가 불가능한 기존 선수는 프로필과 소속을 그대로 유지해요.
            unavailable_ids.append(player_id)
        else:
            row, _ = players._build_player_row(
                players._audit_direct_player_profile(raw, player_id), [], known_positions, "player_endpoint",
            )
            selected += 1
            if apply:
                # 전체 수집이 끝날 때까지 응답을 쌓아 두지 않고 선수별로 바로 저장해요.
                stored += players._upsert_player_rows([row])
        print(f"[current-season {mode} {index}/{total}] player_id={player_id} "
              f"stored={stored} unavailable={len(unavailable_ids)}", flush=True)
    return {"selected_players": selected, "stored_players": stored,
            "unavailable_player_ids": unavailable_ids}


def sync_player_updates(*, apply: bool = False) -> dict:
    started_at = monotonic()
    client = SportmonksClient()
    changed = client.get_latest_players()
    # latest는 이미 프로필을 포함해 단건 API를 다시 호출할 필요가 없어요.
    by_id = {squads._require_int(raw.get("id"), "player.id"): raw for raw in changed}
    existing_ids = _existing_player_ids(by_id)
    result = _sync_existing_profiles(
        ((pid, by_id[pid]) for pid in sorted(existing_ids)),
        mode="player-updates", total=len(existing_ids), apply=apply,
    )
    return {"mode": "player-updates", "apply": apply, "received_players": len(changed),
            "skipped_unknown_players": len(by_id) - len(existing_ids),
            **result, **_metrics(client, started_at)}


def reconcile_current_players(*, apply: bool = False) -> dict:
    started_at = monotonic()
    client = SportmonksClient()
    scope = squads.load_squad_scope(current_only=True)
    player_ids = sorted(squads.load_current_squad_player_ids(scope))
    print(f"[current-season player-reconciliation] players={len(player_ids)}", flush=True)
    result = _sync_existing_profiles(
        ((pid, client.get_player_or_none(pid)) for pid in player_ids),
        mode="player-reconciliation", total=len(player_ids), apply=apply,
    )
    return {"mode": "player-reconciliation", "apply": apply, "requested_players": len(player_ids),
            **result, **_metrics(client, started_at)}
