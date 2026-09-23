"""기존 외부 ID 관계와 경기별 Opta 슈팅·패스·수비 행동을 함께 저장해요."""

from __future__ import annotations

from datetime import datetime, timezone
import json


# 두 수집은 매핑·교체·완료 표시가 같고, 이벤트 분류와 저장 테이블만 달라요.
DATASETS = {
    "shots": ("fixture_opta_shotmaps", "fixture_opta_shots", "result", "슈팅"),
    "analysis": ("fixture_opta_analyses", "fixture_opta_events", "kinds", "이벤트"),
}


def load_known_ids() -> dict:
    from ..core.db import fetch_all

    return {entity: {str(external): internal for external, internal in fetch_all(
        f"SELECT external_{entity}_id, {entity}_id FROM {entity}_external_ids WHERE provider='opta'"
    )} for entity in ("team", "fixture", "player")}


def load_scope(competition_id: int, season_name: str, *, match_dates=None) -> tuple[list[dict], list[dict]]:
    from ..api.db import fetch_all_dict
    from ..core.opta_ids import VERIFIED_SUBSTITUTION_ROSTER, supplement_roster

    if match_dates is not None and not match_dates:
        return [], []
    dates = sorted(set(match_dates)) if match_dates is not None else []
    date_filter = f" AND DATE(f.starting_at) IN ({','.join('%s' for _ in dates)})" if dates else ''
    # ID 검증도 경기 날짜가 같은 후보만 사용해요. 명단은 그 후보 경기만 읽으면 돼요.
    fixtures = fetch_all_dict("""
        SELECT f.fixture_id, f.home_team_id, f.away_team_id, f.starting_at, f.state_id
        FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
        JOIN seasons s ON s.season_id=st.season_id
        WHERE s.competition_id=%s AND s.name=%s
    """ + date_filter, (competition_id, season_name, *dates))
    if not fixtures:
        raise ValueError(f"DB에 대상 시즌 경기가 없어요: {competition_id} {season_name}")
    fixture_ids = [f['fixture_id'] for f in fixtures]
    marks = ','.join('%s' for _ in fixture_ids)
    lineups = fetch_all_dict(f"""
        SELECT l.fixture_id, l.team_id, l.player_id, l.jersey_number, p.display_name, p.full_name
        FROM fixture_lineups l JOIN players p ON p.player_id=l.player_id
        WHERE l.fixture_id IN ({marks})
    """, tuple(fixture_ids))
    # 공식 명단과 대조한 교체 선수만 보충해요. 전체 이벤트를 출전 명단으로 간주하지 않아요.
    placeholders = ",".join(["%s"] * len(VERIFIED_SUBSTITUTION_ROSTER))
    events = fetch_all_dict(f"""
        SELECT e.event_id, e.event_type_id, e.fixture_id, e.team_id, e.player_id,
               p.display_name, p.full_name
        FROM fixture_events e JOIN players p ON p.player_id=e.player_id
        WHERE e.fixture_id IN ({marks}) AND e.event_id IN ({placeholders})
    """, (*fixture_ids, *VERIFIED_SUBSTITUTION_ROSTER))
    return fixtures, supplement_roster(lineups, events)


def refresh_recent_rosters(fixtures: list[dict], lineups: list[dict], *, from_date,
                           to_date, stored_ids: set, apply: bool) -> list[dict]:
    from ..core.fixture_states import COMPLETED_STATE_IDS
    from .fixture_details_loader import normalize_fixture_lineups
    from .live_fixtures_loader import refresh_completed_details

    result = list(lineups)
    pending = [f for f in fixtures
               if from_date.isoformat() <= str(f['starting_at'])[:10] <= to_date.isoformat()
               and not (f['fixture_id'] in stored_ids and f['state_id'] in COMPLETED_STATE_IDS)]
    for payload in refresh_completed_details(pending, apply=apply):
        fixture_id = payload['id']
        normalized = normalize_fixture_lineups(payload, fixture_id)["lineups"]
        originals = [row for row in payload["lineups"] if row["player_id"] is not None]
        fresh = [dict(fixture_id=row[0], team_id=row[1], player_id=row[2], jersey_number=row[5],
                      display_name=source["player"].get("display_name"), full_name=source["player"]["name"])
                 for row, source in zip(normalized, originals)]
        # --check에서도 최신 명단으로 매핑하지만 DB에는 쓰지 않아요.
        result = [row for row in result if row["fixture_id"] != fixture_id] + fresh
        print(f"ROSTER: fixture_id={fixture_id} players={len(fresh)} check={not apply}", flush=True)
    return result


