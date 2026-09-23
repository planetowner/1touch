"""공통 리그 시뮬레이션으로 일별 예측·조건부 예측·카드를 만들어요."""

from __future__ import annotations

from collections import Counter
from datetime import date, datetime, timedelta, timezone
import math

from .clubelo import rating_before
from .cup_betting import utc_datetime
from .fixture_states import COMPLETED_STATE_IDS, LIVE_STATE_IDS, UPCOMING_STATE_IDS
from .probability import WDLModel, simulate_league


# 26/27 정규리그 범위예요. 독일·프랑스의 16위는 최종 강등이 아니라 플레이오프 진입이에요.
# https://www.bundesliga.com/en/faq/what-are-the-rules-and-regulations-of-soccer/how-does-promotion-and-relegation-work-in-the-bundesliga-10645
# https://ligue1.com/en/articles/l1_article_3812-
LEAGUE_RULES = {
    8: {"teams": 20, "direct_relegation": 3, "playoff_position": None},
    82: {"teams": 18, "direct_relegation": 2, "playoff_position": 16},
    301: {"teams": 18, "direct_relegation": 2, "playoff_position": 16},
    384: {"teams": 20, "direct_relegation": 3, "playoff_position": None},
    564: {"teams": 20, "direct_relegation": 3, "playoff_position": None},
}


def league_events(competition_id: int, positions: list[dict]) -> list[dict]:
    rule = LEAGUE_RULES[competition_id]
    n = rule["teams"]
    specs = [("league_winner", "TITLE", [1]), ("top_4", "LEAGUE_FINISH", list(range(1, 5))),
             ("top_6", "LEAGUE_FINISH", list(range(1, 7))),
             ("direct_relegation", "RELEGATION", list(range(n - rule["direct_relegation"] + 1, n + 1)))]
    if rule["playoff_position"]:
        specs.append(("relegation_playoff", "RELEGATION", [rule["playoff_position"]]))
    # Top 4·Top 6를 실제 유럽대항전 진출로 바꾸지 않아요. 컵·배정 규칙 연동은 다음 단계예요.
    return [{"event": name, "competition_id": competition_id, "category": category,
             "probability": min(1.0, max(0.0, math.fsum(p["probability"] for p in positions if p["position"] in ranks)))}
            for name, category, ranks in specs]


def with_probability_changes(events: list[dict], previous_events: list[dict]) -> list[dict]:
    # 같은 대회·결과끼리만 %p로 비교하고, 비교값이 없으면 0으로 바꾸지 않아요.
    previous = {(e['competition_id'], e['event']): e['probability'] for e in previous_events}
    result = []
    for event in events:
        key = (event['competition_id'], event['event'])
        change = 100 * (event['probability'] - previous[key]) if key in previous else None
        result.append({**event, 'change_pp': change})
    return result


def select_cards(events: list[dict], limit: int = 4) -> list[dict]:
    candidates = []
    for event in events:
        p = event["probability"]
        if not 0 <= p <= 1 or not math.isfinite(p):
            raise ValueError("Invalid event probability")
        if p in (0, 1):
            continue
        entropy = -p * math.log2(p) - (1 - p) * math.log2(1 - p)
        candidates.append({**event, "entropy": entropy})
    candidates.sort(key=lambda e: (-e["entropy"], e["competition_id"], e["event"]))
    selected, competitions, categories = [], set(), set()
    # 사용자 확정: 대회별 하나 → 아직 없는 대회/종류 → 남은 정보량 순서예요.
    # 잔류처럼 강등의 여사건은 생성하지 않아 같은 정보를 두 번 선택하지 않아요.
    for mode in ("competition", "category", "remaining"):
        for event in candidates:
            if event in selected or len(selected) >= limit:
                continue
            pair = (event["competition_id"], event["category"])
            if mode == "competition" and event["competition_id"] in competitions:
                continue
            if mode == "category" and pair in categories:
                continue
            selected.append(event)
            competitions.add(event["competition_id"])
            categories.add(pair)
    return selected


