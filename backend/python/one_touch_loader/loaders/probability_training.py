"""경기 전 Elo와 실제 결과를 묶고, 다음 시즌으로 검증한 모델을 만들어요."""

from __future__ import annotations

from collections import Counter
from dataclasses import asdict
from datetime import date
import hashlib
import json

import numpy as np

from ..core.clubelo import rating_before
from ..core.fixture_states import COMPLETED_STATE_IDS
from ..core.probability import WDLModel, evaluate_wdl, fit_wdl


TRAIN_SEASONS = ("2023/2024", "2024/2025")
VALIDATION_SEASON = "2025/2026"
MODEL_SEASONS = (*TRAIN_SEASONS, VALIDATION_SEASON)
BIG5_IDS = (8, 82, 301, 384, 564)


def build_dataset(fixtures: list[dict], histories: dict[int, list[dict]]) -> dict:
    rows, excluded = [], []
    seen = set()
    for fixture in fixtures:
        if fixture["season_name"] not in MODEL_SEASONS or fixture["competition_id"] not in BIG5_IDS:
            continue
        if fixture["state_id"] not in COMPLETED_STATE_IDS:
            continue
        fixture_id = int(fixture["fixture_id"])
        if fixture_id in seen:
            raise ValueError(f"Duplicate training fixture: {fixture_id}")
        seen.add(fixture_id)
        kickoff = str(fixture["starting_at"])
        day = date.fromisoformat(kickoff[:10])
        if fixture["home_score"] is None or fixture["away_score"] is None:
            raise ValueError(f"Completed fixture has no score: {fixture_id}")
        ratings = [rating_before(histories.get(int(fixture[key]), []), day)
                   for key in ("home_team_id", "away_team_id")]
        if any(value is None for value in ratings):
            # 승인된 누락 처리예요. 오늘 Elo나 평균값으로 과거 전력을 대신하지 않아요.
            excluded.append({"fixture_id": fixture_id, "season_name": fixture["season_name"],
                             "competition_id": fixture["competition_id"], "reason": "missing_pre_match_elo",
                             "missing_team_ids": [int(fixture[key]) for key, value in
                                                  zip(("home_team_id", "away_team_id"), ratings) if value is None]})
            continue
        home, away = fixture["home_score"], fixture["away_score"]
        rows.append({"fixture_id": fixture_id, "season_name": fixture["season_name"],
                     "competition_id": fixture["competition_id"], "starting_at": kickoff,
                     "home_team_id": fixture["home_team_id"], "away_team_id": fixture["away_team_id"],
                     "home_elo": ratings[0], "away_elo": ratings[1],
                     "elo_difference": ratings[0] - ratings[1],
                     "outcome": 0 if home > away else 2 if home < away else 1})
    rows.sort(key=lambda row: (row["starting_at"], row["fixture_id"]))
    coverage = []
    for season in MODEL_SEASONS:
        for competition_id in BIG5_IDS:
            available = sum(r["season_name"] == season and r["competition_id"] == competition_id for r in rows)
            missing = sum(r["season_name"] == season and r["competition_id"] == competition_id for r in excluded)
            coverage.append({"season": season, "competition_id": competition_id,
                             "available": available, "excluded": missing})
    return {"rows": rows, "excluded": excluded, "coverage": coverage}


def _inputs(rows):
    return [r["elo_difference"] for r in rows], [r["outcome"] for r in rows]


def _baseline(training):
    counts = Counter(r["outcome"] for r in training)
    if set(counts) != {0, 1, 2}:
        raise ValueError("Every training scope must include all three outcomes")
    return WDLModel((float(np.log(counts[0] / counts[1])), 0.0,
                     float(np.log(counts[2] / counts[1])), 0.0))


def train_and_validate(dataset: dict) -> dict:
    rows = dataset["rows"]
    if any(row["season_name"] not in MODEL_SEASONS for row in rows):
        raise ValueError("Only the approved three past seasons may train the V1 model")
    training = [r for r in rows if r["season_name"] in TRAIN_SEASONS]
    validation = [r for r in rows if r["season_name"] == VALIDATION_SEASON]
    if not training or not validation or max(r["starting_at"] for r in training) >= min(r["starting_at"] for r in validation):
        raise ValueError("Validation must be a nonempty later season, never a random split")
    model = fit_wdl(*_inputs(training))
    baseline = _baseline(training)
    metrics = evaluate_wdl(model, *_inputs(validation))
    baseline_metrics = evaluate_wdl(baseline, *_inputs(validation))
    leagues = []
    separate_log_loss = 0.0
    for competition_id in BIG5_IDS:
        league_train = [r for r in training if r["competition_id"] == competition_id]
        league_test = [r for r in validation if r["competition_id"] == competition_id]
        if not league_train or not league_test:
            raise ValueError(f"Missing training or validation league: {competition_id}")
        league_model = fit_wdl(*_inputs(league_train))
        league_metrics = evaluate_wdl(league_model, *_inputs(league_test))
        separate_log_loss += league_metrics["log_loss"] * len(league_test)
        leagues.append({"competition_id": competition_id, "global_model": evaluate_wdl(model, *_inputs(league_test)),
                        "league_model": league_metrics,
                        "frequency_baseline": evaluate_wdl(_baseline(league_train), *_inputs(league_test))})

    # 검증 수치는 이전 두 시즌 모델의 성능이에요. 배포용 재학습 모델의 검증값으로 바꿔 적지 않아요.
    refitted = fit_wdl(*_inputs(rows))
    data_hash = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    probs = model.predict([r["elo_difference"] for r in validation])
    actual = np.eye(3)[[r["outcome"] for r in validation]]
    calibration = []
    # 구간은 점검용 표시 단위예요. 확률이나 모델 계수를 이 구간 값으로 보정하지 않아요.
    for outcome, name in enumerate(("home_win", "draw", "away_win")):
        for lower in np.arange(0, 1, 0.1):
            selected = (probs[:, outcome] >= lower) & (probs[:, outcome] < lower + 0.1)
            if selected.any():
                calibration.append({"outcome": name, "from": round(float(lower), 1),
                                    "to": round(float(lower + 0.1), 1), "fixtures": int(selected.sum()),
                                    "predicted_mean": float(probs[selected, outcome].mean()),
                                    "observed_fraction": float(actual[selected, outcome].mean())})
    report = {
        "method": "multinomial_logistic_elo_difference_v1", "dataset_sha256": data_hash,
        "validation": {"training_seasons": list(TRAIN_SEASONS), "training_fixtures": len(training),
                       "season": VALIDATION_SEASON, "model": asdict(model), "metrics": metrics,
                       "frequency_baseline": baseline_metrics, "by_league": leagues,
                       "separate_leagues_log_loss": separate_log_loss / len(validation),
                       "calibration": calibration},
        "forecast_model": {**asdict(refitted), "training_seasons": list(MODEL_SEASONS),
                           "training_fixtures": len(rows),
                           "last_training_fixture_at": max(r["starting_at"] for r in rows),
                           "predict_from_season": "2026/2027"},
        "coverage": dataset["coverage"], "excluded": dataset["excluded"],
        "limitations": ["Excluded historical fixtures can bias coverage", "Historical Elo was retrieved retrospectively",
                        "Future Elo is fixed during each simulation", "Points ties use uniform random order"],
    }
    report["training_rows"] = rows
    report["model_id"] = hashlib.sha256(json.dumps({
        "method": report["method"], "dataset": data_hash, "coefficients": refitted.coefficients,
    }, sort_keys=True).encode()).hexdigest()
    return report
