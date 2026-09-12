"""완료된 시즌의 터미널 로그와 DB 저장 건수를 대조해요."""

import ast
import json
import re
from pathlib import Path

from one_touch_loader.core.db import fetch_all
from one_touch_loader.loaders.fixture_details_loader import _load_scope
from one_touch_loader.loaders.team_squad_members_loader import BIG5_COMPETITION_IDS
from verify_fixture_details import verify_schema


def verify_season_log(log_path: Path) -> dict:
    text = log_path.read_text(encoding="utf-16")
    completed = re.search(
        r"^Fixture details season done: season=(\d{4}/\d{4}) competitions=(\[.*?\]) result=(\{.*\})$",
        text, re.M,
    )
    if completed is None:
        raise AssertionError(f"Season completion is absent: {log_path}")
    season, competition_text, summary_text = completed.groups()
    competition_ids = ast.literal_eval(competition_text)
    assert competition_ids == list(BIG5_COMPETITION_IDS), competition_ids
    summary = ast.literal_eval(summary_text)
    progress = re.findall(
        r"^\[fixture-details (\d+)/(\d+)\] fixture_id=(\d+) events=(\d+) stats=(\d+) lineups=(\d+) pressure=(\d+)",
        text, re.M,
    )
    expected = {int(row[2]): tuple(map(int, row[3:])) for row in progress}
    scope = _load_scope(season, competition_ids)
    assert len(progress) == len(expected) == len(scope) == summary["fixtures"]
    assert [int(row[0]) for row in progress] == list(range(1, len(scope) + 1))
    assert all(int(row[1]) == len(scope) for row in progress)
    assert set(scope) == set(expected)

    actual = {fixture_id: [] for fixture_id in scope}
    totals = {}
    for table, key in (
        ("fixture_events", "events"), ("fixture_team_stats", "team_stats"),
        ("fixture_lineups", "lineups"), ("fixture_pressures", "pressures"),
        ("fixture_formations", "formations"), ("fixture_coaches", "fixture_coaches"),
    ):
        rows = dict(fetch_all(
            f"SELECT d.fixture_id,COUNT(*) FROM {table} d "
            "JOIN fixtures f ON f.fixture_id=d.fixture_id "
            "JOIN stages st ON st.stage_id=f.stage_id "
            "JOIN seasons s ON s.season_id=st.season_id "
            "WHERE s.name=%s AND s.competition_id IN (%s,%s,%s,%s,%s) "
            "GROUP BY d.fixture_id",
            (season, *competition_ids),
        ))
        totals[key] = sum(rows.values())
        assert totals[key] == summary[key], (season, key, totals[key], summary[key])
        if key in {"events", "team_stats", "lineups", "pressures"}:
            # 빈 응답인 경기도 완료 로그에 있으므로 미적재 경기로 오인하지 않아요.
            for fixture_id in scope:
                actual[fixture_id].append(rows.get(fixture_id, 0))
    for fixture_id in scope:
        assert tuple(actual[fixture_id]) == expected[fixture_id], fixture_id
    return {
        "season": season, "fixtures": len(scope), "totals": totals,
        "source_log": str(log_path), "schema_counts": verify_schema(), "result": "passed",
    }


if __name__ == "__main__":
    import sys

    print(json.dumps(verify_season_log(Path(sys.argv[1])), ensure_ascii=False, indent=2))
