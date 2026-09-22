"""필터별 현재 순위를 전날 마지막 순위와 비교해요."""
from datetime import timedelta
from decimal import Decimal
import hashlib
import json

from .cup_betting import utc_datetime
from .player_ranking import merge_rating_rows, rank_current_scores
from .player_rating_percentile import RATING_COMPETITION_IDS


def ranking_fingerprint(season_name, rows):
    values = [(r['season_id'], r['competition_id'], r['player_id'], r['rated_matches'],
               str(Decimal(r['rating_sum']).quantize(Decimal('.01'))), r['position']) for r in rows]
    return hashlib.sha256(json.dumps([season_name, sorted(values)], ensure_ascii=False).encode()).hexdigest()


def _ranks(rows, competition_id, position):
    selected = [r for r in rows if competition_id is None or r['competition_id'] == competition_id]
    if competition_id is None:
        selected = merge_rating_rows(selected)
    return rank_current_scores(selected, position)


def compare_rankings(current, previous, *, season_name, as_of, competition_id=None, position=None):
    """이력 없음과 신규 진입은 0계단 변동으로 표시하지 않아요."""
    if competition_id is not None and competition_id not in RATING_COMPETITION_IDS:
        raise ValueError('Unsupported ranking league')
    if position not in (None, 'GK', 'DF', 'MF', 'FW'):
        raise ValueError('Unsupported ranking position')
    ranked = _ranks(current, competition_id, position)
    before = {r['player_id']: r['rank'] for r in _ranks(previous or [], competition_id, position)}
    items = []
    for row in ranked:
        previous_rank = before.get(row['player_id'])
        delta = previous_rank - row['rank'] if previous_rank is not None else None
        movement = ('unavailable' if previous is None else 'new') if delta is None else (
            'up' if delta > 0 else 'down' if delta < 0 else 'unchanged')
        items.append({'player_id': row['player_id'], 'rank': row['rank'], 'previous_rank': previous_rank,
                      'rank_delta': delta, 'movement': movement})
    return {'season_name': season_name, 'competition_id': competition_id, 'position': position,
            'comparison_basis': 'previous_day_final', 'day_timezone': 'UTC',
            'comparison_date': (utc_datetime(as_of).date() - timedelta(days=1)).isoformat(),
            'comparison_available': previous is not None, 'total': len(items), 'items': items}