def bind_shots(result: dict, plan: dict) -> list[tuple]:
    return bind_events(result, plan, dataset="shots")


def bind_events(result: dict, plan: dict, *, dataset: str) -> list[tuple]:
    mappings = plan["mappings"]
    fixture = plan["fixture"]
    _, _, value_key, label = DATASETS[dataset]
    rows, missing = [], set()
    for shot in result["shots" if dataset == "shots" else "events"]:
        external_player = shot["external_player_id"]
        if external_player not in mappings["player"]:
            missing.add(external_player)
            continue
        team_id = mappings["team"][shot["external_team_id"]]
        if team_id != fixture[f"{shot['side']}_team_id"]:
            raise ValueError(f"{label}의 팀과 경기의 홈·원정 팀이 달라요.")
        value = shot[value_key] if dataset == "shots" else json.dumps(shot[value_key])
        endpoint = shot["end"]
        rows.append((shot["external_event_id"], fixture["fixture_id"], team_id,
                     mappings["player"][external_player], shot["minute"], shot["extra_minute"], value,
                     shot["start"]["x"], shot["start"]["y"],
                     endpoint["x"] if endpoint else None, endpoint["y"] if endpoint else None))
    if missing:
        raise ValueError(f"경기·팀·등번호·이름으로 {label} 선수를 연결하지 못했어요: {sorted(missing)}")
    return rows


def replace_match(cursor, result: dict, plan: dict, known: dict, collected_at: str, *, dataset: str = "shots") -> None:
    rows = bind_events(result, plan, dataset=dataset)
    metadata_table, events_table, value_key, _ = DATASETS[dataset]
    fixture_id = plan["fixture"]["fixture_id"]
    # 매핑·완료 표시·이벤트는 단일 트랜잭션에서 반영해요. 실패한 수집은 기존 값을 지우지 않아요.
    cursor.execute("SELECT fixture_id FROM fixtures WHERE fixture_id=%s FOR UPDATE", (fixture_id,))
    if not cursor.fetchone():
        raise ValueError(f"경기가 없어졌어요: {fixture_id}")
    for entity, mapping in plan["mappings"].items():
        additions = [(internal, external) for external, internal in mapping.items() if external not in known[entity]]
        if additions:
            cursor.executemany(f"INSERT INTO {entity}_external_ids ({entity}_id,provider,external_{entity}_id) "
                               "VALUES (%s,'opta',%s)", additions)
    sampled = datetime.fromisoformat(collected_at).astimezone(timezone.utc).replace(tzinfo=None)
    cursor.execute('''INSERT INTO fixture_opta_sources (fixture_id,source_url) VALUES (%s,%s)
        ON DUPLICATE KEY UPDATE source_url=VALUES(source_url)''', (fixture_id, result['source_url']))
    # 외부 경기 ID는 fixture_external_ids, 공통 출처는 fixture_opta_sources에 한 번만 있어요.
    cursor.execute(f'''INSERT INTO {metadata_table} (fixture_id,collected_at) VALUES (%s,%s)
        ON DUPLICATE KEY UPDATE collected_at=VALUES(collected_at)''', (fixture_id, sampled))
    cursor.execute(f"DELETE FROM {events_table} WHERE fixture_id=%s", (fixture_id,))
    if rows:
        cursor.executemany(f"""INSERT INTO {events_table}
            (external_event_id,fixture_id,team_id,player_id,minute,extra_minute,{value_key},start_x,start_y,end_x,end_y)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""", rows)


def save_match(result: dict, plan: dict, known: dict, collected_at: str, *, dataset: str = "shots") -> None:
    save_match_datasets({dataset: result}, plan, known, collected_at)


def save_match_datasets(results: dict, plan: dict, known: dict, collected_at: str) -> None:
    from ..core.db import transaction

    # 함께 수집한 지도·분석은 둘 다 성공해야 완료돼요. 한쪽 실패로 경기 수가 어긋나지 않게 해요.
    pending_known = {entity: dict(ids) for entity, ids in known.items()}
    with transaction() as conn:
        with conn.cursor() as cursor:
            for dataset, result in results.items():
                replace_match(cursor, result, plan, pending_known, collected_at, dataset=dataset)
                for entity, mapping in plan["mappings"].items():
                    pending_known[entity].update(mapping)
