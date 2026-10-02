"""선수 목록·스쿼드·순위 이력에서 같은 병합·포지션·정렬 규칙을 사용해요."""
from collections import defaultdict
from decimal import Decimal

from .fixture_states import COMPLETED_STATE_IDS
from .player_appearances import APPEARED, MATCH_FROM
from .player_detail import dominant_position
from .player_match_metrics import POSITION_GROUPS
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


def season_player_positions(fetch, season_name, as_of):
    return {pid: POSITION_GROUPS.get(position) for pid, position in
            season_player_position_ids(fetch, season_name, as_of).items()}


def season_player_position_ids(fetch, season_name, as_of, *, player_ids=None):
    if player_ids is not None and not player_ids:
        return {}
    completed = ','.join(map(str, COMPLETED_STATE_IDS))
    # 스쿼드는 명단 선수만 묶어서 읽되, 개인 화면처럼 같은 시즌의 모든 대회를 합쳐요.
    player_filter = '' if player_ids is None else f" AND fl.player_id IN ({','.join(['%s'] * len(player_ids))})"
    matches = fetch('SELECT fl.player_id,fl.match_position_id,fl.minutes_played,f.starting_at,f.state_id '
        + MATCH_FROM + f' WHERE s.name=%s AND f.state_id IN ({completed}) AND f.starting_at<=%s AND {APPEARED}'
        + player_filter, (season_name, as_of, *(player_ids or ())))
    by_player = defaultdict(list)
    for row in matches:
        by_player[row['player_id']].append(row)
    return {pid: dominant_position(rows) for pid, rows in by_player.items()}
