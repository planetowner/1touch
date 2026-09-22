"""선수의 실제 출전 여부와 경기 연결을 같은 기준으로 조회해요."""

APPEARED = """(fl.lineup_type_id=11 OR fl.minutes_played>0 OR fl.rating IS NOT NULL
    OR EXISTS (SELECT 1 FROM fixture_events ev WHERE ev.fixture_id=fl.fixture_id
      AND ev.team_id=fl.team_id AND ev.event_type_id=18
      AND (ev.player_id=fl.player_id OR ev.related_player_id=fl.player_id)))"""
MATCH_FROM = """
FROM fixture_lineups fl JOIN fixtures f ON f.fixture_id=fl.fixture_id
JOIN stages st ON st.stage_id=f.stage_id JOIN seasons s ON s.season_id=st.season_id
JOIN competitions c ON c.competition_id=s.competition_id
"""
