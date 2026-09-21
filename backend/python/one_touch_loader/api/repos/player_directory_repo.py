"""메인 선수 목록은 현재 시즌 랭킹과 실제 최근 출전 기록을 사용해요."""
from collections import defaultdict
from contextlib import closing
from datetime import datetime, timezone
from decimal import Decimal

from ..db import get_conn
from .player_detail_repo import APPEARED, COMPLETED, MATCH_FROM
from ...core.player_detail import dominant_position
from ...core.player_match_metrics import POSITION_GROUPS
from ...core.player_rating_percentile import (
    HistoricalPercentile, RATING_COMPETITION_IDS, REFERENCE_START_SEASON_NAME,
    average_rating, display_score, rank_players,
)

LEAGUES = ','.join(map(str, RATING_COMPETITION_IDS))


def merge_current_scores(rows, distribution):
    grouped = {}
    for row in rows:
        pid = row['player_id']
        if pid not in grouped:
            grouped[pid] = {**row, 'rating_sum': Decimal(0), 'rated_matches': 0}
        grouped[pid]['rating_sum'] += row['rating_sum']
        grouped[pid]['rated_matches'] += row['rated_matches']
    # 이적 선수도 한 줄로 표시해요. 리그 평균을 평균내지 않고 경기 수로 가중해요.
    for row in grouped.values():
        row['percentile_score'] = distribution.score(average_rating(row['rating_sum'], row['rated_matches']))
    return list(grouped.values())


def watch_players(rows):
    grouped = defaultdict(list)
    for row in rows:
        grouped[row['player_id']].append(row)
    result = []
    for pid, matches in grouped.items():
        matches.sort(key=lambda r: (r['starting_at'], r['fixture_id']), reverse=True)
        matches = matches[:10]
        # 평점이 없는 출전을 건너뛰면 '최근 5경기'가 바뀌므로 10경기 모두 확인해요.
        if len(matches) < 10 or any(r['rating'] is None for r in matches):
            continue
        recent = sum(Decimal(str(r['rating'])) for r in matches[:5]) / 5
        previous = sum(Decimal(str(r['rating'])) for r in matches[5:]) / 5
        change = recent - previous
        if change <= 0:
            continue
        result.append({
            'player_id': pid, 'name': matches[0]['name'], 'image': matches[0]['image'],
            'recent_average': float(recent), 'previous_average': float(previous), 'change': float(change),
        })
    return sorted(result, key=lambda r: (-r['change'], -r['recent_average'], r['player_id']))[:10]


def get_current_ranking(competition_id=None, position=None, *, limit=20, offset=0):
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                def fetch(sql, params=()):
                    cur.execute(sql, params)
                    return cur.fetchall()
                leagues = fetch(f"""SELECT s.season_id,s.name AS season_name,s.competition_id,c.name,
                    COUNT(sc.player_id) AS available_players FROM seasons s
                    JOIN competitions c ON c.competition_id=s.competition_id
                    LEFT JOIN player_rating_scores sc ON sc.season_id=s.season_id
                    WHERE s.is_current=1 AND s.competition_id IN ({LEAGUES})
                    GROUP BY s.season_id,s.name,s.competition_id,c.name ORDER BY s.competition_id""")
                scores = fetch(f"""SELECT sc.player_id,p.display_name AS name,p.image_path AS image,
                    sc.rating_sum,sc.rated_matches,sc.percentile_score,s.name AS season_name
                    FROM player_rating_scores sc JOIN players p ON p.player_id=sc.player_id
                    JOIN seasons s ON s.season_id=sc.season_id
                    WHERE s.is_current=1 AND s.competition_id IN ({LEAGUES})
                    AND (%s IS NULL OR s.competition_id=%s)""", (competition_id, competition_id))
                names = {r['season_name'] for r in scores}
                if len(names) > 1:
                    raise ValueError('Current league seasons do not match')
                season_name = next(iter(names), leagues[0]['season_name'] if leagues else None)
                matches = fetch("SELECT fl.player_id,fl.match_position_id,fl.minutes_played,f.starting_at,f.state_id "
                    + MATCH_FROM + f" WHERE s.name=%s AND f.state_id IN ({COMPLETED}) AND f.starting_at<=%s AND {APPEARED}", (season_name, now))
                by_player = defaultdict(list)
                for row in matches:
                    by_player[row['player_id']].append(row)
                if competition_id is None and scores:
                    samples = fetch(f"""SELECT sample.rating_sum,sample.rated_matches
                        FROM player_rating_reference_samples sample JOIN seasons s ON s.season_id=sample.season_id
                        WHERE sample.competition_id IN ({LEAGUES}) AND s.name BETWEEN %s AND %s""",
                        (REFERENCE_START_SEASON_NAME, season_name))
                    distribution = HistoricalPercentile(average_rating(r['rating_sum'], r['rated_matches']) for r in samples)
                    scores = merge_current_scores(scores, distribution)
                for row in scores:
                    row['position'] = POSITION_GROUPS.get(dominant_position(by_player[row['player_id']]))
                ranked = rank_players([r for r in scores if position is None or r['position'] == position])
                items = []
                for row in ranked[offset:offset + limit]:
                    items.append({k: v for k, v in row.items() if k not in ('rating_sum', 'percentile_score')} |
                                 {'display_score': display_score(row['percentile_score'])})
                return {'season_name': season_name, 'leagues': leagues, 'total': len(ranked), 'items': items,
                        'limit': limit, 'offset': offset, 'competition_id': competition_id, 'position': position}
        finally:
            conn.rollback()


def get_ones_to_watch():
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                # 현재 5대 리그 소속 선수의 모든 대회 출전을 시즌 경계 없이 최근 10경기씩 읽어요.
                cur.execute(f"""WITH current_players AS (
                    SELECT DISTINCT sm.player_id FROM team_squad_members sm JOIN seasons s ON s.season_id=sm.season_id
                    WHERE s.is_current=1 AND s.competition_id IN ({LEAGUES})
                ), appearances AS (
                    SELECT fl.player_id,fl.fixture_id,fl.rating,f.starting_at,
                        ROW_NUMBER() OVER (PARTITION BY fl.player_id ORDER BY f.starting_at DESC,fl.fixture_id DESC) AS recent
                    FROM fixture_lineups fl JOIN current_players cp ON cp.player_id=fl.player_id
                    JOIN fixtures f ON f.fixture_id=fl.fixture_id
                    WHERE f.state_id IN ({COMPLETED}) AND f.starting_at<=UTC_TIMESTAMP() AND {APPEARED}
                ) SELECT a.*,p.display_name AS name,p.image_path AS image FROM appearances a
                  JOIN players p ON p.player_id=a.player_id WHERE a.recent<=10""")
                return {'items': watch_players(cur.fetchall()), 'scope': 'all_competitions_recent_10_appearances'}
        finally:
            conn.rollback()
