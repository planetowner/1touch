"""현재 시즌 선수의 최근 폼과 급여 대비 기여도를 계산해요."""
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime
from math import ceil, exp, log
from statistics import median

import numpy as np
from scipy.optimize import minimize_scalar
from sklearn.linear_model import QuantileRegressor
from sklearn.model_selection import KFold
from sklearn.preprocessing import SplineTransformer, StandardScaler
from threadpoolctl import threadpool_limits

from .player_rating_percentile import HistoricalPercentile


FORM_MATCH_LIMIT = 5
GRADE_LABELS = ("Very Poor", "Poor", "Fair", "Good")
COST_MODEL_SEED = 20260920
COST_WEIGHTS = np.asarray([.5, .5])


def valid_ratings(rows: list[dict]) -> list[dict]:
    # 미출전과 평점 미제공을 0점 경기로 바꾸지 않아요.
    return [r for r in rows if (r["minutes_played"] or 0) > 0 and r["rating"] is not None]


def weighted_rating(rows: list[dict], decay_per_day: float = 0.0) -> float | None:
    rows = valid_ratings(rows)
    if not rows:
        return None
    latest = max(r["starting_at"] for r in rows)
    # 공통 기준일은 분자·분모에서 소거돼요. 마지막 경기일을 쓰면 오래된 경기에서도 언더플로가 없어요.
    weights = [r["minutes_played"] * exp(
        -decay_per_day * (latest - r["starting_at"]).total_seconds() / 86400
    ) for r in rows]
    return sum(float(r["rating"]) * w for r, w in zip(rows, weights)) / sum(weights)


def calibrate_form_decay(rows: list[dict]) -> dict:
    """각 경기보다 앞선 최대 5경기만 써서 다음 평점의 출전 시간 가중 오차를 비교해요."""
    histories = defaultdict(list)
    for row in rows:
        if (row["minutes_played"] or 0) > 0:
            histories[row["player_id"]].append(row)
    prior_ratings, prior_days, prior_minutes, targets, target_minutes = [], [], [], [], []
    for player_id in sorted(histories):
        history = histories[player_id]
        history.sort(key=lambda r: (r["starting_at"], r["fixture_id"]))
        for index, target in enumerate(history[1:], 1):
            if target["rating"] is None:
                continue
            prior = history[max(0, index - FORM_MATCH_LIMIT):index]
            # 같은 시각의 기록을 이전 경기로 취급하지 않아요.
            prior = valid_ratings([r for r in prior if r["starting_at"] < target["starting_at"]])
            if not prior:
                continue
            padding = FORM_MATCH_LIMIT - len(prior)
            prior_ratings.append([float(r["rating"]) for r in prior] + [0] * padding)
            prior_days.append([(target["starting_at"] - r["starting_at"]).total_seconds() / 86400
                               for r in prior] + [0] * padding)
            prior_minutes.append([r["minutes_played"] / 90 for r in prior] + [0] * padding)
            targets.append(float(target["rating"]))
            target_minutes.append(target["minutes_played"] / 90)
    if not targets:
        raise ValueError("No prior/next-match pairs available for form calibration")
    ratings = np.asarray(prior_ratings)
    days = np.asarray(prior_days)
    minutes = np.asarray(prior_minutes)
    # 날짜의 공통 차이는 평균에서 소거돼요. 큰 공백 뒤에도 분모가 0이 되지 않게 해요.
    days -= np.min(np.where(minutes > 0, days, np.inf), axis=1)[:, None]

    def loss(decay: float) -> float:
        weights = minutes * np.exp(-decay * np.maximum(days, 0))
        predicted = np.sum(ratings * weights, axis=1) / np.sum(weights, axis=1)
        return float(np.average((predicted - targets) ** 2, weights=target_minutes))

    # 반감기 1일~무감쇠 범위를 탐색해요. 무감쇠가 더 정확하면 임의의 최근성 가중치를 넣지 않아요.
    upper = log(2)
    fitted = minimize_scalar(loss, bounds=(0, upper), method="bounded")
    decay = min((0.0, float(fitted.x), upper), key=loss)
    return {"match_limit": FORM_MATCH_LIMIT, "decay_per_day": decay,
            "validation_pairs": len(targets), "weighted_mse": loss(decay),
            "no_decay_mse": loss(0), "seven_day_half_life_mse": loss(log(2) / 7)}


def _indicator(reason: str | None = None) -> dict:
    return {"raw_score": None, "percentile": None, "grade": None, "band": None,
            "reference_count": 0, "unavailable_reason": reason}


