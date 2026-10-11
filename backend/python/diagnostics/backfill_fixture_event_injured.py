"""기존 교체 이벤트의 부상 여부만 다시 조회해요. --apply를 주면 저장해요."""
from __future__ import annotations

import argparse
from collections import Counter
import json

from one_touch_loader.core.db import fetch_all, transaction
from one_touch_loader.core.sportmonks import SportmonksClient


def backfill(*, apply: bool, fixture_ids: list[int] | None = None) -> dict:
    sql = """SELECT fe.fixture_id,fe.event_id,fe.event_type_id
        FROM fixture_events fe JOIN fixture_event_types fet USING(event_type_id)
        WHERE fet.code='substitution' AND fe.injured IS NULL"""
    params = ()
    if fixture_ids is not None:
        sql += " AND fe.fixture_id IN (" + ",".join("%s" for _ in fixture_ids) + ")"
        params = tuple(fixture_ids)
    sql += " ORDER BY fe.fixture_id,fe.event_id"
    events_by_fixture = {}
    for fixture_id, event_id, type_id in fetch_all(sql, params):
        events_by_fixture.setdefault(fixture_id, {})[event_id] = type_id
    scope = list(events_by_fixture)
    totals = Counter(fixtures=0, matched=0, source_true=0, source_false=0, source_null=0, updated=0)
    missing = []
    client = SportmonksClient()
    for offset in range(0, len(scope), 50):
        group = scope[offset:offset + 50]
        # 전체 상세 재적재는 명단·통계도 바꿔요. 기존 ID에 연결되는 부상 값만 보충해요.
        fixtures = client.get_fixtures_batch(group, include="events")
        rows = []
        batch_missing = []
        for fixture in fixtures:
            stored = events_by_fixture[fixture["id"]]
            source = {event["id"]: event for event in fixture["events"]}
            for event_id, type_id in stored.items():
                event = source.get(event_id)
                if event is None or event["type_id"] != type_id:
                    batch_missing.append({"fixture_id": fixture["id"], "event_id": event_id})
                    continue
                injured = event["injured"]
                totals["matched"] += 1
                totals["source_null" if injured is None else "source_true" if injured else "source_false"] += 1
                if injured is not None:
                    rows.append((injured, event_id, fixture["id"], type_id))
        if apply and rows:
            with transaction() as connection, connection.cursor() as cursor:
                # 조회 중 라이브 수집이 채운 값은 과거 응답으로 덮어쓰지 않아요.
                cursor.executemany("""UPDATE fixture_events SET injured=%s
                    WHERE event_id=%s AND fixture_id=%s AND event_type_id=%s AND injured IS NULL""", rows)
                totals["updated"] += cursor.rowcount
        totals["fixtures"] += len(group)
        missing.extend(batch_missing)
        print(json.dumps({"apply": apply, "total_fixtures": len(scope), **totals,
                          "last_fixture_id": group[-1], "missing_events": batch_missing}), flush=True)
    return {"apply": apply, **totals, "missing_events": missing, "api_requests": client.request_count}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--fixture-id", type=int, nargs="+")
    args = parser.parse_args()
    print(json.dumps(backfill(apply=args.apply, fixture_ids=args.fixture_id)), flush=True)


if __name__ == "__main__":
    main()
