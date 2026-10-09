"""메인 선수 목록은 현재 시즌 랭킹과 실제 최근 출전 기록을 사용해요."""
from collections import defaultdict
from contextlib import closing
from datetime import datetime, timezone
from decimal import Decimal

from ..db import get_conn
from .player_detail_repo import (
    COMPLETED, CURRENT_LEAGUE_SEASON, get_current_player_teams,
)
from ...core.player_appearances import APPEARED, MATCH_FROM
from ...core.player_ranking import merge_current_scores, rank_current_scores
from ...core.player_positions import season_player_positions
from ...core.player_rating_percentile import (
    HistoricalPercentile, RATING_COMPETITION_IDS, REFERENCE_START_SEASON_NAME,
    average_rating, display_score,
)

LEAGUES = ','.join(map(str, RATING_COMPETITION_IDS))
WATCH_WINDOW_SIZE = 3


def watch_players(rows):
    grouped = defaultdict(list)
    for row in rows:
        grouped[row['player_id']].append(row)
    result = []
    for pid, matches in grouped.items():
        matches.sort(key=lambda r: (r['starting_at'], r['fixture_id']), reverse=True)
        matches = matches[:WATCH_WINDOW_SIZE * 2]
        # 평점이 없는 출전을 건너뛰면 비교할 경기가 바뀌므로 6경기 모두 확인해요.
        if len(matches) < WATCH_WINDOW_SIZE * 2 or any(r['rating'] is None for r in matches):
            continue
        # 최근 3경기는 모두 이번 시즌이어야 해요. 직전 3경기는 지난 시즌도 허용해요.
        if not all(r['is_current_season'] for r in matches[:WATCH_WINDOW_SIZE]):
            continue
        recent = sum(Decimal(str(r['rating'])) for r in matches[:WATCH_WINDOW_SIZE]) / WATCH_WINDOW_SIZE
        previous = sum(Decimal(str(r['rating'])) for r in matches[WATCH_WINDOW_SIZE:]) / WATCH_WINDOW_SIZE
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
                positions = season_player_positions(fetch, season_name, now)
                if competition_id is None and scores:
                    samples = fetch(f"""SELECT sample.rating_sum,sample.rated_matches
                        FROM player_rating_reference_samples sample JOIN seasons s ON s.season_id=sample.season_id
                        WHERE sample.competition_id IN ({LEAGUES}) AND s.name BETWEEN %s AND %s""",
                        (REFERENCE_START_SEASON_NAME, season_name))
                    distribution = HistoricalPercentile(average_rating(r['rating_sum'], r['rated_matches']) for r in samples)
                    scores = merge_current_scores(scores, distribution)
                for row in scores:
                    row['position'] = positions.get(row['player_id'])
                ranked = rank_current_scores(scores, position)
                items = []
                for row in ranked[offset:offset + limit]:
                    items.append({k: v for k, v in row.items() if k not in ('rating_sum', 'percentile_score')} |
                                 {'display_score': display_score(row['percentile_score'])})
                return {'season_name': season_name, 'leagues': leagues, 'total': len(ranked), 'items': items,
                        'limit': limit, 'offset': offset, 'competition_id': competition_id, 'position': position}
        finally:
            conn.rollback()


def _attach_current_player_teams(fetch, items):
    teams = get_current_player_teams(fetch, tuple(item['player_id'] for item in items))
    for item in items:
        team = teams[item['player_id']]
        for key in ('team_id', 'team_name', 'jersey_number'):
            item[key] = team[key] if team else None


def get_following_players(user_id):
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                def fetch(sql, params=()):
                    cur.execute(sql, params)
                    return cur.fetchall()

                items = fetch("""SELECT p.player_id,p.display_name AS name,p.image_path
                    FROM user_following_players f JOIN players p ON p.player_id=f.player_id
                    WHERE f.user_id=%s ORDER BY f.position""", (user_id,))
                # 편집 화면도 목록 응답만으로 소속팀과 등번호를 바로 보여줘요.
                _attach_current_player_teams(fetch, items)
                return {'items': items}
        finally:
            conn.rollback()


def get_ones_to_watch():
    with closing(get_conn()) as conn:
        conn.start_transaction(readonly=True)
        try:
            with conn.cursor(dictionary=True) as cur:
                # 모든 대회 출전을 최근 6경기씩 읽고, 선수 상세와 같은 시즌 기준을 적용해요.
                cur.execute(f"""WITH current_players AS (
                    SELECT DISTINCT sm.player_id FROM team_squad_members sm JOIN seasons s ON s.season_id=sm.season_id
                    WHERE s.is_current=1 AND s.competition_id IN ({LEAGUES})
                ), appearances AS (
                    SELECT fl.player_id,fl.fixture_id,fl.rating,f.starting_at,
                        s.name=({CURRENT_LEAGUE_SEASON}) AS is_current_season,
                        ROW_NUMBER() OVER (PARTITION BY fl.player_id ORDER BY f.starting_at DESC,fl.fixture_id DESC) AS recent
                    {MATCH_FROM} JOIN current_players cp ON cp.player_id=fl.player_id
                    WHERE f.state_id IN ({COMPLETED}) AND f.starting_at<=UTC_TIMESTAMP() AND {APPEARED}
                ) SELECT a.*,p.display_name AS name,p.image_path AS image FROM appearances a
                  JOIN players p ON p.player_id=a.player_id WHERE a.recent<={WATCH_WINDOW_SIZE * 2}""")
                items = watch_players(cur.fetchall())
                if items:
                    def fetch(sql, params=()):
                        cur.execute(sql, params)
                        return cur.fetchall()

                    _attach_current_player_teams(fetch, items)
                return {'items': items, 'scope': 'all_competitions_recent_6_appearances'}
        finally:
            conn.rollback()
