"""선수 목록·순위 이력에서 같은 병합·정렬 규칙을 사용해요."""
from decimal import Decimal

from .player_rating_percentile import average_rating, rank_players


def merge_rating_rows(rows):
    grouped = {}
    for row in rows:
        pid = row['player_id']
        if pid not in grouped:
            grouped[pid] = {**row, 'rating_sum': Decimal(0), 'rated_matches': 0}
        grouped[pid]['rating_sum'] += row['rating_sum']
        grouped[pid]['rated_matches'] += row['rated_matches']
    return list(grouped.values())


def merge_current_scores(rows, distribution):
    # 이적 선수도 한 줄로 표시해요. 리그 평균을 평균내지 않고 경기 수로 가중해요.
    merged = merge_rating_rows(rows)
    for row in merged:
        row['percentile_score'] = distribution.score(average_rating(row['rating_sum'], row['rated_matches']))
    return merged


def rank_current_scores(rows, position=None):
    return rank_players([r for r in rows if position is None or r['position'] == position])
