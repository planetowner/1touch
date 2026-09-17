"""Elo 차이로 경기 확률을 학습하고 같은 규칙으로 리그 전체를 계산해요."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy.optimize import minimize
from scipy.special import logsumexp


OUTCOMES = ("home_win", "draw", "away_win")


@dataclass(frozen=True)
class WDLModel:
    coefficients: tuple[float, float, float, float]

    def predict(self, elo_differences) -> np.ndarray:
        differences = np.asarray(elo_differences, dtype=float)
        if not np.isfinite(differences).all():
            raise ValueError("Elo differences must be finite")
        design = np.column_stack((np.ones(differences.size), differences.reshape(-1) / 400.0))
        # 400은 입력 단위 변환이에요. 홈 효과와 Elo의 영향은 계수로 학습해요.
        logits = np.zeros((differences.size, 3))
        logits[:, (0, 2)] = design @ np.asarray(self.coefficients).reshape(2, 2).T
        return np.exp(logits - logsumexp(logits, axis=1, keepdims=True))


def fit_wdl(elo_differences, outcomes) -> WDLModel:
    differences = np.asarray(elo_differences, dtype=float)
    outcomes = np.asarray(outcomes)
    if differences.ndim != 1 or outcomes.shape != differences.shape or not len(outcomes):
        raise ValueError("Training inputs must be nonempty paired vectors")
    if not np.isfinite(differences).all() or set(outcomes.tolist()) != {0, 1, 2}:
        raise ValueError("Training requires finite Elo and all three outcomes")
    design = np.column_stack((np.ones(len(differences)), differences / 400.0))
    observed = np.eye(3)[outcomes.astype(int)]

    def loss_gradient(coefficients):
        logits = np.zeros((len(outcomes), 3))
        logits[:, (0, 2)] = design @ coefficients.reshape(2, 2).T
        logs = logits - logsumexp(logits, axis=1, keepdims=True)
        loss = -float((logs * observed).sum() / len(outcomes))
        gradient = ((np.exp(logs) - observed)[:, (0, 2)].T @ design / len(outcomes)).reshape(-1)
        return loss, gradient

    # 무승부를 기준 범주로 두고 홈·원정 절편과 기울기를 최대우도로 함께 학습해요.
    # 별도의 고정 HFA나 고정 무승부 비율을 더하지 않아요.
    result = minimize(loss_gradient, np.zeros(4), jac=True, method="BFGS")
    if not result.success or not np.isfinite(result.x).all():
        raise ValueError(f"W/D/L fitting did not converge: {result.message}")
    return WDLModel(tuple(float(value) for value in result.x))


def evaluate_wdl(model: WDLModel, elo_differences, outcomes) -> dict:
    actual = np.asarray(outcomes, dtype=int)
    probabilities = model.predict(elo_differences)
    if len(actual) != len(probabilities) or not len(actual) or not np.isin(actual, (0, 1, 2)).all():
        raise ValueError("Invalid evaluation outcomes")
    return {
        "fixtures": len(actual),
        "log_loss": float(-np.log(probabilities[np.arange(len(actual)), actual]).mean()),
        "brier_score": float(np.square(probabilities - np.eye(3)[actual]).sum(axis=1).mean()),
    }


def summarize_points(points: np.ndarray) -> dict:
    values = np.asarray(points)
    if values.ndim != 1 or not values.size or not np.isfinite(values).all():
        raise ValueError("Expected a nonempty finite points vector")
    if not np.equal(values, np.floor(values)).all():
        raise ValueError("League points must be integers")
    # 사용자 확정: 중앙 80% 구간이에요. 승점은 정수여서 실제 포함 비율은 더 클 수 있어요.
    lower, upper = np.quantile(values, (0.1, 0.9), method="inverted_cdf")
    return {
        "mean": float(values.mean()),
        "likely_range": {
            "lower": int(lower), "upper": int(upper), "target_coverage": 0.8,
            "included_probability": float(((values >= lower) & (values <= upper)).mean()),
            "method": "equal_tail", "unit": "points",
        },
    }


def simulate_league(
    team_ids: list[int], current_points: dict[int, int], remaining_fixtures: list[dict],
    *, simulations: int, seed: int, forced_outcome: tuple[int, int] | None = None,
) -> dict[int, dict]:
    """각 경기의 홈승·무·원정승 확률은 호출 전에 한 번 계산해 고정해요."""
    if simulations < 1 or len(team_ids) < 2 or len(set(team_ids)) != len(team_ids):
        raise ValueError("Invalid teams or simulation count")
    if set(current_points) != set(team_ids):
        raise ValueError("Current points are required for every league team")
    index = {team_id: i for i, team_id in enumerate(team_ids)}
    base = np.asarray([current_points[team_id] for team_id in team_ids])
    if not np.isfinite(base).all() or not np.equal(base, np.floor(base)).all():
        raise ValueError("Current points must be finite integers")
    if len({f["fixture_id"] for f in remaining_fixtures}) != len(remaining_fixtures):
        raise ValueError("Duplicate remaining fixture")
    if forced_outcome is not None:
        fixture_id, outcome = forced_outcome
        if outcome not in (0, 1, 2) or fixture_id not in {f["fixture_id"] for f in remaining_fixtures}:
            raise ValueError("What-if must select a remaining fixture and a W/D/L outcome")
    rng = np.random.default_rng(seed)
    points = np.broadcast_to(base.astype(np.int64), (simulations, len(team_ids))).copy()
    for fixture in remaining_fixtures:
        h, a = index[fixture["home_team_id"]], index[fixture["away_team_id"]]
        probs = np.asarray(fixture["probabilities"], dtype=float)
        if h == a or probs.shape != (3,) or not np.isfinite(probs).all() or (probs < 0).any() or not np.isclose(probs.sum(), 1, atol=1e-12, rtol=0):
            raise ValueError("Invalid remaining fixture probability")
        # 기준 예측과 세 조건부 예측에서 같은 난수를 써 비교의 표본 흔들림을 줄여요.
        draws = rng.random(simulations)
        cumulative = np.cumsum(probs)
        cumulative[-1] = 1.0
        outcome = np.searchsorted(cumulative, draws, side="right")
        if forced_outcome is not None and fixture["fixture_id"] == forced_outcome[0]:
            outcome[:] = forced_outcome[1]
        points[:, h] += np.where(outcome == 0, 3, outcome == 1)
        points[:, a] += np.where(outcome == 2, 3, outcome == 1)

    # V1은 미래 점수를 만들지 않아요. 사용자 승인대로 동률 순서를 균등하게 나누는 근사치예요.
    ordering = np.lexsort((rng.random(points.shape), -points), axis=1)
    positions = np.empty_like(ordering)
    np.put_along_axis(positions, ordering, np.broadcast_to(np.arange(1, len(team_ids) + 1), ordering.shape), axis=1)
    result = {}
    for team_id, i in index.items():
        counts = np.bincount(positions[:, i], minlength=len(team_ids) + 1)[1:]
        result[team_id] = {
            "positions": [{"position": rank, "probability": float(count / simulations)}
                          for rank, count in enumerate(counts, 1)],
            "projected_points": summarize_points(points[:, i]),
        }
    return result
