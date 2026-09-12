"""리그·시즌별로 조회한 경기 xG·선수 xG·슈팅을 한 트랜잭션으로 교체해요."""

from __future__ import annotations

from decimal import Decimal

from ..core.db import transaction
from ..core.understat import UnderstatClient
from .understat_common import (
    load_external_ids, load_understat_scope, select_understat_matches, write_understat_report,
)


def normalize_understat_match(match: dict, details: dict, fixture_id: int,
                             team_ids: dict, player_ids: dict) -> dict:
    side_teams = {side: team_ids[str(match[side]["id"])] for side in ("h", "a")}
    player_xg, shots = [], []
    seen_players = set()
    for side, roster in details["rosters"].items():
        for player in roster.values():
            external_player_id = str(player["player_id"])
            # 30804의 명단 중복은 선수 xG의 PK와 충돌해요. --check에서도 저장 전에 드러내요.
            # 같은 xG라도 임의로 합치지 않아요. 이 경기에는 슈팅 중복도 함께 있었어요.
            if external_player_id in seen_players:
                raise ValueError(f"Understat match {match['id']} repeats player_id={external_player_id}")
            seen_players.add(external_player_id)
            # 슈팅이 없는 선수의 0도 원본 명단에서 직접 제공된 값만 저장해요.
            # 명단 밖 선수에게 0을 채우거나 슈팅 합계를 자동 대체값으로 넣지 않아요.
            player_xg.append((fixture_id, player_ids[external_player_id], Decimal(player["xG"])))
    for side, source_shots in details["shots"].items():
        for shot in source_shots:
            # 자책골도 원본 결과와 행위 팀을 보존해요. 일반 슈팅 수에서는 따로 제외해요.
            # X/Y는 슈팅 시작 위치예요. 제공되지 않은 도착 좌표·궤적은 만들지 않아요.
            shots.append((int(shot["id"]), fixture_id, side_teams[side],
                          player_ids[str(shot["player_id"])], int(shot["minute"]),
                          Decimal(shot["X"]), Decimal(shot["Y"]), Decimal(shot["xG"]), shot["result"]))
    # 17/18 Watford–Liverpool(7120)도 원본 팀 xG 2.17647과 슈팅 xG 합계 약 2.22495가 달라요.
    # 팀·선수·슈팅은 각각 제공된 값을 보존해요. 한쪽 합계로 다른 쪽 원본을 덮어쓰지 않아요.
    return {"expected_goals": (fixture_id, Decimal(match["xG"]["h"]), Decimal(match["xG"]["a"])),
            "player_expected_goals": player_xg, "shots": shots}


def replace_understat_rows(batch: list[dict]) -> None:
    fixture_ids = tuple(rows["expected_goals"][0] for rows in batch)
    expected_goals = [rows["expected_goals"] for rows in batch]
    player_expected_goals = [row for rows in batch for row in rows["player_expected_goals"]]
    shots = [row for rows in batch for row in rows["shots"]]
    with transaction() as connection:
        with connection.cursor() as cursor:
            # 원격 DB 실측에서 요청 한 번에 약 0.47초, 연결 반환에 약 1.88초가 걸렸어요.
            # 경기마다 왕복하지 않고 조회를 마친 리그·시즌 묶음을 저장해요. 실패하면 묶음 전체를 되돌려요.
            # Sportmonks fixture-details가 교체하는 테이블과 저장 범위를 분리해요.
            for table in ("fixture_shots", "fixture_player_expected_goals", "fixture_expected_goals"):
                cursor.execute(f"DELETE FROM {table} WHERE fixture_id IN ({','.join('%s' for _ in fixture_ids)})", fixture_ids)
            cursor.executemany("INSERT INTO fixture_expected_goals (fixture_id,home_xg,away_xg) VALUES (%s,%s,%s)",
                               expected_goals)
            if player_expected_goals:
                cursor.executemany("""
                    INSERT INTO fixture_player_expected_goals (fixture_id,player_id,xg) VALUES (%s,%s,%s)
                """, player_expected_goals)
            if shots:
                cursor.executemany("""
                    INSERT INTO fixture_shots (shot_id,fixture_id,team_id,player_id,minute,x,y,xg,result)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
                """, shots)


def collect_understat(season_name: str | None = None, competition_ids: list[int] | None = None,
                      *, check: bool = False) -> dict:
    scope = load_understat_scope(season_name, competition_ids)
    fixture_ids = load_external_ids("fixture")
    team_ids = load_external_ids("team")
    player_ids = load_external_ids("player")
    client = UnderstatClient()
    totals = {"fixtures": 0, "players": 0, "shots": 0, "unavailable": 0}
    try:
        for season in scope:
            source = client.get_season(season["competition_id"], season["name"])
            matches, unavailable = select_understat_matches(source)
            totals["unavailable"] += len(unavailable)
            if unavailable:
                path = write_understat_report("unavailable", {**season, "fixtures": unavailable})
                print(f"[understat] {season['name']} competition_id={season['competition_id']} "
                      f"unavailable={unavailable} report={path}", flush=True)
            batch = []
            for index, match in enumerate(matches, 1):
                external_id = str(match["id"])
                details = client.get_match(external_id)
                roster_ids = {str(p["player_id"]) for roster in details["rosters"].values() for p in roster.values()}
                shot_ids = {str(p["player_id"]) for shots in details["shots"].values() for p in shots}
                missing = {"fixture": [] if external_id in fixture_ids else [external_id],
                           "teams": [str(match[s]["id"]) for s in ("h", "a") if str(match[s]["id"]) not in team_ids],
                           "players": sorted((roster_ids | shot_ids) - player_ids.keys())}
                if any(missing.values()):
                    path = write_understat_report("unmapped", {**season, "match_id": external_id, "missing": missing})
                    raise ValueError(f"Understat IDs need mapping: {missing}. Report: {path}")
                fixture_id = fixture_ids[external_id]
                rows = normalize_understat_match(match, details, fixture_id, team_ids, player_ids)
                batch.append(rows)
                totals["fixtures"] += 1
                totals["players"] += len(rows["player_expected_goals"])
                totals["shots"] += len(rows["shots"])
                print(f"[understat {index}/{len(matches)}] {season['name']} competition_id={season['competition_id']} "
                      f"fixture_id={fixture_id} shots={len(rows['shots'])} "
                      f"players={len(rows['player_expected_goals'])} prepared=True check={check}", flush=True)
            if not check and batch:
                replace_understat_rows(batch)
                # 위 경기별 로그는 원본 조회·변환 완료예요. 이 문구부터 DB 저장 완료를 뜻해요.
                print(f"[understat stored] {season['name']} competition_id={season['competition_id']} "
                      f"fixtures={len(batch)}", flush=True)
    finally:
        client.close()
    return totals