def _assign_form_grades(items: list[dict]) -> None:
    eligible = [item["form"] for item in items if item["form"]["raw_score"] is not None]
    if len(eligible) < 2:
        for value in eligible:
            value["unavailable_reason"] = "insufficient_comparison_players"
        return
    # 계산 순서에 따른 부동소수점 오차로 같은 값의 백분위가 갈리지 않게 해요.
    for value in eligible:
        value["raw_score"] = round(value["raw_score"], 10)
    distribution = HistoricalPercentile(value["raw_score"] for value in eligible)
    for value in eligible:
        percentile = float(distribution.score(value["raw_score"]))
        band = min(int(percentile // 20), 4)
        value.update(percentile=percentile, band=band,
                     grade=(*GRADE_LABELS, "Excellent")[band],
                     reference_count=len(eligible), unavailable_reason=None)


def _teammate_wage_medians(wages: dict[int, float], excluded_player: int | None = None) -> dict[int, float | None]:
    """현재 구단의 등록 급여에서 본인과 예측 대상 선수를 제외해요."""
    available = {player: wage for player, wage in wages.items() if player != excluded_player}
    result = {}
    for player in wages:
        teammates = [wage for teammate, wage in available.items() if teammate != player]
        result[player] = median(teammates) if teammates else None
    return result


def _cost_features(rows: list[dict], roster: list[dict]) -> tuple[list[dict], np.ndarray] | None:
    club_wages = defaultdict(dict)
    for player in roster:
        wage = player["estimated_weekly_gross_eur"]
        if wage and wage > 0:
            club_wages[(player["season_id"], player["team_id"])][player["player_id"]] = float(wage)
    # 출전하지 않은 동료도 구단의 급여 구조에는 포함해요. 시즌·구단이 다른 급여는 섞지 않아요.
    club_levels = {club: _teammate_wage_medians(wages) for club, wages in club_wages.items()}
    row_clubs = [(r["season_id"], r["team_id"]) for r in rows]
    levels = [club_levels[club][r["player_id"]] for r, club in zip(rows, row_clubs)]
    eligible = [i for i, level in enumerate(levels) if level is not None]
    if not eligible:
        return None
    leagues = sorted({r["competition_id"] for r in rows})
    positions = sorted({r["position_group_id"] for r in rows})
    design = np.asarray([
        [log(rows[i]["actual_weekly_wage_eur"]), log(levels[i])]
        + [float(rows[i]["competition_id"] == league) for league in leagues[1:]]
        + [float(rows[i]["position_group_id"] == position) for position in positions[1:]]
        for i in eligible
    ])
    return [rows[i] for i in eligible], design


def combined_cost_score(actual: np.ndarray, expected: np.ndarray, scales: np.ndarray) -> np.ndarray:
    # 두 항목의 단위를 학습 정답의 표준편차로 맞춰요. 50:50은 제품에서 정한 비중이에요.
    return ((actual - expected) / scales) @ COST_WEIGHTS


def _cost_band(score: float, fair_boundary: float, very_boundary: float) -> int:
    if score < -very_boundary:
        return 0
    if score < -fair_boundary:
        return 1
    if score <= fair_boundary:
        return 2
    return 3 if score <= very_boundary else 4


def cost_effectiveness_scores(rows: list[dict], roster: list[dict]) -> dict[int, dict]:
    """본인의 성과를 학습·오차 보정에서 제외하고, 주급 대비 두 기대치를 평가해요."""
    prepared = _cost_features(sorted(rows, key=lambda r: r["player_id"]), roster)
    if prepared is None:
        return {}
    rows, raw = prepared
    if len(rows) < 5:
        return {}
    actual = np.asarray([[r["season_rating"] if r["season_rating"] is not None else np.nan,
                          r["minutes_share"]] for r in rows])
    complete = np.isfinite(actual).all(axis=1)
    results = {}
    with threadpool_limits(limits=1):
        for fold, (development, test) in enumerate(KFold(5, shuffle=True, random_state=COST_MODEL_SEED).split(rows)):
            order = np.random.default_rng(COST_MODEL_SEED + fold * 100).permutation(development)
            train, calibration = np.split(order, [int(len(order) * .75)])
            paired_cal = calibration[complete[calibration]]
            paired_test = test[complete[test]]
            ranks = [ceil((len(paired_cal) + 1) * coverage) for coverage in (.8, .95)]
            # 유한 표본으로 95% 경계를 정할 수 없으면 등급을 만들지 않아요.
            if ranks[-1] > len(paired_cal) or not len(paired_test):
                continue
            spline = SplineTransformer(n_knots=5, degree=3, knots="quantile",
                                       extrapolation="linear", include_bias=False)
            spline.fit(raw[train, :2])
            values = np.column_stack((spline.transform(raw[:, :2]), raw[:, 2:]))
            design = StandardScaler().fit(values[train]).transform(values)
            expected = np.empty_like(actual)
            scales = []
            for column, limits in enumerate(((0, 10), (0, 1))):
                available_train = train[np.isfinite(actual[train, column])]
                target = actual[available_train, column]
                if len(target) < 2 or float(np.std(target)) == 0:
                    break
                center, scale = float(np.mean(target)), float(np.std(target))
                estimator = QuantileRegressor(quantile=.5, alpha=.001, solver="highs")
                estimator.fit(design[available_train], (target - center) / scale)
                expected[:, column] = np.clip(estimator.predict(design) * scale + center, *limits)
                scales.append(scale)
            if len(scales) != 2:
                continue
            scales = np.asarray(scales)
            calibration_scores = combined_cost_score(actual[paired_cal], expected[paired_cal], scales)
            absolute_errors = np.sort(np.abs(calibration_scores))
            q80, q95 = [float(absolute_errors[rank - 1]) for rank in ranks]
            scores = combined_cost_score(actual[paired_test], expected[paired_test], scales)
            for index, score in zip(paired_test, scores):
                differences = (actual[index] - expected[index]) / scales
                band = _cost_band(float(score), q80, q95)
                results[rows[index]["player_id"]] = {
                    "raw_score": float(score), "band": band,
                    "grade": (*GRADE_LABELS, "Very Good")[band], "unavailable_reason": None,
                    "expected_rating": float(expected[index, 0]),
                    "expected_minutes_share": float(expected[index, 1]),
                    "rating_sd": float(scales[0]), "minutes_share_sd": float(scales[1]),
                    "rating_standardized_difference": float(differences[0]),
                    "minutes_standardized_difference": float(differences[1]),
                    "fair_boundary": q80, "very_boundary": q95,
                }
    for value in results.values():
        value["reference_count"] = len(results)
    return results


def build_player_indicators(roster: list[dict], matches: list[dict], fixtures: list[dict],
                            calibration: dict | None, *, as_of: datetime) -> list[dict]:
    """현재 시즌 입력으로 폼 백분위와 주급 대비 성과 등급을 계산해요."""
    by_player, by_team = defaultdict(list), defaultdict(list)
    for row in matches:
        if row["starting_at"] <= as_of:
            by_player[row["player_id"]].append(row)
            by_team[(row["season_id"], row["team_id"], row["player_id"])].append(row)
    team_games = Counter()
    for fixture in fixtures:
        if fixture["starting_at"] <= as_of:
            for team_id in (fixture["home_team_id"], fixture["away_team_id"]):
                team_games[(fixture["season_id"], team_id)] += 1
    result, wage_rows = [], []
    for player in roster:
        current_matches = sorted(by_player[player["player_id"]],
                                 key=lambda r: (r["starting_at"], r["fixture_id"]))
        # 평점이 없는 출전도 최근 5경기에 포함해, 오래된 경기를 최근 경기로 대체하지 않아요.
        recent = [r for r in current_matches if (r["minutes_played"] or 0) > 0][-FORM_MATCH_LIMIT:]
        rated = valid_ratings(recent)
        form = _indicator("form_calibration_unavailable" if calibration is None else "no_rated_matches")
        form.update(rated_matches=len(rated), appearances=len(recent),
                    last_match_at=recent[-1]["starting_at"] if recent else None,
                    season_rating=weighted_rating(current_matches))
        if calibration is not None and rated:
            form["raw_score"] = weighted_rating(recent, calibration["decay_per_day"])

        team_matches = by_team[(player["season_id"], player["team_id"], player["player_id"])]
        team_rated = valid_ratings(team_matches)
        minutes = sum(r["minutes_played"] or 0 for r in team_matches)
        available = team_games[(player["season_id"], player["team_id"])] * 90
        wage = player["estimated_weekly_gross_eur"]
        cost = _indicator("no_rated_matches")
        cost.update(season_rating=weighted_rating(team_rated), minutes_played=minutes,
                    rated_minutes=sum(r["minutes_played"] for r in team_rated),
                    available_minutes=available, minutes_share=minutes / available if available else None,
                    actual_weekly_wage_eur=wage, expected_weekly_wage_eur=None,
                    rated_matches=len(team_rated))
        if not wage or wage <= 0:
            cost["unavailable_reason"] = "wage_unavailable"
        elif player["position_group_id"] is None:
            cost["unavailable_reason"] = "position_unavailable"
        elif available:
            if team_rated:
                cost["unavailable_reason"] = "performance_model_unavailable"
            # 평점 없는 선수도 확인된 출전 비중은 학습에 사용해요. 통합 등급은 제공하지 않아요.
            wage_rows.append({**player, **cost})
        result.append({"player_id": player["player_id"], "team_id": player["team_id"],
                       "season_id": player["season_id"], "season_name": player["season_name"],
                       "competition_id": player["competition_id"],
                       "position_group_id": player["position_group_id"], "as_of": as_of,
                       "comparison_scope": "current_season_big_five_all_positions",
                       "form": form, "cost_effectiveness": cost})
    predictions = cost_effectiveness_scores(wage_rows, roster)
    for item in result:
        item["cost_effectiveness"].update(predictions.get(item["player_id"], {}))
    _assign_form_grades(result)
    return result
