"""수집과 기존 자료 이전에서 같은 영상·경기·팀 관계를 저장해요."""
from __future__ import annotations

import json

from .highlights import normalize, utc_datetime
from .db_json import decoded


def write_candidates(cursor, team_ids, candidates, checked_at):
    videos = {}
    for values in candidates.values():
        for video in values:
            previous = videos.get(video['video_id'])
            if previous is not None and previous != video:
                raise ValueError(f"Conflicting highlight video: {video['video_id']}")
            videos[video['video_id']] = video
    fixture_ids = sorted({v['match']['fixture_id'] for v in videos.values() if v['match']['fixture_id'] is not None})
    known = set()
    if fixture_ids:
        cursor.execute('SELECT fixture_id FROM fixtures WHERE fixture_id IN (' + ','.join(['%s'] * len(fixture_ids)) + ')', tuple(fixture_ids))
        known = {row[0] for row in cursor.fetchall()}
    for video in videos.values():
        match = video['match']
        fixture_id = match['fixture_id'] if match['fixture_id'] in known else None
        # 점수는 수집 중 영상 대조에만 써요. 알려진 팀·대회는 ID로 읽고, 없는 공식 경기의 정보만 남겨요.
        external = (None if fixture_id is not None else json.dumps({k: v for k, v in match.items()
                    if k not in {'match_key','starting_at','score','penalty_shootout'}}, ensure_ascii=False))
        # 기존 fixtures의 일정이 덜 갱신된 경기도 있어, 최근 3개 정렬에는 확인한 경기 시각을 써요.
        cursor.execute('''INSERT INTO highlight_matches (match_key,fixture_id,starting_at,external_record) VALUES (%s,%s,%s,%s)
            ON DUPLICATE KEY UPDATE fixture_id=VALUES(fixture_id),starting_at=VALUES(starting_at),external_record=VALUES(external_record)''',
            (match['match_key'], fixture_id, utc_datetime(match['starting_at']).replace(tzinfo=None), external))
        cursor.execute('''INSERT INTO highlight_channels (channel_id,name,source_type) VALUES (%s,%s,%s)
            ON DUPLICATE KEY UPDATE name=VALUES(name),source_type=VALUES(source_type)''',
            (video['channel_id'], video['channel_name'], video['source_type']))
        cursor.execute('''INSERT INTO highlight_videos
            (video_id,match_key,channel_id,title,thumbnail_url,published_at,duration_seconds,region_restriction,embeddable)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) ON DUPLICATE KEY UPDATE
            match_key=VALUES(match_key),channel_id=VALUES(channel_id),title=VALUES(title),thumbnail_url=VALUES(thumbnail_url),
            published_at=VALUES(published_at),duration_seconds=VALUES(duration_seconds),
            region_restriction=VALUES(region_restriction),embeddable=VALUES(embeddable)''',
            (video['video_id'], match['match_key'], video['channel_id'], video['title'], video['thumbnail_url'],
             utc_datetime(video['published_at']).replace(tzinfo=None), video['duration_seconds'],
             json.dumps(video['region_restriction']), video['embeddable']))
    for team_id in team_ids:
        cursor.execute('DELETE FROM team_highlights WHERE team_id=%s', (team_id,))
        for video in candidates[team_id]:
            cursor.execute('INSERT INTO team_highlights (team_id,video_id) VALUES (%s,%s)', (team_id, video['video_id']))
        stamp = checked_at[team_id] if isinstance(checked_at, dict) else checked_at
        cursor.execute('''INSERT INTO team_highlight_sync (team_id,checked_at) VALUES (%s,%s)
            ON DUPLICATE KEY UPDATE checked_at=VALUES(checked_at)''', (team_id, stamp))
    # 다른 팀이 아직 사용하는 영상은 유지하고, 사라진 후보의 복사본은 남기지 않아요.
    cursor.execute('DELETE FROM highlight_videos WHERE video_id NOT IN (SELECT video_id FROM team_highlights)')
    cursor.execute('DELETE FROM highlight_matches WHERE match_key NOT IN (SELECT match_key FROM highlight_videos)')
    cursor.execute('DELETE FROM highlight_channels WHERE channel_id NOT IN (SELECT channel_id FROM highlight_videos)')


HIGHLIGHT_SELECT = '''SELECT v.*, c.name AS channel_name,c.source_type,m.fixture_id,m.starting_at,m.external_record,
    sy.checked_at,f.home_team_id,f.away_team_id,
    ht.name AS home_name,at.name AS away_name,s.name AS season_name,s.competition_id,co.name AS competition_name
    FROM team_highlights th JOIN highlight_videos v ON v.video_id=th.video_id
    JOIN highlight_channels c ON c.channel_id=v.channel_id JOIN highlight_matches m ON m.match_key=v.match_key
    JOIN team_highlight_sync sy ON sy.team_id=th.team_id
    LEFT JOIN fixtures f ON f.fixture_id=m.fixture_id
    LEFT JOIN teams ht ON ht.team_id=f.home_team_id LEFT JOIN teams at ON at.team_id=f.away_team_id
    LEFT JOIN stages st ON st.stage_id=f.stage_id LEFT JOIN seasons s ON s.season_id=st.season_id
    LEFT JOIN competitions co ON co.competition_id=s.competition_id WHERE th.team_id=%s'''


def candidate_from_row(row):
    if row['fixture_id'] is None:
        match = {**decoded(row['external_record']), 'match_key': row['match_key']}
    else:
        match = {
            'match_key': row['match_key'], 'fixture_id': row['fixture_id'],
            'competition_key': f"sportmonks:{row['competition_id']}", 'competition_name': row['competition_name'],
            'season_name': row['season_name'],
            'home': {'team_id': row['home_team_id'], 'name': row['home_name']},
            'away': {'team_id': row['away_team_id'], 'name': row['away_name']},
            'record_source': 'sportmonks', 'record_url': f"https://api.sportmonks.com/v3/football/fixtures/{row['fixture_id']}",
        }
    match['starting_at'] = utc_datetime(row['starting_at']).isoformat().replace('+00:00', 'Z')
    return {**{k: row[k] for k in ('video_id','title','thumbnail_url','channel_id','channel_name','source_type','duration_seconds')},
            'published_at': utc_datetime(row['published_at']), 'region_restriction': decoded(row['region_restriction']),
            'embeddable': bool(row['embeddable']), 'video_url': f"https://www.youtube.com/watch?v={row['video_id']}",
            'is_extended': 'extended' in normalize(row['title']), 'match': match}
