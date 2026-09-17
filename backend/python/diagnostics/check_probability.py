"""저장된 Probability를 실제 조회 경로로 읽고, 쓰기 없이 응답 구조를 확인해요."""

from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor

from one_touch_loader.api.repos.probability_repo import get_team_probability
from one_touch_loader.api.schemas.probability import TeamProbabilityResponse
from one_touch_loader.loaders.probability_loader import _fetch, read_teams


def check():
    counts = {table: _fetch(f"SELECT COUNT(*) AS n FROM {table}")[0]["n"]
              for table in ("clubelo_ratings", "probability_models", "probability_runs")}
    seasons = _fetch("""SELECT season_id,COUNT(*) AS snapshots,MIN(as_of) AS first_at,
                       MAX(as_of) AS last_at FROM probability_runs GROUP BY season_id""")
    teams = read_teams()
    print(json.dumps({"counts": counts, "seasons": seasons}, default=str), flush=True)

    def check_team(team):
        payload = get_team_probability(team["team_id"], team["season_id"])
        if payload is None:
            raise ValueError(f"Missing forecast for team {team['team_id']}")
        TeamProbabilityResponse.model_validate(payload)
        if abs(sum(row["probability"] for row in payload["positions"]) - 1) > 1e-9:
            raise ValueError(f"Invalid position probabilities for team {team['team_id']}")
        return bool(payload["comparison"]["available"]), payload["what_if"] is not None

    comparisons = what_ifs = 0
    # DB 풀 5개 안에서 독립적인 읽기만 나눠, 원격 DB 왕복 시간을 줄여요.
    with ThreadPoolExecutor(max_workers=4) as executor:
        for i, (comparison, what_if) in enumerate(executor.map(check_team, teams), 1):
            comparisons += comparison
            what_ifs += what_if
            if i % 24 == 0 or i == len(teams):
                print(f"Probability API checked {i}/{len(teams)} teams", flush=True)
    if len({team["season_id"] for team in teams}) != 5:
        raise ValueError("Five current leagues must be present")
    return {"check": True, "counts": counts, "seasons": seasons, "api_teams": len(teams),
            "teams_with_comparison": comparisons, "teams_with_what_if": what_ifs}


if __name__ == "__main__":
    print(json.dumps(check(), ensure_ascii=False, default=str), flush=True)