def forecast_day(*, competition_id: int, season_id: int, teams: list[dict], fixtures: list[dict],
                 histories: dict[int, list[dict]], model_report: dict, as_of: date,
                 simulations: int, seed: int, include_what_if: bool = True,
                 observed_at: datetime | None = None) -> dict:
    if competition_id not in LEAGUE_RULES:
        raise ValueError("V1 currently simulates the five major leagues")
    rule = LEAGUE_RULES[competition_id]
    if observed_at is not None and (observed_at.tzinfo is None or observed_at.utcoffset() != timedelta(0) or observed_at.date() != as_of):
        raise ValueError("Observed inputs must use a UTC timestamp on the selected day")
    team_ids = sorted(int(t["team_id"]) for t in teams)
    if len(team_ids) != rule["teams"] or len(set(team_ids)) != len(team_ids):
        raise ValueError("The complete league membership is required")
    # 종료 결과만 있는 부분 일정으로 시즌 전체인 것처럼 계산하지 않아요.
    expected_pairs = {(h, a) for h in team_ids for a in team_ids if h != a}
    pairs = Counter((f["home_team_id"], f["away_team_id"]) for f in fixtures)
    if set(pairs) != expected_pairs or any(count != 1 for count in pairs.values()):
        raise ValueError("The complete home-and-away league schedule is required")
    trained = model_report["forecast_model"]
    if date.fromisoformat(trained["last_training_fixture_at"][:10]) >= as_of:
        raise ValueError("The model contains results at or after the forecast cutoff")
    if any(f["season_name"] != "2026/2027" or f["season_id"] != season_id or f["competition_id"] != competition_id for f in fixtures):
        raise ValueError("V1 league rules are verified for 2026/2027 only")
    model = WDLModel(tuple(trained["coefficients"]))
    # 과거 복원은 전날까지, 현재 관측은 수집 시점에 공개된 당일 Elo까지 사용해요.
    elo_cutoff = as_of + timedelta(days=1) if observed_at else as_of
    ratings = {t: rating_before(histories.get(t, []), elo_cutoff) for t in team_ids}
    if any(v is None for v in ratings.values()):
        raise ValueError(f"Missing Elo at cutoff for teams: {[t for t, v in ratings.items() if v is None]}")
    points, played = dict.fromkeys(team_ids, 0), dict.fromkeys(team_ids, 0)
    finished, remaining = [], []
    for fixture in sorted(fixtures, key=lambda f: (str(f["starting_at"]), f["fixture_id"])):
        if not fixture["starting_at"]:
            raise ValueError("A fixture has no date; verify its schedule before forecasting")
        day = date.fromisoformat(str(fixture["starting_at"])[:10])
        kickoff = datetime.fromisoformat(str(fixture["starting_at"])).replace(tzinfo=timezone.utc)
        state = fixture["state_id"]
        allowed = (*COMPLETED_STATE_IDS, *UPCOMING_STATE_IDS, *(LIVE_STATE_IDS if observed_at else ()))
        if (day < as_of or observed_at) and state not in allowed:
            raise ValueError(f"Fixture {fixture['fixture_id']} is live or has an unresolved result")
        h, a = fixture["home_team_id"], fixture["away_team_id"]
        if state in COMPLETED_STATE_IDS and (kickoff < observed_at if observed_at else day < as_of):
            hs, aws = fixture["home_score"], fixture["away_score"]
            if hs is None or aws is None:
                raise ValueError("Completed fixture has no score")
            points[h] += 3 if hs > aws else int(hs == aws)
            points[a] += 3 if hs < aws else int(hs == aws)
            played[h] += 1
            played[a] += 1
            finished.append(fixture)
        else:
            # 진행 중인 경기의 임시 점수는 확정 승점에 넣지 않아요. 먼저 끝난 경기는 즉시 반영해요.
            # 복원 시점 이후 경기의 현재 결과는 읽지 않고, 당시 Elo로 새로 뽑아요.
            remaining.append({"fixture_id": fixture["fixture_id"], "home_team_id": h, "away_team_id": a,
                              "starting_at": str(fixture["starting_at"]), "round_name": fixture.get("round_name"),
                              "schedule_confirmed": (kickoff >= observed_at if observed_at else day >= as_of) and state != 10,
                              "probabilities": model.predict([ratings[h] - ratings[a]])[0].tolist()})
    kwargs = dict(team_ids=team_ids, current_points=points, remaining_fixtures=remaining,
                  simulations=simulations, seed=seed)
    baseline = simulate_league(**kwargs)
    output_teams = {}
    for team in teams:
        t = team["team_id"]
        entry = baseline[t]
        previous_fixture = next((f for f in reversed(finished) if t in (f['home_team_id'], f['away_team_id'])), None)
        previous_at = utc_datetime(previous_fixture['starting_at']) if previous_fixture else None
        entry.update({"team_id": t, "team_name": team["name"], "short_code": team.get("short_code"),
                      "elo": ratings[t], "current_points": points[t], "played": played[t],
                      "maximum_points": points[t] + 3 * (2 * (len(team_ids) - 1) - played[t]),
                      "previous_fixture_date": previous_at.date().isoformat() if previous_at else None,
                      "previous_fixture_at": previous_at.isoformat().replace('+00:00', 'Z') if previous_at else None})
        entry["events"] = league_events(competition_id, entry["positions"])
        entry["cards"] = select_cards(entry["events"]) if remaining else []
        entry["what_if"] = None
        output_teams[str(t)] = entry
    if include_what_if:
        next_by_team = {t: next((f for f in remaining if f["schedule_confirmed"] and t in
                                (f["home_team_id"], f["away_team_id"])), None) for t in team_ids}
        conditionals = {}
        for fixture in {f["fixture_id"]: f for f in next_by_team.values() if f is not None}.values():
            conditionals[fixture["fixture_id"]] = [simulate_league(**kwargs, forced_outcome=(fixture["fixture_id"], outcome))
                                                    for outcome in range(3)]
        for t, fixture in next_by_team.items():
            if fixture is None:
                continue
            scenarios = []
            for label, result_index in zip(("win", "draw", "loss"), (0, 1, 2) if fixture["home_team_id"] == t else (2, 1, 0)):
                simulated = conditionals[fixture["fixture_id"]][result_index][t]
                events = with_probability_changes(league_events(competition_id, simulated["positions"]),
                                                  output_teams[str(t)]["events"])
                scenarios.append({"outcome": label, "events": events, **simulated})
            output_teams[str(t)]["what_if"] = {"fixture": fixture, "scenarios": scenarios}
    return {"competition_id": competition_id, "season_id": season_id, "season_name": "2026/2027",
            "as_of": observed_at.isoformat().replace("+00:00", "Z") if observed_at else as_of.isoformat() + "T00:00:00Z",
            "cutoff": "observed_state" if observed_at else "utc_day_start",
            "history_kind": "observed_calculation" if observed_at else "reconstructed", "model_id": model_report["model_id"],
            "simulations": simulations, "seed": seed, "max_sampling_standard_error_pp": 50 / math.sqrt(simulations),
            "finished_fixtures": len(finished), "remaining_fixtures": len(remaining),
            "limitations": ["point_ties_uniform", "elo_fixed", "daily_historical_cutoff",
                            "historical_fixture_dates_are_currently_stored_dates",
                            "european_qualification_and_cup_outcomes_pending", "inplay_scores_not_used"],
            "teams": output_teams}


def forecast_dates(fixtures: list[dict], through: date) -> list[date]:
    first = min(date.fromisoformat(str(f["starting_at"])[:10]) for f in fixtures)
    return [first + timedelta(days=i) for i in range((through - first).days + 1)]
