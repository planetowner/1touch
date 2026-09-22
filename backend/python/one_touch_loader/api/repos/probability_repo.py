"""요청 중 시뮬레이션하지 않고 저장된 같은 모델의 일별 예측을 조회해요."""

from __future__ import annotations

from datetime import datetime, timezone

from ..db import fetch_all_dict, fetch_one_dict
from ...core.probability_forecast import select_cards
from ...core.probability_storage import load_run
from ...core.db_json import decoded
from ...core.european_probability import OUTCOME_KIND


def get_european_title(team_id, season_name):
    selected = fetch_one_dict("""SELECT r.run_id FROM probability_runs r
        JOIN seasons s ON s.season_id=r.season_id
        LEFT JOIN tournament_brackets b ON b.season_id=s.season_id
        JOIN probability_team_results tr ON tr.run_id=r.run_id AND tr.team_id=%s
        WHERE s.name=%s AND s.is_current=1 AND s.competition_id IN (2,5,2286)
          AND JSON_UNQUOTE(JSON_EXTRACT(r.payload,'$.outcome_kind'))=%s
          AND ((NOT EXISTS (SELECT 1 FROM fixtures f JOIN stages st ON st.stage_id=f.stage_id
                          WHERE st.season_id=s.season_id AND st.stage_type_id=224)
                AND (b.season_id IS NULL OR JSON_LENGTH(JSON_EXTRACT(b.payload,'$.stages'))=0))
               OR JSON_UNQUOTE(JSON_EXTRACT(r.payload,'$.bracket_input_sha256'))=b.input_sha256)
        ORDER BY r.as_of DESC,r.created_at DESC,r.run_id DESC LIMIT 1""", (team_id, season_name, OUTCOME_KIND))
    if selected is None:
        return None
    run = load_run(fetch_all_dict, selected['run_id'], team_id)
    team = run['teams'][str(team_id)]
    # 대회마다 모델과 계산 시점이 달라 리그 이력·증감과 섞지 않아요.
    return {key: run[key] for key in ('competition_id', 'season_id', 'season_name', 'as_of', 'model_id',
        'simulations', 'probability_method', 'strength_source_url', 'coefficient_source_url',
        'validation', 'limitations')} | {'event': team['event'], 'probability': team['probability'],
        'sampling_standard_error_pp': team['sampling_standard_error_pp']}


def _history_point(snapshot, entry):
    return {"as_of": snapshot["as_of"], "kind": snapshot["history_kind"], "played": entry["played"],
            "events": entry["events"], "expected_points": entry["projected_points"]["mean"]}


def get_team_probability(team_id: int, season_id: int) -> dict | None:
    # 큰 JSON까지 정렬하면 운영 MySQL의 정렬 메모리가 부족해요. ID만 먼저 골라요.
    selected = fetch_one_dict("""
        SELECT run_id FROM probability_runs WHERE season_id=%s
          AND JSON_EXTRACT(payload,'$.market_kind') IS NULL
          AND JSON_EXTRACT(payload,'$.outcome_kind') IS NULL
        ORDER BY as_of DESC,created_at DESC,run_id DESC LIMIT 1
        """, (season_id,))
    if selected is None:
        return None
    run = load_run(fetch_all_dict, selected["run_id"], team_id)
    team = run["teams"].get(str(team_id)) if run else None
    if team is None:
        return None
    latest = fetch_one_dict("""SELECT r.model_id,UNIX_TIMESTAMP(r.created_at) AS created_epoch,
        JSON_OBJECT('method',JSON_EXTRACT(m.payload,'$.method'),
                    'validation',JSON_EXTRACT(m.payload,'$.validation')) AS model_payload
        FROM probability_runs r JOIN probability_models m ON m.model_id=r.model_id WHERE r.run_id=%s""",
        (selected["run_id"],))
    model = decoded(latest["model_payload"])
    history_rows = fetch_all_dict("""SELECT r.as_of,r.payload,tr.payload AS team_payload FROM probability_runs r
        JOIN probability_team_results tr ON tr.run_id=r.run_id AND tr.team_id=%s JOIN (
            SELECT run_id,ROW_NUMBER() OVER (PARTITION BY as_of ORDER BY created_at DESC,run_id DESC) AS version
            FROM probability_runs WHERE season_id=%s AND model_id=%s AND DATE(as_of)<=%s
              AND TIME(as_of)=TIME('00:00:00')
        ) snapshots ON snapshots.run_id=r.run_id WHERE version=1 ORDER BY r.as_of""",
        (team_id, season_id, latest["model_id"], run["as_of"][:10]))
    history, previous = [], None
    for row in history_rows:
        stamp = row["as_of"]
        if isinstance(stamp, str):
            stamp = datetime.fromisoformat(stamp.replace('Z', '+00:00'))
        snapshot = {**decoded(row["payload"]), "as_of": stamp.replace(tzinfo=timezone.utc).isoformat().replace('+00:00', 'Z')}
        entry = decoded(row["team_payload"])
        history.append(_history_point(snapshot, entry))
        if snapshot["as_of"][:10] == team["previous_fixture_date"]:
            previous = entry
    if run["cutoff"] == "observed_state":
        history.append(_history_point(run, team))
    previous_events = {e["event"]: e["probability"] for e in previous["events"]} if previous else {}
    events = [{**event, "change_pp": 100 * (event["probability"] - previous_events[event["event"]])
               if event["event"] in previous_events else None} for event in team["events"]]
    europe = get_european_title(team_id, run['season_name'])
    card_events = list(events) if run['remaining_fixtures'] else []
    if europe:
        event = {key: europe[key] for key in ('event', 'competition_id', 'probability')}
        event.update(category='TITLE', change_pp=None)
        events.append(event)
        card_events.append(event)
    return {
        "team_id": team_id, "team_name": team["team_name"], "competition_id": run["competition_id"],
        "season_id": season_id, "season_name": run["season_name"], "as_of": run["as_of"],
        "cutoff": run["cutoff"],
        "calculated_at": datetime.fromtimestamp(float(latest["created_epoch"]), tz=timezone.utc),
        "model_id": latest["model_id"], "simulations": run["simulations"],
        "max_sampling_standard_error_pp": run["max_sampling_standard_error_pp"],
        "strength_source": "clubelo", "probability_method": model["method"],
        "validation": model["validation"]["metrics"],
        "elo": team["elo"], "current_points": team["current_points"], "played": team["played"],
        "maximum_points": team["maximum_points"], "positions": team["positions"],
        "projected_points": {**team["projected_points"], "change_points":
                             team["projected_points"]["mean"] - previous["projected_points"]["mean"] if previous else None},
        "comparison": {"basis": "previous_league_fixture_utc_day_start", "available": previous is not None,
                       "as_of": team["previous_fixture_date"] + "T00:00:00Z" if team["previous_fixture_date"] else None},
        "events": events, "cards": select_cards(card_events), "european_title": europe,
        "history": history, "what_if": team["what_if"], "limitations": run["limitations"],
        "pending_outcomes": ["ucl_qualification", "europa_qualification", "domestic_cup_winner"]
                            + ([] if europe else ['european_title']),
    }
