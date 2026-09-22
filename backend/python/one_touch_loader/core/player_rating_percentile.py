"""5대 리그의 2017/18~평가 시즌 평균 평점으로 백분위를 계산해요."""
from __future__ import annotations

from bisect import bisect_left, bisect_right
from decimal import Decimal, ROUND_HALF_UP
from fractions import Fraction
from typing import Iterable


RATING_COMPETITION_IDS = (8, 82, 301, 384, 564)
REFERENCE_START_SEASON_NAME = "2017/2018"
MINIMUM_RATED_MATCHES = 10
DISPLAY_SCORE_ANCHORS = ((0, 0), (50, 50), (90, 70), (99, 90), (100, 100))


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


def score_season_records(rows: list[dict], *, from_season: str | None = None) -> list[dict]:
    """각 시즌은 자기 시즌까지의 모든 리그 표본과 비교하고, 이후 시즌은 제외해요."""
    by_season: dict[str, list[dict]] = {}
    for row in rows:
        by_season.setdefault(row["season_name"], []).append(row)
    reference = []
    result = []
    for season_name in sorted(by_season):
        season_rows = by_season[season_name]
        # 같은 시즌의 다른 리그와 자기 기록도 비교 집단에 포함해요.
        reference.extend(average_rating(row["rating_sum"], row["rated_matches"]) for row in season_rows)
        # 갱신 대상 이전 시즌도 비교 표본에는 남기고, 저장하지 않을 점수 계산만 생략해요.
        if from_season is not None and season_name < from_season:
            continue
        distribution = HistoricalPercentile(reference)
        result.extend({
            **row,
            "percentile_score": distribution.score(average_rating(row["rating_sum"], row["rated_matches"])),
        } for row in season_rows)
    return result


def display_score(score: Decimal) -> float:
    # 모든 시즌에 같은 환산표를 써서 상위권 간격을 넓혀요. 저장 백분위와 순위는 유지해요.
    # 먼저 백분위를 반올림하면 상위권 차이가 사라지므로 환산을 마친 뒤 한 자리로 표시해요.
    for (lower_percentile, lower_score), (upper_percentile, upper_score) in zip(
        DISPLAY_SCORE_ANCHORS, DISPLAY_SCORE_ANCHORS[1:],
    ):
        if lower_percentile <= score <= upper_percentile:
            converted = lower_score + (score - lower_percentile) * (upper_score - lower_score) / (
                upper_percentile - lower_percentile
            )
            return float(converted.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP))
    raise ValueError("Percentile score must be between 0 and 100")


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
