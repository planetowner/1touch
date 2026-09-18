"""고정한 과거 선수·시즌 평균 평점으로 백분위를 계산해요."""
from __future__ import annotations

from bisect import bisect_left, bisect_right
from decimal import Decimal, ROUND_HALF_UP
from fractions import Fraction
from typing import Iterable


REFERENCE_SEASON_NAMES = tuple(f"{year}/{year + 1}" for year in range(2020, 2025))
MINIMUM_RATED_MATCHES = 10


def average_rating(rating_sum: Decimal, rated_matches: int) -> Fraction:
    # 7.1과 7.10처럼 같은 평균은 출전 수나 소수점 오차 때문에 다른 값이 되면 안 돼요.
    return Fraction(rating_sum) / rated_matches


class HistoricalPercentile:
    def __init__(self, reference: Iterable[Fraction]):
        self.reference = tuple(sorted(reference))
        if not self.reference:
            raise ValueError("Historical rating reference must not be empty")

    def score(self, rating: Fraction) -> Decimal:
        below = bisect_left(self.reference, rating)
        through_equal = bisect_right(self.reference, rating)
        # 같은 평균은 절반만 포함해요. 현재 시즌 1위나 최댓값으로 재조정하지 않아요.
        return Decimal(50 * (below + through_equal)) / len(self.reference)


def display_score(score: Decimal) -> float:
    return float(score.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP))


def rank_players(rows: list[dict]) -> list[dict]:
    """백분위가 같아도 원래 평균순으로 정렬하고, 평균까지 같으면 공동 순위로 표시해요."""
    ranked = sorted(rows, key=lambda row: (
        -average_rating(row["rating_sum"], row["rated_matches"]), row["player_id"],
    ))
    previous = None
    rank = 0
    result = []
    for index, row in enumerate(ranked, 1):
        mean = average_rating(row["rating_sum"], row["rated_matches"])
        if mean != previous:
            rank = index
        result.append({**row, "rank": rank, "average_rating": float(mean)})
        previous = mean
    return result
