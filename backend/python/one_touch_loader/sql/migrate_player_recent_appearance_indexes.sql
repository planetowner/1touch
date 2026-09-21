-- 최근 10회 출전을 찾을 때 과거 라인업·교체 이벤트의 본문을 반복해서 읽지 않도록 해요.
-- 출전 판정에 필요한 값만 인덱스에서 읽으며 경기 기록과 계산 규칙은 바꾸지 않아요.
ALTER TABLE fixture_lineups
  ADD INDEX idx_fixture_lineups_player_appearance
    (player_id, fixture_id, team_id, lineup_type_id, minutes_played, rating, match_position_id),
  ALGORITHM=INPLACE, LOCK=NONE;

ALTER TABLE fixture_events
  ADD INDEX idx_fixture_events_appearance
    (fixture_id, team_id, event_type_id, player_id, related_player_id),
  ALGORITHM=INPLACE, LOCK=NONE;
