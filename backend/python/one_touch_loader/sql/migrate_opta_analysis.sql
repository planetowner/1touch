-- 기존 Opta 슈팅·Understat 데이터는 유지하고 패스·수비 행동을 별도로 저장해요.
-- 완료 행이 없으면 미수집이에요. 실제 0개 경기와 구분해요.
CREATE TABLE fixture_opta_analyses (
  fixture_id BIGINT UNSIGNED NOT NULL,
  external_fixture_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
  external_competition_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
  external_season_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
  source_url VARCHAR(1000) NOT NULL,
  home_count SMALLINT UNSIGNED NOT NULL,
  away_count SMALLINT UNSIGNED NOT NULL,
  collected_at DATETIME(6) NOT NULL COMMENT 'UTC 수집 시각',
  PRIMARY KEY (fixture_id),
  UNIQUE KEY uq_opta_analysis_external (external_fixture_id),
  CONSTRAINT fk_opta_analysis_fixture FOREIGN KEY (fixture_id)
    REFERENCES fixtures(fixture_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_opta_events (
  external_event_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
  fixture_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  minute SMALLINT UNSIGNED NOT NULL,
  extra_minute SMALLINT UNSIGNED NOT NULL,
  kinds JSON NOT NULL COMMENT '한 패스의 성공·키패스·어시스트 중복 분류를 보존해요',
  start_x DECIMAL(9,6) NOT NULL,
  start_y DECIMAL(9,6) NOT NULL,
  end_x DECIMAL(9,6) NULL COMMENT '수비 행동은 끝 좌표를 제공하지 않아요',
  end_y DECIMAL(9,6) NULL,
  PRIMARY KEY (external_event_id),
  KEY idx_opta_events_fixture (fixture_id, minute, extra_minute),
  CONSTRAINT fk_opta_event_analysis FOREIGN KEY (fixture_id)
    REFERENCES fixture_opta_analyses(fixture_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_opta_event_team FOREIGN KEY (team_id)
    REFERENCES teams(team_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_opta_event_player FOREIGN KEY (player_id)
    REFERENCES players(player_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
