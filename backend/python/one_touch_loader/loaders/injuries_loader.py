from __future__ import annotations

import json

from ..core.db import transaction
from ..core.sportmonks import SportmonksClient
from .team_squad_members_loader import load_squad_scope


SQL_SELECT_SQUAD_PLAYER_IDS = """
SELECT player_id FROM team_squad_members WHERE team_id = %s AND season_id = %s
"""
SQL_UPSERT_INJURY_TYPES = """
INSERT INTO injury_types (type_id, name) VALUES (%s, %s)
ON DUPLICATE KEY UPDATE name = VALUES(name)
"""
SQL_INSERT_INJURIES = """
INSERT INTO team_player_injuries (
  sideline_id, team_id, player_id, type_id, start_date, end_date
) VALUES (%s, %s, %s, %s, %s, %s)
"""


def build_injury_rows(team_id: int, sidelined: list[dict], squad_player_ids: set[int]) -> dict:
    injuries = []
    types = {}
    excluded = []
    non_injury = 0
    for item in sidelined:
        # 실제 category는 injury와 suspended예요. 팀 부상 화면에는 injury만 저장해요.
        if item["category"] != "injury":
            non_injury += 1
            continue
        # 사용자가 2026-09-08 확정한 기준은 공급자 스쿼드 원문이 아닌 DB 스쿼드예요.
        # 여기서 빠졌다는 이유로 부상이 끝났거나 선수가 회복됐다고 판단하지 않아요.
        if item["player_id"] not in squad_player_ids:
            excluded.append({"sideline_id": item["id"], "player_id": item["player_id"]})
            continue
        type_id = item["type_id"]
        types[type_id] = item["type"]["name"]
        # games_missed=null이 실제로 중단을 일으켰지만 화면에 쓰지 않아 변환·저장을 없앴어요.
        # end_date는 원문 그대로 두고, 과거 날짜나 NULL로 복귀 상태를 계산하지 않아요.
        injuries.append((
            item["id"], team_id, item["player_id"], type_id,
            item["start_date"], item["end_date"],
        ))
    return {
        "injuries": injuries,
        "types": sorted(types.items()),
        "non_injury": non_injury,
        "excluded_not_in_squad": excluded,
    }


def replace_team_injuries(team_id: int, season_id: int, sidelined: list[dict]) -> dict:
    # 스쿼드 조회·사유 갱신·목록 교체를 한 트랜잭션으로 묶어 실패 시 기존 목록을 보존해요.
    with transaction() as conn:
        with conn.cursor() as cursor:
            cursor.execute(SQL_SELECT_SQUAD_PLAYER_IDS, (team_id, season_id))
            squad_player_ids = {row[0] for row in cursor.fetchall()}
            rows = build_injury_rows(team_id, sidelined, squad_player_ids)
            if rows["types"]:
                cursor.executemany(SQL_UPSERT_INJURY_TYPES, rows["types"])
            cursor.execute("DELETE FROM team_player_injuries WHERE team_id = %s", (team_id,))
            if rows["injuries"]:
                cursor.executemany(SQL_INSERT_INJURIES, rows["injuries"])
    # 빈 응답도 현재 목록 교체예요. is_active나 수집 이력 컬럼은 따로 두지 않아요.
    return {
        "received": len(sidelined),
        "injuries": len(rows["injuries"]),
        "non_injury": rows["non_injury"],
        "excluded_not_in_squad": rows["excluded_not_in_squad"],
    }


def refresh_current_injuries(team_ids: list[int] | None = None) -> dict:
    # 선수·스쿼드와 같은 현재 Big 5 팀 범위를 써서 컵의 외부 상대팀을 포함하지 않아요.
    scope = load_squad_scope(current_only=True)
    if team_ids is not None:
        requested = set(team_ids)
        unknown = requested - {row["team_id"] for row in scope}
        if unknown:
            raise ValueError(f"Not a current Big 5 team: {sorted(unknown)}")
        scope = [row for row in scope if row["team_id"] in requested]
    client = SportmonksClient()
    totals = {"teams": 0, "received": 0, "injuries": 0, "non_injury": 0, "excluded_not_in_squad": 0}
    for index, row in enumerate(scope, 1):
        team_id = row["team_id"]
        payload = client.get_team_with_sidelined(team_id)
        result = replace_team_injuries(team_id, row["season_id"], payload["sidelined"])
        totals["teams"] += 1
        for key in ("received", "injuries", "non_injury"):
            totals[key] += result[key]
        totals["excluded_not_in_squad"] += len(result["excluded_not_in_squad"])
        print(
            f"[injuries {index}/{len(scope)}] team_id={team_id} season_id={row['season_id']} "
            f"received={result['received']} injuries={result['injuries']} "
            f"non_injury={result['non_injury']} excluded_not_in_squad={len(result['excluded_not_in_squad'])}",
            flush=True,
        )
        if result["excluded_not_in_squad"]:
            print(
                f"[injuries excluded] team_id={team_id} reason=not_in_db_current_squad "
                + json.dumps(result["excluded_not_in_squad"]),
                flush=True,
            )
    return totals


def refresh_team_injuries(team_id: int) -> dict:
    return refresh_current_injuries([team_id])
